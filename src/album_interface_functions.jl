# This file wraps functions from Spotify.jl.
# Used by repl_player.jl.

"album_details_print(context::JSON3.Object) -> nothing"
function album_details_print(ioc, uri::String)
    album_id = SpAlbumId(uri)
    album_details_print(ioc, album_id)
    nothing
end
function album_details_print(ioc, album_id::SpAlbumId)
    o = album_get_single(album_id)[1]
    print(ioc, o.name)
    io = color_set(ioc, :normal)
    print(io, "  release date: ", o.release_date)
    print(io, "  label: ", o.label)
    print(io, "  tracks: ", o.total_tracks)
    println(io, "  images: ", length(o.images))
    color_set(ioc)
    nothing
end
