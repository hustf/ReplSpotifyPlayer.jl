# This file contains functions used internally by repl_player.jl, the user facing functions.
# Some of these wrappers translate into ReplSpotifyPlayer types and DataFrame.
# These are second-tier, not called directly by keypresses, rather indirect.
# They wrap hierarcical functionality in Spotify.jl/library
# They are based on Spotify.jl/example/


"is_track_in_library(track_id::SpTrackId) -> Bool"
is_track_in_library(track_id::SpTrackId) = Spotify.Tracks.tracks_get_contains([track_id])[1][1]

"delete_track_from_library_print(track_id, , item::JSON3.Object) -> Bool"
function delete_track_from_library_print(ioc, track_id, item::JSON3.Object)
    if is_track_in_library(track_id)
        io = color_set(ioc, :yellow)
        print(io, "Going to delete \"")
        track_album_artists_print(io, item)
        println(io, "\" from your library.")
        color_set(ioc)
        Spotify.Tracks.tracks_remove_from_library([track_id])
        return true
    else
        io = color_set(ioc, :yellow)
        print(io, "  ❌ Can't delete \"")
        track_album_artists_print(ioc, item)
        println(io, "\"\n  - Not in library.")
        color_set(ioc)
        return false
    end
end