# This file wraps functions from Spotify.jl.
# Used by repl_player.jl.

"""
    artist_details_print(ioc, uri::String) -> nothing
    artist_details_print(ioc, artist_id::SpArtistId) -> nothing
"""
function artist_details_print(ioc, uri::String)
    artist_id = SpArtistId(uri)
    artist_details_print(ioc, artist_id)
    nothing
end
function artist_details_print(ioc, artist_id)
    o = artist_get(artist_id)[1]
    print(ioc, o.name)
    io = color_set(ioc, :normal)
    print(io, "  followers: ", o.followers.total)
    print(io, "  genres: ", o.genres)
    if get(io, :print_ids, false)
        print(io, "  ")
        show(io, MIME("text/plain"), artist_id)
    end
    color_set(ioc)
    # TODO: consider using images.
    nothing
end


"""
    artist_tracks_in_data_print(ioc, uri::String) -> nothing
    artist_tracks_in_data_print(ioc, artist_id::SpArtistId) -> nothing
    artist_tracks_in_data_print(ioc, artist_id, tracks_data) -> nothing

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
    silent = get(ioc, :silent, :true)
    color_set(ioc, :light_black)
    all_track_ids = artist_get_all_tracks(artist_id;  silent)
    color_set(ioc)
    all_tracks_df = DataFrame(:trackid => all_track_ids)
    used_tracks_df = innerjoin(tracks_data, all_tracks_df, on = :trackid)
    artist_name = artist_get(artist_id)[1].name
    io = color_set(ioc, :yellow)
    print(io, "\n", artist_name)
    printstyled(io, " has ", color =:light_black)
    print(io, length(all_track_ids))
    printstyled(io, " tracks on Spotify. ", color = :light_black)
    if nrow(used_tracks_df) > 0
        if nrow(used_tracks_df) == 1
            printstyled(io, " One track in your playlists: ", color = :light_black)
        else
            printstyled(io, " ", nrow(used_tracks_df), " tracks in your tracks data: ", color = :light_black)
        end
        for dfrw in eachrow(used_tracks_df)
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
            if length(playlistrefs) > 0
                for l in playlistrefs 
                    if ! ismissing(l)
                        print(io_, "\n    ")
                        playlist_no_details_print(io_, l)
                    end
                end
                println(io_)
            else
                println(io_, "  Found in TDF[], but not currently in a playlist you own. ")
            end
            color_set(io)
        end
    else
        println(io, "None occur in your playlists.")
    end
    color_set(ioc)
    println(ioc)
    nothing
end










"""
    artist_get_all_albums(artist_id; country = get_user_country(), include_groups = "")
    -> Vector{SpAlbumId},  prints to stdout

# Non-obious parameters

- include_groups : A comma-separated list of keywords that will be used to filter the response.
    If not supplied, all album types will be returned.
    Valid values are:
    * `album`
    * `single`
    * `compilation`
    * `appears_on`

# Example

```
julia> artist_id = "spotify:artist:2sf2owtFSCvz2MLfxmNdkb"

julia> artist_get_all_albums(artist_id)
61-element Vector{Spotify.SpAlbumId}:
 spotify:album:4flAylJfbXX7DVPH7oaS6d
 spotify:album:1leWzxXRfb2h3JZ0tjAt7s
 spotify:album:1oLBDxQlDGNuVvi8QuKKEA
 spotify:album:2CXY5q62zOgU7Ju4rA7FMw
 spotify:album:67SgIr5XQiQg4xYI7zFM4Q
 ⋮
 spotify:album:1WacHRxZ1QHMzRZ2WH96gt
 spotify:album:2Y7nG4LCOytZPetc1mnSC1
 spotify:album:0Dg03V02HduzUmPSOPugW1
 spotify:album:5W3fyI4YPle5wruoB9mBOX
```
"""
function artist_get_all_albums(artist_id; country = get_user_country(), include_groups = "")
    batchsize = 50
    albums = Vector{SpAlbumId}()
    for batchno = 0:200
        offset = batchno * batchsize
        json, waitsec = artist_get_albums(artist_id; limit = batchsize, offset, country)
        isempty(json) && break
        waitsec > 0 && throw("Too fast, whoa!")
        l = length(json.items)
        l == 0 && break
        for item in json.items
            album_id = SpAlbumId(item.uri)
            push!(albums, album_id)
        end
    end
    albums
end





"""
    artist_get_all_tracks(artist_id; silent = true, country = get_user_country())
    -> Vector{SpTrackId},  prints to stdout

