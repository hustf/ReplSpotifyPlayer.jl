# This file contains functions used internally by repl_player.jl (the user-facing functions).
# These are second-tier, not called directly by keypresses, rather indirect.
# They do not fit neatly in player_interface_functions or playlist_interface_functions.
# They are based on Spotify.jl/example/

"track_album_artists_print(ioc, item::JSON3.Object)"
function track_album_artists_print(ioc, item::JSON3.Object)
    print(ioc, item.name, " \\ ", item.album.name)
    ars = item.artists
    vs = [ar.name for ar in ars]
    print(ioc, " \\ ", join(vs, " & "))
    if get(ioc, :print_ids, false)
        track_id = SpTrackId(item.id)
        print(ioc, "  ")
        show(ioc, MIME("text/plain"), track_id)
        color_reset(ioc)
    end
    nothing
end