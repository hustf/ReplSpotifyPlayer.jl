# This file wraps functions from Spotify.jl.
# Used by repl_player.jl.

"""
album_details_print(ioc, uri) ---> nothing\\
album_details_print(ioc, album_id::SpAlbumId) ---> nothing\\
album_details_print(ioc, album_id::SpAlbumId, o::JSON3.Object) ---> nothing\\
"""
album_details_print(ioc, uri::String) = album_details_print(ioc, SpAlbumId(uri))
function album_details_print(ioc, album_id::SpAlbumId)
    market = ""
    album = album_get_single(album_id; market)[1]
    album_details_print(ioc, album_id, album)
end
function album_details_print(ioc, album_id, album::JSON3.Object)
    album_no_details_print(IOContext(ioc, :print_date => true), album.name, album.release_date, album_id)
    io = color_set(ioc, :normal)
    print(color_set(io, :light_black), "  label: ")
    print(color_set(io, :normal), album.label)
    print(color_set(io, :light_black), "  tracks: ")
    print(color_set(io, :normal), album.total_tracks)
    color_set(ioc)
    nothing
end

"""
    album_no_details_print(ioc, rw::DataFrameRow)
    album_no_details_print(ioc, album_name, release_date, album_id::SpAlbumId)
"""
album_no_details_print(ioc, rw::DataFrameRow) = album_no_details_print(ioc, rw[:album_name], rw[:release_date], rw[:album_id])
function album_no_details_print(ioc, album_name, release_date, album_id::SpAlbumId)
    print(color_set(ioc, 107), album_name)
    color_set(ioc)
    if get(ioc, :print_date, false)
        print(ioc, " {", release_date, "}")
    end
    if get(ioc, :print_ids, false)
        print(ioc, "  ")
        show(ioc, MIME("text/plain"), album_id)
        color_set(ioc)
    end
end


"""
    album_get_id_and_data(context::JSON3.Object)
    ---> (::SpAlbumId, ::DataFrame)
"""
function album_get_id_and_data(context::JSON3.Object)
    album_id = SpAlbumId(context.uri)
    album_data =  tracks_data_from_album(album_id)
    tracks_data_append_audio_features!(album_data; silent = false)
    # For skimming through albums, 'popularity' is an important indication.
    # But we do not store 'popularity' in the local track data file
    # because it can vary quickly with time.
    o = get_multiple_tracks(album_data.trackid)
    @assert length(o) == nrow(album_data)
    vpop = map(i -> i.popularity , o)
    album_data.popularity = vpop
    # We can save a call by also adding album details.
    album_data.album_id = repeat([album_id], nrow(album_data))
    album_data.album_name = map(i -> i.album.name , o)
    album_data.albumtype = map(i -> i.album.type , o)
    @assert ! isempty(album_data)
    album_id, album_data
end




"""
    tracks_data_from_album(album_id::SpAlbumId)

# Arguments

- album_id       Album id to add tracks from
"""
function tracks_data_from_album(album_id::SpAlbumId)
    nt_album = tracks_namedtuple_from_album(album_id)
    DataFrame(nt_album)
end



"""
    tracks_namedtuple_from_album(album_id::SpAlbumId)
    ---> NamedTuple{field_names}(field_values)
"""
function tracks_namedtuple_from_album(album_id::SpAlbumId)
    o, waitsec = album_get_tracks(album_id; limit = 50, market = "");
    nt = make_named_tuple_from_album_object(o)
    @assert isnothing(o.next)
    nt
end

"""
    function make_named_tuple_from_album_object(o)
        ---> NamedTuple{field_names}(field_values)

o is the JSON object from album_get_tracks
"""
function make_named_tuple_from_album_object(o)
    trackid =  map(i -> SpTrackId(i.id) , o.items)
    trackname =  map(i -> string(i.name)  , o.items)
    artists =  map(o.items) do i
        map(i.artists) do a
            string(a.name)
        end
    end
    artist_ids =  map(o.items) do i
        map(i.artists) do a
            SpArtistId(a.id)
        end
    end
    available_markets = map(i -> join(i.available_markets, " "), o.items)
    # Make output a NamedTuple...
    field_names = (
        :trackid,
        :trackname,
        :artists,
        :artist_ids,
        :available_markets)
    field_values = [trackid,
        trackname,
        artists,
        artist_ids,
        available_markets]
    NamedTuple{field_names}(field_values)
end