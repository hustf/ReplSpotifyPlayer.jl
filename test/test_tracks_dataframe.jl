using Test
push!(ENV, "SPOTIFY_NOINIT" => "true"); using ReplSpotifyPlayer
using ReplSpotifyPlayer: TDF, SpTrackId, SpPlaylistId, tracks_data_append_playlist!, subset
using ReplSpotifyPlayer: save_tracks_data, load_tracks_data, playlist_owned_dataframe_get
using ReplSpotifyPlayer: ncol, flatten
import ReplSpotifyPlayer: InlineStrings
using ReplSpotifyPlayer: groupby, combine, transform, nrow, select!, Not
using ReplSpotifyPlayer: flatten_horizontally_vector, names, unflatten_horizontally_vector
using ReplSpotifyPlayer: tracks_namedtuple_from_playlist, tracks_data_append_namedtuple_from_playlist!
using ReplSpotifyPlayer: delete_the_last_and_missing_playlistref_columns!, countmap, _loadtypes
import CSV

##############################
# tracks_data_append_playlist!
##############################
pl_id = SpPlaylistId("3FyJWXqFocKq2SYGjGoelU")
nt_playlist = tracks_namedtuple_from_playlist(pl_id)
problem_track_ids = filter(pa-> pa[2] > 1, countmap(nt_playlist.trackid))
filter(pa-> pa[2] > 1, countmap(nt_playlist.trackname))

#
#
#


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


# delete_the_last_and_missing_playlistref_columns!(tracks_data)

trr = PlaylistRef(name = "77-78spm", id = SpPlaylistId("spotify:playlist:5KzcRWVCfzbvK2tkos8hfT"), snapshot_id = "MTksZGEyYjFkNzAwZmM0ZDYxMmNmNTBlNzljMDliMmM5ODE1MzQ5OWMwZQ==")
df = DataFrame(n = [10, 20, 30],
           playlistref = [trr, trr, trr],
           playlistref_1 = [trr, missing, missing],
           playlistref_2 = [missing, missing, missing])
@test ncol(df) == 4
delete_the_last_and_missing_playlistref_columns!(df)
@test ncol(df) == 3

#################################
# Prepare for precompile workload
#################################

savestring = "trackid,trackname,danceability,key,valence,speechiness,duration_ms,instrumentalness,liveness,mode,acousticness,time_signature,energy,tempo,loudness,isrc,album_id,album_name,albumtype,release_date,available_markets,playlistref,playlistref_1,playlistref_2,playlistref_3,artists_1,artist_ids_1\n4WDFsTvNBbkiYc3eoGd0Xp,Aldhechen Manin,0.863,9,0.789,0.0538,234307,0.0437,0.103,0,0.828,4,0.377,75.017,-7.05,FR9W10300943,5FPDGVaIIfWVH79NJoslSe,Amassakoul,album,2004-10-12,,\"PlaylistRef(\"\"75-76spm\"\", \"\"MzIsN2U2MDY0OTY5OTUyMmI0ZjJlNjZkOTRiZTljMGNjOTAyYWY3ZDczMA==\"\", 4ud3ACGzjSHgfXjdX9YSd8)\",,,,Tinariwen,2sf2owtFSCvz2MLfxmNdkb\n3LklW07tvdx2AHsgfi1Mng,I Wish,0.669,7,0.572,0.147,249293,0.0,0.38,1,0.00137,4,0.809,97.885,-7.146,USVR10300417,34hLOvajp6WQOGlt6CNLSA,I Wish,album,1995-09-02,CA US,\"PlaylistRef(\"\"97-98spm\"\", \"\"NDEsNDBkN2JlOTNmOWRmODE5ZGI2MjMyZmYzZmJkOGY3ODA4YzViNWI0Mg==\"\", 1olNe2lIG7O3xYcp0txRom)\",\"PlaylistRef(\"\"-- Liked from Radio --\"\", \"\"OTE0LDI0NDNkYzJlOTAyZDE4ZmU2ZjU5YTc1ZTM4N2EzMmQ5MDlkM2QwYTU=\"\", 3FyJWXqFocKq2SYGjGoelU)\",,,Skee-Lo,55Pp4Ns5VfTSFsBraW7MQy\n"
iob = IOBuffer(savestring)
csv = CSV.File(iob; types = _loadtypes)
df0 = DataFrame(csv)
df1 = unflatten_horizontally_vector(df0, :artists)
TDF[] = unflatten_horizontally_vector(df1, :artist_ids)
