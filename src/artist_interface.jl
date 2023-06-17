# This file wraps functions from Spotify.jl.
# Also prints artists.

"""
    artist_no_details_print(ioc, rw::DataFrameRow)
    artist_no_details_print(ioc, artist_name, artist_id::SpArtistId)
"""
function artist_no_details_print(ioc, rw::DataFrameRow)
    if hasproperty(rw, :artist_ids)
         artist_no_details_print(ioc, rw[:artists], rw[:artist_ids])
    else
        artist_no_details_print(ioc, rw[:artist], rw[:artist_id])
    end
end
function artist_no_details_print(ioc, artists::Vector, artist_ids::Vector)
    first = true
    for (artist_name, id) in zip(artists, artist_ids)
        if first
            first = false
        else
            print(ioc, " & ")
        end
        artist_no_details_print(ioc, artist_name, SpArtistId(id))
    end
end
function artist_no_details_print(ioc, artist_name, artist_id::SpArtistId)
    print(color_set(ioc, 217), artist_name)
    color_set(ioc)
    if get(ioc, :print_ids, false)
        print(ioc, "  ")
        show(ioc, MIME("text/plain"), artist_id)
        color_set(ioc)
    end
end

"""
    artist_details_print(ioc, uri::String) ---> nothing\\
    artist_details_print(ioc, artist_id::SpArtistId) ---> nothing\\
"""
artist_details_print(ioc, uri::String) = artist_details_print(ioc, SpArtistId(uri))
function artist_details_print(ioc, artist_id)
    o = artist_get(artist_id)[1]
    artist_no_details_print(ioc, o.name, artist_id)
    print(color_set(ioc, :light_black), "  followers: ")
    print(color_set(ioc, :normal), o.followers.total)
    gen = String.(o.genres)
    if ! isempty(gen)
        genres_print(ioc, String.(o.genres))
    end
    color_set(ioc)
    # Consider: We might include images through Sixels.
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
    nothing'm'
end
function artist_tracks_in_playlists_print(ioc, artist_id::SpArtistId; enumerator = 1)
    # Called from current_context_print -> artist_tracks_in_playlists_print if the context is an artist.
    artist_tracks_in_playlists_print(ioc, tracks_data_update(), artist_id ; enumerator)
end

function artist_tracks_in_playlists_print(ioc, tracks_data, artist_id; enumerator = 1)
    # One row per artist
    per_artist_data = flatten(tracks_data, [:artists, :artist_ids])
    # Drop other artists.
    artist_data = sort(filter(:artist_ids => ==(artist_id), per_artist_data), :trackname)
    io = color_set(ioc, :light_black)
    if nrow(artist_data) == 0
        println(color_set(ioc), "\n\tArtist has no tracks in your owned playlist.")
        return artist_data
    end
    delete_the_last_and_missing_playlistref_columns!(artist_data)
    print(color_set(io), " has ")
    if nrow(artist_data) == 1
        print(color_set(io, :normal), " one")
        print(color_set(io, :light_black), " track ")
    else
        print(color_set(io, :normal), " ", nrow(artist_data))
        print(color_set(io, :light_black), " tracks ")
    end
    print(color_set(io), "in your playlists. This is where they are referred:")
    # Flatten artist_data further, to one row per playlist reference
    transform!(artist_data, r"playlistref"  => ByRow((cells...) -> filter(! ismissing, cells)) => :pl_refs)
    select!(artist_data, Not(r"playlistref"))
    artist_track_context_data = flatten(artist_data, [:pl_refs])
    rename!(artist_track_context_data, :pl_refs => :pl_ref)
    # Print this part
    enumerated_track_album_artist_context_print(ioc, artist_track_context_data; enumerator)
    println(color_set(ioc))
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
    println(color_set(ioc))
    df
end
