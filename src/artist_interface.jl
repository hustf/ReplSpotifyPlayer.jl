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
    artist_tracks_in_playlists_print(ioc, uri::String) ---> nothing\\
    artist_tracks_in_playlists_print(ioc, artist_id::SpArtistId; enumerator = 1) ---> nothing\\
    artist_tracks_in_playlists_print(ioc, artist_id, tracks_data; ; enumerator = 1) ---> nothing\\
"""
function artist_tracks_in_playlists_print(ioc, uri::String)
    # Called from current_context_print if the context is an artist.
    artist_id = SpArtistId(uri)
    artist_tracks_in_playlists_print(ioc, artist_id)
    nothing
end
function artist_tracks_in_playlists_print(ioc, artist_id::SpArtistId; enumerator = 1)
    # Called from current_context_print -> artist_tracks_in_playlists_print if the context is an artist.
    artist_tracks_in_playlists_print(ioc, tracks_data_update(), artist_id ; enumerator)
end

function artist_tracks_in_playlists_print(ioc, tracks_data, artist_id; enumerator = 1)
    color_set(ioc, :light_black)
    # One row per artist
    per_artist_data = flatten(tracks_data, [:artists, :artist_ids])
    # Drop other artists.
    artist_data = sort(filter(:artist_ids => ==(artist_id), per_artist_data), :trackname)
    if nrow(artist_data) == 0
        println(color_set(ioc, :light_black), "\n\tArtist has no tracks in your owned playlist.")
        return artist_data
    end
    delete_the_last_and_missing_playlistref_columns!(artist_data)
    color_set(ioc)
    artist_name = artist_data[1, :artists]
    io = color_set(ioc, :yellow)
    print(io, "\n", artist_name)
    printstyled(io, " has ", color =:light_black)
    if nrow(artist_data) == 1
        print(io, " one")
        printstyled(io, " track ", color = :light_black)
    else
        print(io, " ", nrow(artist_data))
        printstyled(io, " tracks ", color = :light_black)
    end
    printstyled(io, "in your playlists. This is where they are referred:", color = :light_black)
    # Flatten artist_data further, to one row per playlist reference
    transform!(artist_data, r"playlistref"  => ByRow((cells...) -> filter(! ismissing, cells)) => :pl_refs)
    select!(artist_data, Not(r"playlistref"))
    artist_track_context_data = flatten(artist_data, [:pl_refs])
    # Print this part
    io_ = color_set(io, :blue)
    for dfrw in eachrow(artist_track_context_data)
        color_set(io, :normal)
        track_id = dfrw[:trackid]
        track_name = dfrw[:trackname]
        print(io, "\n  ", track_name, " ")
        if get(ioc, :print_ids, false)
            print(io, "  ")
            show(io, MIME("text/plain"), track_id)
            color_set(io)
        end
        print(color_set(io), "\n", lpad(string(enumerator), 7), "    ")
        enumerator += 1
        playlist_no_details_print(color_set(io_), dfrw.pl_refs)
        color_set(io)
    end
    println(ioc)
    color_set(ioc)
    artist_track_context_data
end

function artists_tracks_request_play_in_context_print(ioc, item::JSON3.Object)
    type = item.type
    if type == "track"
        artist_ids = [SpArtistId(a.uri) for a in item.artists]
    else
        throw("Didn't think of $(string(type))")
    end
    artists_tracks_request_play_in_context_print(ioc, artist_ids)
end

function artists_tracks_request_play_in_context_print(ioc, artist_ids::Vector{SpArtistId})
    tracks_data = tracks_data_update()
    df = DataFrame()
    enumerator = 1
    for aid in artist_ids
        dfa = artist_tracks_contexts_print(ioc, tracks_data, aid; enumerator)
        if ! isempty(dfa)
            df = vcat(df, dfa)
            enumerator = nrow(df) + 1
        end
    end
    if ! isempty(df)
        select_track_context_and_play_print(ioc, df)
    end
    nothing
end
function artist_tracks_contexts_print(ioc, tracks_data, artist_id; enumerator = 1)
    color_set(ioc)
    artist_details_print(ioc, artist_id)
    df = artist_tracks_in_playlists_print(ioc, tracks_data, artist_id; enumerator)
    println(ioc)
    df
end
