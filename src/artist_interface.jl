# This file wraps functions from Spotify.jl.
# Used by repl_player.jl.

"""
    artist_details_print(ioc, uri::String) ---> nothing\\
    artist_details_print(ioc, artist_id::SpArtistId) ---> nothing\\
"""
artist_details_print(ioc, uri::String) = artist_details_print(ioc, SpArtistId(uri))
function artist_details_print(ioc, artist_id)
    o = artist_get(artist_id)[1]
    print(ioc, o.name)
    io = color_set(ioc, :normal)
    print(io, "  followers: ", o.followers.total)
    gen = String.(o.genres)
    if ! isempty(gen)
        genres_print(io, String.(o.genres))
    end
    if get(io, :print_ids, false)
        print(io, "  ")
        show(io, MIME("text/plain"), artist_id)
    end
    color_set(ioc)
    # We might include images through Sixels.
    nothing
end


"""
    artist_tracks_in_data_print(ioc, uri::String) ---> nothing\\
    artist_tracks_in_data_print(ioc, artist_id::SpArtistId) ---> nothing\\
    artist_tracks_in_data_print(ioc, artist_id, tracks_data) ---> nothing\\

This can be especially time consuming, so some progress indication when accessing
the web API is probably in order.
Convey progress feedback through io context: :silent=>false.
"""
function artist_tracks_in_data_print(ioc, uri::String)
    artist_id = SpArtistId(uri)
    artist_tracks_in_data_print(ioc, artist_id)
    nothing
end
function artist_tracks_in_data_print(ioc, artist_id::SpArtistId)
    artist_tracks_in_data_print(ioc, artist_id, tracks_data_update())
end

function artist_tracks_in_data_print(ioc, artist_id, tracks_data)
    color_set(ioc, :light_black)
    tracks_album_artist_playlists_data = select(tracks_data, :artists, :artist_ids,:trackid, :trackname, :albumtype, :album_name, :isrc, r"playlistref")
    # One row per artist
    per_artist_data = flatten(tracks_data, [:artists, :artist_ids])
    # Drop other artists.
    df = sort(filter(:artist_ids => ==(artist_id), per_artist_data), :trackname)
    if nrow(df) == 0
        println(color_set(ioc, :light_black), "\tArtist has no tracks in your owned playlist.")
        return nothing
    end
    all_track_ids = df[!, :trackid]
    color_set(ioc)
    artist_name = df[1, :artists]
    io = color_set(ioc, :yellow)
    print(io, "\n", artist_name)
    printstyled(io, " has ", color =:light_black)
    if nrow(df) > 0
        if nrow(df) == 1
            print(io, " One")
            printstyled(io, " track in your playlists: ", color = :light_black)
        else
            print(io, " ", nrow(df))
            printstyled(io, " tracks in your playlists: ", color = :light_black)
        end
        for dfrw in eachrow(df)
            color_set(io, :normal)
            track_id = dfrw[:trackid]
            track_name = dfrw[:trackname]
            print(io, "\n  ", track_name, " ")
            if get(ioc, :print_ids, false)
                print(io, "  ")
                show(io, MIME("text/plain"), track_id)
                color_set(io)
            end
            io_ = color_set(io, :blue)
            playlistrefs = filter(x-> ! ismissing(x), collect(dfrw[r"playlistref"]))
            @assert length(playlistrefs) > 0
            for l in playlistrefs
                if ! ismissing(l)
                    print(io_, "\n    ")
                    playlist_no_details_print(io_, l)
                end
            end
            color_set(io)
        end
    else
        println(io, "None occur in your playlists. This function needs some testing.")
    end
    println(ioc)
    color_set(ioc)
    nothing # Consider returning these tracks to a play queue. Pri below rhytm graph.
end

function artist_and_tracks_in_data_print(ioc, item::JSON3.Object)
    type = item.type
    if type == "track"
        artist_ids = [SpArtistId(a.uri) for a in item.artists]
    else
        throw("Didn't think of $(string(type))")
    end
    artist_and_tracks_in_data_print.(ioc, artist_ids)
end

function artist_and_tracks_in_data_print(ioc, artist_id)
    color_set(ioc)
    artist_details_print(ioc, artist_id)
    println(ioc)
    artist_tracks_in_data_print(ioc, artist_id)
end
