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
using PrecompileTools
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
# With init() disabled:
#  1) 10.040503 seconds 2) 4.4 seconds
# With @compile_workload, no real contents:
#  1) 10.040503 seconds 2) 4.4 seconds
# With @compile_workload, plot_audio contents:
#  1) 17.1 seconds 2) 4.6 seconds
# With @compile_workload, also TDF mockup:
#  1) 22.04 seconds 2) 4.7 seconds
# With @compile_workload, also search mockup:
#  1) 29.8 seconds 2) 4.9 seconds
function __init__()
    if lowercase(get(ENV, "SPOTIFY_NOINIT", "false")) !== "true"
        println(stdout, "The environment variable SPOTIFY_NOINIT is not set to \"true\". More browser windows than necessary may pop up.")
    end
    init()
end

@compile_workload begin
    # all calls in this block will be precompiled, regardless of whether
    # they belong to your package or not (on Julia 1.8 and higher)
    ioc = color_set(IOContext(devnull, :print_ids => true, :color => true), :green)
    track_id = SpTrackId("11dFghVXANMlKmJXsNCbNl")
    json_string = """{
        "meta": {\n    "analyzer_version": "4.0.0",\n    "platform": "Linux",\n    "detailed_status": "OK",\n    "status_code": 0,\n    "timestamp": 1495193577,\n    "analysis_time": 6.93906,\n    "input_process": "libvorbisfile L+R 44100->22050"\n  },
        "track": {\n    "num_samples": 4585515,\n    "duration": 207.95985,\n    "sample_md5": "string",\n    "offset_seconds": 0,\n    "window_seconds": 0,\n    "analysis_sample_rate": 22050,\n    "analysis_channels": 1,\n    "end_of_fade_in": 0,\n    "start_of_fade_out": 201.13705,\n    "loudness": -5.883,\n    "tempo": 118.211,\n    "tempo_confidence": 0.73,\n    "time_signature": 4,\n    "time_signature_confidence": 0.994,\n    "key": 9,\n    "key_confidence": 0.408,\n    "mode": 0,\n    "mode_confidence": 0.485,\n    "codestring": "string",\n    "code_version": 3.15,\n    "echoprintstring": "string",\n    "echoprint_version": 4.15,\n    "synchstring": "string",\n    "synch_version": 1,\n    "rhythmstring": "string",\n    "rhythm_version": 1\n  },
        "bars": [\n    {\n      "start": 0.49567,\n      "duration": 2.18749,\n      "confidence": 0.925\n    }\n  ],
        "beats": [\n    {\n      "start": 0.49567,\n      "duration": 2.18749,\n      "confidence": 0.925\n    }\n  ],
        "sections": [\n    {\n      "start": 0,\n      "duration": 6.97092,\n      "confidence": 1,\n      "loudness": -14.938,\n      "tempo": 113.178,\n      "tempo_confidence": 0.647,\n      "key": 9,\n      "key_confidence": 0.297,\n      "mode": -1,\n      "mode_confidence": 0.471,\n      "time_signature": 4,\n      "time_signature_confidence": 1\n    }\n  ],
        "segments": [{"start":0,"duration":0.42367,"confidence":0,"loudness_start":-60,"loudness_max_time":0,"loudness_max":-60,"loudness_end":0,"pitches":[0.764,0.956,1.0,0.981,0.783,0.619,0.577,0.442,0.321,0.152,0.151,0.367],"timbre":[0,171.13,9.469,-28.48,57.491,-50.067,14.833,5.359,-27.228,0.973,-10.64,-7.228]},{"start":0.42367,"duration":0.55764,"confidence":1,"loudness_start":-60,"loudness_max_time":0.044,"loudness_max":-12.76,"loudness_end":0,"pitches":[0.004,0.022,0.003,0.003,0.114,0.006,0.004,0.01,0.014,1.0,0.023,0.01],"timbre":[39.257,75.635,120.155,-21.931,70.006,161.637,-6.818,-4.919,-11.285,21.902,67.779,-4.607]}],
        "tatums": [\n    {\n      "start": 0.49567,\n      "duration": 2.18749,\n      "confidence": 0.925\n    }\n  ]\n}"""
    audio_analysis = JSON3.read(json_string)
    # Before precompilation with @compile_workload
    # @ time plot_audio(ioc, track_id, audio_analysis)
    #  4.908023 seconds (9.24 M allocations: 593.884 MiB, 4.22% gc time, 98.50% compilation time)
    plot_audio(ioc, track_id, audio_analysis)
    #########################
    # Mockup tracks dataframe
    #########################
    savestring = "trackid,trackname,danceability,key,valence,speechiness,duration_ms,instrumentalness,liveness,mode,acousticness,time_signature,energy,tempo,loudness,isrc,album_id,album_name,albumtype,release_date,available_markets,playlistref,playlistref_1,playlistref_2,playlistref_3,artists_1,artist_ids_1\n4WDFsTvNBbkiYc3eoGd0Xp,Aldhechen Manin,0.863,9,0.789,0.0538,234307,0.0437,0.103,0,0.828,4,0.377,75.017,-7.05,FR9W10300943,5FPDGVaIIfWVH79NJoslSe,Amassakoul,album,2004-10-12,,\"PlaylistRef(\"\"75-76spm\"\", \"\"MzIsN2U2MDY0OTY5OTUyMmI0ZjJlNjZkOTRiZTljMGNjOTAyYWY3ZDczMA==\"\", 4ud3ACGzjSHgfXjdX9YSd8)\",,,,Tinariwen,2sf2owtFSCvz2MLfxmNdkb\n3LklW07tvdx2AHsgfi1Mng,I Wish,0.669,7,0.572,0.147,249293,0.0,0.38,1,0.00137,4,0.809,97.885,-7.146,USVR10300417,34hLOvajp6WQOGlt6CNLSA,I Wish,album,1995-09-02,CA US,\"PlaylistRef(\"\"97-98spm\"\", \"\"NDEsNDBkN2JlOTNmOWRmODE5ZGI2MjMyZmYzZmJkOGY3ODA4YzViNWI0Mg==\"\", 1olNe2lIG7O3xYcp0txRom)\",\"PlaylistRef(\"\"-- Liked from Radio --\"\", \"\"OTE0LDI0NDNkYzJlOTAyZDE4ZmU2ZjU5YTc1ZTM4N2EzMmQ5MDlkM2QwYTU=\"\", 3FyJWXqFocKq2SYGjGoelU)\",,,Skee-Lo,55Pp4Ns5VfTSFsBraW7MQy\n"
    iob = IOBuffer(savestring)
    csv = CSV.File(iob; types = _loadtypes)
    df0 = DataFrame(csv)
    df1 = unflatten_horizontally_vector(df0, :artists)
    TDF[] = unflatten_horizontally_vector(df1, :artist_ids)
    # Search internal 
    search_then_select_print(ioc, TDF[]; mock_user_input = "manin")
    ####################
    # Cleanup to be sure
    ####################
    TDF[] = DataFrame()
end







end # module