This gets all track_ids from the web API, whether that occurs in a user playlist or not.

This is intended for use in finding those of an artist's tracks which occur
in owned playlists (and perhaps user library). Considered too slow for many artists at a time.

# NOTE [Track Relinking](https://developer.spotify.com/documentation/web-api/concepts/track-relinking)
"
The availability of a track depends on the country registered in the user’s Spotify profile settings.
Often Spotify has several instances of a track in its catalogue, each available in a different set of markets.
 This commonly happens when the track the album is on has been released multiple times under different
 licenses in different markets.

These tracks are linked together so that when a user tries to play a track that isn’t available in their own
market, the Spotify mobile, desktop, and web players try to play another instance of the track that is available
 in the user’s market.
"

# Example
```
julia> artist_id = "spotify:artist:2sf2owtFSCvz2MLfxmNdkb"

julia> @time artist_get_all_tracks(artist_id)
9.662973 seconds (40.95 k allocations: 10.739 MiB, 0.16% gc time)
692-element Vector{SpTrackId}:
 spotify:track:4FsVaGWVuYX8TqKQpwZYtd
 spotify:track:6unJkSbcI0I8Ak88IRu35I
 spotify:track:1b8V2JRw0YJiN9jeBWkAPg
 spotify:track:1raugzX28SqqCiRXQQrb4z
 spotify:track:0yox0qriKo0WWUVpoLtK5l
 spotify:track:109R1RqbpPmPCP0OtQLFXz
 spotify:track:5lqhsv5tW76GB3WBL5vh59
 spotify:track:1lH8iTfrXyg2RFNbRT4sgO
 spotify:track:6zLVUIWvIYUsRNMsrhuJ36
 ⋮
 spotify:track:4FyUafYjyC8n0GjkdOkhry
 spotify:track:5y0fsgpF0CICt77CwQkIFA
 spotify:track:1oZYMquWGyr0SGQ8hhjOvj
 spotify:track:6TFINWC5oWjDe4emrxd6H7
 spotify:track:4oaeGnrn91FNRWrAGcegYi
 spotify:track:2YOTbb7xL2I3dOsSiwsypP
 spotify:track:3W9IchAxK6quv4gwWG4fwJ
 spotify:track:3rHXf9TY0SmaJuqHVSl3dc
 spotify:track:0aNBvUgi1V8hI4LwMMhSjV

```

"""
function artist_get_all_tracks(artist_id; silent = true, country = get_user_country())
    tracks_w_duplicates = Vector{SpTrackId}()
    album_ids = artist_get_all_albums(artist_id; country)
    ! silent && println(stdout, "Retrieving tracks in albums:  ")
    for album_id in album_ids
        json, waitsec = album_get_single(album_id; market = country)
        waitsec > 0 && throw("Too fast, whoa!")
        isempty(json) && throw("Error getting album_id $album_id")
        ! silent && print(stdout, json.name, "  ")
        for item in json.tracks.items
            track_id = SpTrackId(item.id)
            push!(tracks_w_duplicates, track_id)
        end
    end
    ! silent && println(stdout)
    unique(tracks_w_duplicates)
end




function artist_and_tracks_in_data_print(ioc, item::JSON3.Object)
    type = item.type
    if type == "track"
        artist = item.artists[1]
        artist_id = SpArtistId(artist.uri)
    else
        throw("Didn't think of $(string(type))")
    end
    artist_and_tracks_in_data_print(ioc, artist_id)
end
function artist_and_tracks_in_data_print(ioc, artist_id)
    artist_details_print(ioc, artist_id)
    println(ioc)
    artist_tracks_in_data_print(ioc, artist_id)
end