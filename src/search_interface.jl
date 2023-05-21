
"""
    get_all_search_result_track_objects(q)
    ---> Vector{JSON3.Object}

The web API used directly has a limit of 50 results,
default is 20.
"""
function get_all_search_result_track_objects(q)
    results = Vector{JSON3.Object}()
    type = "track"
    limit = 50
    o, waitsec = Search.search_get(q, type = type, limit = limit)
    append!(results, collect(o.tracks.items))
    while o.tracks.next !== nothing && ! isempty(o.tracks.items) && length(o.tracks.items) > 1
        offset = length(results)
        o, waitsec = Search.search_get(q, type = type, limit = limit, offset = offset)
        append!(results, collect(o.tracks.items))
    end
    results
end

"""
    get_all_search_result_album_objects(q; market = "")
    ---> Vector{JSON3.Object}

The web API used directly has a limit of 50 results,
default is 20.
"""
function get_all_search_result_album_objects(q; market = "")
    results = Vector{JSON3.Object}()
    type = "album"
    limit = 50
    o, waitsec = Search.search_get(q, type = type, limit = limit, market = market)
    append!(results, collect(o.albums.items))
    while o.albums.next !== nothing && ! isempty(o.albums.items) && length(o.albums.items) > 1
        offset = length(results)
        o, waitsec = Search.search_get(q, type = type, limit = limit, offset = offset, market = market)
        append!(results, collect(o.albums.items))
    end
    results
end


"""
    get_checked_search_result_album_objects(artist_id::SpArtistId; market = "")

This unfortunately does not return all albums. `artist_get_all_albums` works better.

# Example
```
julia> artist_id = SpArtistId("69NjH5MsRLr0CX0zSlGmN3")
spotify:artist:69NjH5MsRLr0CX0zSlGmN3

julia> vo = get_checked_search_result_album_objects(artist_id);

julia> length(vo)
8
```

"""
function get_checked_search_result_album_objects(artist_id::SpArtistId; market = "")
    a = artist_get(artist_id)[1]
    get_checked_search_result_album_objects(artist_id, a.name; market)
end
function get_checked_search_result_album_objects(artist_id::SpArtistId, artist_name; market = "")
    vec_objs = get_all_search_result_album_objects(Spotify.HTTP.escapeuri("artist:$artist_name"); market)
    function checked(o)
        o.album_type !== "album" && return false
        v_name_match = map(a-> a.name == artist_name , o.artists)
        ! any(v_name_match) && return false
        v_id_match = map(a-> SpArtistId(a.id) == artist_id , o.artists)
        ! any(v_id_match) && return false
        true
    end
    filter(checked, vec_objs)
end