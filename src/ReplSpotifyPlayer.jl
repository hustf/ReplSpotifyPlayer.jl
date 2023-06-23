module ReplSpotifyPlayer
using REPL
using REPL.LineEdit
using REPL: LineEditREPL
using REPL.Terminals: clear_line
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
using StatsBase: countmap
import Spotify.JSON3
import CSV
import CSV.InlineStrings
import Base: tryparse, show, length, iterate
export Spotify
export SpId, SpCategoryId, SpPlaylistId, SpAlbumId, SpTrackId
export SpArtistId
export JSON3
export PlaylistRef, DataFrame
export TDF
export tracks_data_load_and_update, save_tracks_data
export playtracks

"""
TDF[] to access tracks_data currently in memory. Each row contains a track, features and which playlists refer it.

The preferred way is `tracks_data_update()`, which is quite fast too, and saves to disk.
"""
const TDF = Ref{DataFrame}(DataFrame())
const PLAYERPrompt = Ref{LineEdit.Prompt}()
const SEARCHString = Ref{String}("...")
include("types.jl")
include("playlist_interface.jl")
include("player_interface.jl")
include("library_interface.jl")
include("artist_interface.jl")
include("album_interface.jl")
include("tracks_interface.jl")
include("utilties_internal.jl")
include("utilties_user_response.jl")
include("audio_visualization.jl")
include("search_interface.jl")
include("tracks_dataframe.jl")
include("tracks_dataframe_lookup.jl")
include("tracks_dataframe_load_save.jl")
include("housekeeping.jl")
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
    PLAYERPrompt[] = add_seventh_prompt_mode(Base.active_repl)
    define_single_keystrokes!(PLAYERPrompt[])
    # This improves the default when using Windows Terminal.
    # When using VS code, no difference. But note, in VS Code,
    # the terminal may 'blink' when we're using control codes,
    # like in 'print_and_delete'. Very infrequently, VS Code
    # terminal gets messed up (blinking). In that case, restart
    # the application.
    if Sys.iswindows() || lowercase(get(ENV, "COLORTERM", "")) == "truecolor"
        UnicodePlots.truecolors!()
    end
    @info "Type `:` to enter mini player mode, `e` or `⌫ ` to exit."
    nothing
end


# Prior to precompilation tools, after small change, v"1.9.0-beta4":
# @time begin;push!(ENV, "SPOTIFY_NOINIT" => "true"); using ReplSpotifyPlayer;end 
# 63.696591 seconds
# 34.435758 seconds (no changes)
# Update to J 1.9.1, first time:
# @time begin;push!(ENV, "SPOTIFY_NOINIT" => "true"); using ReplSpotifyPlayer;end 
# 261.538231 second
# Second and third run:
# 29.850486 seconds

function __init__()
    if lowercase(get(ENV, "SPOTIFY_NOINIT", "false")) !== "true"
        println("The environment variable SPOTIFY_NOINIT is not set to \"true\". More browser windows than necessary may pop up.")
    end
    init()
end
end # module