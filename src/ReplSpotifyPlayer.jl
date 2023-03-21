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
export tracks_data_get

"""
TDF[] to access tracks_data in memory. Each row contains a track, features and which playlists refer it.
"""
const TDF = Ref{DataFrame}(DataFrame())
include("types.jl")
include("playlist_interface_functions.jl")
include("tracks_dataframe_functions.jl")
include("tracks_dataframe_lookup_functions.jl")
include("tracks_dataframe_io.jl")
function __init__()
    TDF[] = tracks_data_get(;silent = false)
    save_tracks_data(TDF[])
end
end # module