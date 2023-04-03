# This file wraps functions from Spotify.jl.
# Used by repl_player.jl.

"""
album_details_print(ioc, uri) -> nothing
album_details_print(ioc, album_id::SpAlbumId) -> nothing
album_details_print(ioc, album_id::SpAlbumId, o::JSON3.Object) -> nothing
"""
album_details_print(ioc, uri::String) = album_details_print(ioc, SpAlbumId(uri))
function album_details_print(ioc, album_id::SpAlbumId)
    album = album_get_single(album_id)[1]
    album_details_print(ioc, album_id, album)
end

function album_details_print(ioc, album_id, album::JSON3.Object)
    print(ioc, album.name)
    io = color_set(ioc, :normal)
    print(io, "  release date: ", album.release_date)
    print(io, "  label: ", album.label)
    print(io, "  tracks: ", album.total_tracks)
    if get(io, :print_ids, false)
        print(io, "  ")
        show(io, MIME("text/plain"), album_id)
    end
    color_set(ioc)
    nothing
end
