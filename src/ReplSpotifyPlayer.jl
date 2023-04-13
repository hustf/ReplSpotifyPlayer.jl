module ReplSpotifyPlayer
# We'd like to
# Lookup trackid -> playlist_ids
# Lookup features -> track_ids
# Lookup artists -> track_ids, playlist_ids
# Statistics for a playlist in terms of audio features and genres

using REPL
using REPL.LineEdit 
using REPL: LineEditREPL
using Base: @kwdef, text_colors #, active_repl
using Markdown
using DataFrames
using UnicodePlots
import DataFrames.PrettyTables
import DataFrames.PrettyTables: _render_text
using Spotify
using Spotify: SpType, get_user_country, credentials_contain_scope
using Spotify.Player, Spotify.Playlists, Spotify.Tracks, Spotify.Artists, Spotify.Albums, Spotify.Search
using Statistics

import Spotify.JSON3
import CSV
import Base: tryparse, show
export Spotify
export SpId, SpCategoryId, SpPlaylistId, SpAlbumId, SpTrackId
export SpArtistId
export Player
export Albums

#, Spotify.Playlists, Spotify.Tracks, Spotify.Artists

export JSON3
export PlaylistRef, TrackRef, authorize, DataFrame

export TDF
export is_playlist_in_data, is_playlist_snapshot_in_data, is_other_playlist_snapshot_in_data
export is_track_in_data
export tracks_data_load_and_update, save_tracks_data
export metronome, playtracks
export artist_get_all_albums

"""
TDF[] to access tracks_data currently in memory. Each row contains a track, features and which playlists refer it.

The preferred way is `tracks_data_update()`, which is quite fast too, and saves to disk.
"""
const TDF = Ref{DataFrame}(DataFrame())
const PLAYERprompt = Ref{LineEdit.Prompt}()
include("types.jl")
include("playlist_interface_functions.jl")
include("player_interface_functions.jl")
include("library_interface_functions.jl")
include("artist_interface_functions.jl")
include("album_interface_functions.jl")
include("utilties_interface_functions.jl")
include("tracks_dataframe_functions.jl")
include("tracks_dataframe_lookup_functions.jl")
include("tracks_dataframe_io.jl")
include("replmode.jl")
include("repl_player.jl")
include("utilties.jl")

function init()
    repl_player_default_scopes = ["user-read-private", "user-modify-playback-state", "user-read-playback-state", "playlist-modify-private", 
        "playlist-read-private", "playlist-read-collaborative", "user-library-read"]
    if ! Spotify.credentials_contain_scope(repl_player_default_scopes)
        apply_and_wait_for_implicit_grant(;scopes = repl_player_default_scopes)
    end

    # This gets the current subscribed playlists, and creates 
    # or updates a local tracks data file and in-memory copy:
    tracks_data_update()
    
    # Configure miniprompt, then tell Julia about it. 

    @assert isdefined(Base, :isinteractive)
    @assert Base.isinteractive()
    @assert isdefined(Base, :active_repl)
    PLAYERprompt[] = add_seventh_prompt_mode(Base.active_repl) 
    define_single_keystrokes!(PLAYERprompt[])
    @info "Type : to enter mini player mode, e to exit."
end

function __init__()
    init()
end
end # module