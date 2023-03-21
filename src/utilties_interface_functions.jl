# This file contains functions used internally by repl_player.jl (the user-facing functions).
# These are second-tier, not called directly by keypresses, rather indirect.
# They do not fit neatly in player_interface_functions or playlist_interface_functions.
# They are based on Spotify.jl/example/

"track_album_artists_string(item::JSON3.Object; link_for_copy = true) -> String"
function track_album_artists_string(item::JSON3.Object; link_for_copy = true)
    a = item.album.name
    ars = item.artists
    vs = [ar.name for ar in ars]
    link = ""
    if link_for_copy
        track_id = SpTrackId(item.id)
        link *= "  " 
        iob = IOBuffer()
        show(IOContext(iob, :color => true), "text/plain", track_id)
        link *= String(take!(iob))
    end
    item.name * " \\ " * a * " \\ " * join(vs, " & ") * link
end