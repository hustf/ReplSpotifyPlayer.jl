using Test
push!(ENV, "SPOTIFY_NOINIT" => "true"); using ReplSpotifyPlayer
using ReplSpotifyPlayer: tracks_namedtuple_from_playlist, nrow, ncol, playlist_owned_dataframe_get, subset
using ReplSpotifyPlayer: is_other_playlist_snapshot_in_data, tracks_data_append_playlist!, select!, propertynames
using ReplSpotifyPlayer: DataFrameRow, playlist_details_print, color_set, playlist_get_tracks, make_named_tuple_from_json_object
using ReplSpotifyPlayer: tracks_data_append_namedtuple_from_playlist!, PlaylistRef
# An owned playlist
playlist_id = SpPlaylistId("3FyJWXqFocKq2SYGjGoelU") # ~599 tracks
####################
# Bottom first test.
####################
fields = "items(track(name,id,external_ids,available_markets,album(id,name,album_type,release_date),artists(name,id))), next"
o, waitsec = playlist_get_tracks(playlist_id; fields, limit = 100, market ="");
nt = make_named_tuple_from_json_object(o)
@test nt.artists isa Vector{Vector{String}}
nt1 = tracks_namedtuple_from_playlist(playlist_id)
@test nt1.artists isa Vector{Vector{String}}
@test ncol(DataFrame(nt1)) == 10
@test DataFrame(nt1).artists isa Vector{Vector{String}}
td = DataFrame()
playlist_ref = playlist_ref = PlaylistRef("Test", "dummysnapshot",  playlist_id)
tracks_data_append_namedtuple_from_playlist!(td, playlist_ref, nt1; silent = false)
@test td.artists isa Vector{Vector{String}}

###################
# Higher level test
###################

# get playlists
playlistrefs_df = playlist_owned_dataframe_get(;silent = false) # 487.755 ms

# First a playlist with ~599 tracks
playlistrefs_rw = subset(playlistrefs_df, :name => x-> x .== ("-- Liked from Radio --"))[1,:]
pl_ref = PlaylistRef(playlistrefs_rw)
@time nt_playlist = tracks_namedtuple_from_playlist(pl_ref.id)  #2.4s

# Build tracks data from scratch
tracks_data = DataFrame()
@test ! is_other_playlist_snapshot_in_data(tracks_data, pl_ref)
@time tracks_data_append_playlist!(tracks_data, pl_ref) # 2.7s
@test nrow(tracks_data) > 200
@test tracks_data.artists isa Vector{Vector{String}}

# Pick another playlist with no tracks overlap with tracks_data
playlistrefs_rw = subset(playlistrefs_df, :name => x-> x .== ("Santana"))[1,:]
pl_ref = PlaylistRef(playlistrefs_rw)
nt_playlist = tracks_namedtuple_from_playlist(pl_ref.id)
# Check that there is no ovelap of trackids
@test length(intersect(nt_playlist.trackid, tracks_data.trackid)) == 0
# Append the no-overlap playlist to tracks_data
@time tracks_data_append_playlist!(tracks_data, pl_ref)
# Test that no additional playlistref column was added
@test propertynames(tracks_data)[end] == :playlistref
# Test that both playlistrefs exist.
@test length(unique(tracks_data[!, end])) == 2

# Pick another playlist with tracks overlap with tracks_data
playlistrefs_rw = subset(playlistrefs_df, :name => x-> x .== ("89-90spm"))[1,:]
pl_ref = PlaylistRef(playlistrefs_rw)
nt_playlist = tracks_namedtuple_from_playlist(pl_ref.id)
# Check that there is ovelap of trackids
@test length(intersect(nt_playlist.trackid, tracks_data.trackid)) > 0
# Append the overlap playlist to tracks_data
@time tracks_data_append_playlist!(tracks_data, pl_ref)
# Test that an additional playlistref column was added
@test propertynames(tracks_data)[end] == :playlistref_1
# Test that both playlistrefs exist.
@test length(unique(tracks_data[!, end])) == 2

# Now lookup pl_ref in tracks_data to print details.
# We won't get the full SpPlayistRef from the player
# context, so SpPlaylistId must suffice.

playlist_id = pl_ref.id
# This gets all rows with the playlist
row_contains_playlist(rw::DataFrameRow, playlist_id) = any(ref -> ! ismissing(ref) && ref.id == playlist_id, rw[r"playlistref"])
filter(rw-> row_contains_playlist(rw, playlist_id), tracks_data)

# If a playlist is in tracks_data, we still need to call the web API.
# This is because we don't store the playlist description locally.
ioc = color_set(IOContext(stdout, :print_ids => true), :green)
@time playlist_details_print(ioc, playlist_id) #0.43s

# Now with a public playlist. This accesses the web service.
@time playlist_details_print(ioc, SpPlaylistId("0wsYVMq9Tl3uY3zMPy5e6H"))