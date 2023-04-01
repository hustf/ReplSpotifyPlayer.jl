# This file wraps functions from Spotify.jl.
# Used by repl_player.jl.

"artist_details_print(context::JSON3.Object) -> nothing"
function artist_details_print(ioc, uri::String)
    artist_id = SpArtistId(uri)
    artist_details_print(ioc, artist_id)
    nothing
end
function artist_details_print(ioc, artist_id::SpArtistId)
    o = artist_get(artist_id)[1]
    print(ioc, o.name)
    io = color_set(ioc, :normal)
    print(io, "  followers: ", o.followers.total)
    print(io, "  genres: ", o.genres)
    print(io, "  images: ", length(o.images))
    color_set(ioc)
    # TODO: consider using images.
    nothing
end
