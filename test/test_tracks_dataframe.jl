using Test
using ReplSpotifyPlayer
using ReplSpotifyPlayer: TDF, SpTrackId, SpPlaylistId, tracks_data_append_playlist!, subset
using ReplSpotifyPlayer: save_tracks_data, load_tracks_data, playlist_owned_dataframe_get
using ReplSpotifyPlayer: ncol, flatten
import ReplSpotifyPlayer: InlineStrings
using ReplSpotifyPlayer: groupby, combine, transform, nrow, select!, Not
using ReplSpotifyPlayer: flatten_horizontally_vector, names, unflatten_horizontally_vector
using ReplSpotifyPlayer: tracks_namedtuple_from_playlist, tracks_data_append_namedtuple_from_playlist!

@test !isempty(TDF[])

tr = TDF[].trackid[10]
tr_na = SpTrackId("1234567890123456789012")
pl_ref = TDF[].playlistref[10]
pl_ref_old = PlaylistRef(name = pl_ref.name, snapshot_id = "x", id = pl_ref.id)
plid_na = SpPlaylistId("1234567890123456789012")
pl_ref_na = PlaylistRef(name = "playlistname", snapshot_id = "x", id = plid_na)

@test is_track_in_data(tr)
@test ! is_track_in_data(tr_na)

@test is_playlist_snapshot_in_data(pl_ref)
@test ! is_playlist_snapshot_in_data(pl_ref_na)
@test ! is_playlist_snapshot_in_data(pl_ref_old)

@test is_playlist_in_data(pl_ref)
@test ! is_playlist_in_data(pl_ref_na)
@test is_playlist_in_data(pl_ref_old)

@test ! is_other_playlist_snapshot_in_data(pl_ref)
@test ! is_other_playlist_snapshot_in_data(pl_ref_na)
@test is_other_playlist_snapshot_in_data(pl_ref_old)

tdfe = DataFrame()

@test ! is_track_in_data(tdfe, tr)
@test ! is_track_in_data(tdfe, tr_na)

@test ! is_playlist_snapshot_in_data(tdfe, pl_ref)
@test ! is_playlist_snapshot_in_data(tdfe, pl_ref_na)
@test ! is_playlist_snapshot_in_data(tdfe, pl_ref_old)

@test ! is_playlist_in_data(tdfe, pl_ref)
@test ! is_playlist_in_data(tdfe, pl_ref_na)
@test ! is_playlist_in_data(tdfe, pl_ref_old)

@test ! is_other_playlist_snapshot_in_data(tdfe, pl_ref)
@test ! is_other_playlist_snapshot_in_data(tdfe, pl_ref_na)
@test ! is_other_playlist_snapshot_in_data(tdfe, pl_ref_old)

tdfr = view(TDF[], 10, :)

@test is_track_in_data(tdfr, tr)
@test ! is_track_in_data(tdfr, tr_na)

@test is_playlist_snapshot_in_data(tdfr, pl_ref)
@test ! is_playlist_snapshot_in_data(tdfr, pl_ref_na)
@test ! is_playlist_snapshot_in_data(tdfr, pl_ref_old)

@test is_playlist_in_data(tdfr, pl_ref)
@test ! is_playlist_in_data(tdfr, pl_ref_na)
@test is_playlist_in_data(tdfr, pl_ref_old)

@test ! is_other_playlist_snapshot_in_data(tdfr, pl_ref)
@test ! is_other_playlist_snapshot_in_data(tdfr, pl_ref_na)
@test is_other_playlist_snapshot_in_data(tdfr, pl_ref_old)

# Test writing and reading csv.
tdfc = DataFrame(trackid = [tr_na], playlistref = [pl_ref_na])
@test tdfc.trackid[1] == tr_na
@test tdfc.playlistref[1] == pl_ref_na

pth = mktempdir()
fpth = joinpath(pth, "dataframe_test.csv")
save_tracks_data(tdfc; fpth )
tdfl = load_tracks_data(;fpth)
@test tdfl.trackid[1] == tr_na
@test tdfl.playlistref[1] == pl_ref_na

###############################################
# Test types are preserved when save, then load.
###############################################
playlistrefs_df = playlist_owned_dataframe_get(;silent = false)
playlistrefs_rw = subset(playlistrefs_df, :name => x-> x .== ("-- Liked from Radio --"))[1,:]
pl_ref = PlaylistRef(playlistrefs_rw)
tdfs = DataFrame()

# The field 'available markets' can have hundreds of elements, inconvenient in a dataframe.
# Check that 'available_markets' is converted at creation
nt = tracks_namedtuple_from_playlist(pl_ref.id)
am = nt.available_markets
@test am isa Vector{String}

tracks_data_append_playlist!(tdfs, pl_ref; silent = false)
playlistrefs_rw = subset(playlistrefs_df, :name => x-> x .== ("89-90spm"))[1,:]
pl_ref = PlaylistRef(playlistrefs_rw)
tracks_data_append_playlist!(tdfs, pl_ref; silent = false)
@test ncol(tdfs) == 12

fpth = joinpath(pth, "dataframe_type_test.csv")
save_tracks_data(tdfs; fpth )
tdfl = load_tracks_data(;fpth)
for (col_s, col_l, col_name) in zip(eachcol(tdfs), eachcol(tdfl), propertynames(tdfs))
    if col_name ∉ [:artists, :artist_ids]
        if eltype(col_s) <: eltype(col_l)
            @test true
        else
            println(col_name, " ", eltype(col_s), " ", eltype(col_l))
           # @test false
        end
    end
end

############################################################
# Workaround for saving / loading columns with Vector{String}
############################################################

# Give up on one-liner...
df = DataFrame(n = [10, 20, 30],
    A = [["ab","cd"], ["ef","gh"], ["ij", "kl", "mn"]],
    B = [["Ab","Cd"], ["Ef","Gh"], ["Ij", "Kl", "Mnop"]])
df1 = flatten_horizontally_vector(df, :A)
df2 = flatten_horizontally_vector(df1, :B)
df3 = unflatten_horizontally_vector(df2, :A)
df4 = unflatten_horizontally_vector(df3, :B)
df
@test isequal(df, df4)

####################
# Formally mutating?
####################
nt = tracks_namedtuple_from_playlist(pl_ref.id)
td = DataFrame()
@test isempty(td)
tracks_data_append_namedtuple_from_playlist!(td, pl_ref,  nt)
@test ! isempty(td)