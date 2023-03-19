module ReplSpotifyPlayer
# We'd like to
#Lookup trackid -> playlist_ids
#Lookup features -> track_ids
#Lookup artists -> track_ids, playlist_ids
#update data when snapshot number for a playlist changes.
using Spotify
using Spotify: SpType
using Base: @kwdef
using DataFrames
import DataFrames.PrettyTables
import DataFrames.PrettyTables: _render_text
using Spotify.Tracks
import CSV
import Base: tryparse, show
export Spotify
export SpId, SpCategoryId, SpPlaylistId, SpAlbumId, SpTrackId
export SpArtistId
export JSON3
export PlaylistRef, TrackRef, authorize, DataFrame

export TDF
export is_playlist_in_data, is_playlist_snapshot_in_data, is_other_playlist_snapshot_in_data
export is_track_in_data
export trackrefs_dataframe_get

#temp
#export trackrefs_dataframe_get, load_tracks_data, 
#    playlist_owned_dataframe_get, trackrefs_dataframe_append!, 
#    trackrefs_append_audio_features!, track_ids_and_names_in_playlist,
#    save_tracks_data, Spotify, Tracks, apply_and_wait_for_implicit_grant,
#    TDF
#
const TDF = Ref{DataFrame}(DataFrame())
include("types.jl")
include("playlist_interface_functions.jl")
include("tracks_dataframe_functions.jl")
include("tracks_dataframe_lookup_functions.jl")
function __init__()
    additional_scopes = ["playlist-read-collaborative", "playlist-read-collaborative", "user-read-private", 
        "user-modify-playback-state", "user-read-playback-state", "playlist-modify-private", 
        "playlist-read-private"]
    if ! Spotify.credentials_contain_scope(additional_scopes)
        apply_and_wait_for_implicit_grant(;scopes= unique(vcat(additional_scopes, Spotify.DEFAULT_IMPLICIT_GRANT)))
    end
    TDF[] = trackrefs_dataframe_get(;silent = false) # TEMP DEBUG
    save_tracks_data(TDF[])
end
end # module