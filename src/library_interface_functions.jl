# This file contains functions used internally by repl_player.jl, the user facing functions.
# Some of these wrappers translate into ReplSpotifyPlayer types and DataFrame.
# These are second-tier, not called directly by keypresses, rather indirect.
# They wrap hierarcical functionality in Spotify.jl/library
# They are based on Spotify.jl/example/


"is_track_in_library(track_id::SpTrackId) -> Bool"
is_track_in_library(track_id::SpTrackId) = Spotify.Tracks.tracks_get_contains([track_id])[1][1]

"delete_track_from_library(track_id, playing_now_desc) -> String, prints to stdout"
function delete_track_from_library(track_id, playing_now_desc)
    if is_track_in_library(track_id)
        printstyled(stdout, "Going to delete \" * playing_now_desc * "\" from your library.\n", color = :yellow)
        Spotify.Tracks.tracks_remove_from_library([track_id])
        return ""
    else
        printstyled(stdout, "\n  Can't delete \"" * playing_now_desc * "\"\n  - Not in library.\n", color = :red)
        return "❌"
    end
end