# This file wraps functions from Spotify.jl.
# Used by tracks_dataframe.jl
# Some of these wrappers translate into ReplSpotifyPlayer types and DataFrame.

# Some are based on Spotify.jl/example/
"""
    playlist_owned_dataframe_get(; silent = true)

# Example

```
julia> playlist_owned_dataframe_get()
87×3 DataFrame
 Row │ name          snapshot_id                        id
     │ String        String                             SpPlayli…
─────┼─────────────────────────────────────────────────────────────────────────
   1 │ Santana       MTUsZjkxNTk5ZTNjZmU5NTAwNjVmZmMw…  3NlsEQpwa0EGKoWjI6lRGG
   2 │ 123-124spm    MTQsYTRjZWY5NTMwZjQwOTM2NjYxOGFk…  5c0by8vfXvJ2MVTyExKBHA
  ⋮  │      ⋮                        ⋮                            ⋮
  87 │ Nero remix    MTIsZWY1NTIxMjlmYjRhYTU3NTIyOTcz…  6SsuaqQY0ibRJOpWVyshfb
                                                                84 rows omitted
```
"""
playlist_owned_dataframe_get(; silent = true) = DataFrame(playlist_owned_refs_get(;silent))

"""
    tracks_namedtuple_from_playlist(playlist_id::SpPlaylistId)
    ---> NamedTuple{field_names}(field_values)

```julia-repl
julia> playlist_id = SpPlaylistId("spotify:playlist:0ov1bfBQagkGtM1OYlE7A3")
spotify:playlist:0ov1bfBQagkGtM1OYlE7A3

julia> DataFrame(tracks_namedtuple_from_playlist(playlist_id))
45×10 DataFrame
 Row │ trackid                 trackname                          isrc          artists                            ⋯
     │ SpTrackId               String                             String        Array…                             ⋯
─────┼──────────────────────────────────────────────────────────────────────────────────────────────────────────────
   1 │ 75sH9bA9JKUmNvkiei1TtL  STEPPIN UP                         GBBKS1000156  ["M.I.A."]                         ⋯
   2 │ 4zYtMB8UXHcFizdmPbW1lM  Le chrome et le coton (Lafayette…  FR9W11215479  ["Jérôme Echenoz", "Anna Jean", …
   3 │ 0N9WhEz6DiBDvBxa6uJCTY  Eet                                USWB10901895  ["Regina Spektor"]
   4 │ 0LArpKG8L6lGDv53CvYIf0  30 Minutes - Remix                 RUA110100053  ["t.A.T.u."]
  ⋮  │           ⋮                             ⋮                       ⋮                        ⋮                  ⋱
  42 │ 21GDyNP7F74VbcFMn8c6Lh  We Are The Night                   GBAAA0700876  ["The Chemical Brothers"]          ⋯
  43 │ 2M6hxptv4hht21Wc0yTpNA  Blackbird                          AUBM01800239  ["Tash Sultana"]
  44 │ 3uPImxAltF6FcSGIC3OPWq  How Can a Poor Man Stand Such Ti…  USSM10602988  ["Bruce Springsteen"]
  45 │ 2OV5hOFQWLW5XTnSipBAau  Greatest Love                      NOAPI0808130  ["Major Parkinson"]
                                                                                       6 columns and 37 rows omitted

```
"""
function tracks_namedtuple_from_playlist(playlist_id::SpPlaylistId)
    fields = "items(track(name,id,external_ids,available_markets,album(id,name,album_type,release_date),artists(name,id))), next"
    o, waitsec = playlist_get_tracks(playlist_id; fields, limit = 100, market = "");
    if ! isnothing(findfirst(i-> isnothing(i.track.id), o.items))
        # CONSIDER instead of erroring, let it pass? Cover over it in make_named_tuple_from_json_object(o), use filter but assert all fields have equal length.
        # Since these errors are rare, wait until it reoccurs before debugging.
        println(stderr)
        @warn "This playlist contains unexpected tracks data field:"
        playlist_details_print(IOContext(stdout, :print_ids => true), playlist_id)
        println(stderr)
        @warn "Showing the first problematic track. Check in the player if it still is available?"
        i = findfirst(i -> isnothing(i.track.id), o.items)
        @warn "$(o.items[i].track)"
        throw(ArgumentError("Can't retrieve track in playlist_id $(playlist_id)"))
    end
    nt = make_named_tuple_from_json_object(o)
    while ! isnothing(o.next)
        sleep(waitsec)
        o, waitsec = playlist_get_tracks(playlist_id; offset = length(nt.trackid), fields, limit = 100, market = "");
        if ! isnothing(findfirst(i-> isnothing(i.track.id), o.items))
            println(stderr)
            @warn "This playlist contains unexpected tracks data field:"
            playlist_details_print(IOContext(stdout, :print_ids => true), playlist_id)
            @warn "Showing the first problematic track. Check in the player if it still is available?"
            i = findfirst(i -> isnothing(i.track.id), o.items)
            println(stderr)
            @warn "$(o.items[i].track)"
            throw(ArgumentError("Can't retrieve the track in playlist shown above."))
        end
        append_to_named_tuple_from_json_object!(nt, o)
    end
    nt
end


"""
append_to_named_tuple_from_json_object!(nt, o)

Increases the length of value vectors in the named tuple nt. See 'make_named_tuple_from_json_object'.
"""
function append_to_named_tuple_from_json_object!(nt, o)
    ant = make_named_tuple_from_json_object(o)
    for (fi, afi) in zip(nt, ant)
        append!(fi, afi)
    end
    nt
end


"""
    make_named_tuple_from_json_object(o)

o is a Json3 Object returned from calls like
fields = "items(track(name,id,external_ids,available_markets,album(id,name,album_type,release_date),artists(name,id))), next"
o = playlist_get_tracks(playlist_id; fields, limit = 100, market)[1];
"""
function make_named_tuple_from_json_object(o)
    trackid =  map(i -> SpTrackId(i.track.id) , o.items)
    trackname =  map(i -> string(i.track.name)  , o.items)
    isrc =  map(i -> InlineStrings.String15(i.track.external_ids[:isrc])  , o.items)
    artists =  map(o.items) do i
        map(i.track.artists) do a
            string(a.name)
        end
    end
    artist_ids =  map(o.items) do i
        map(i.track.artists) do a
            SpArtistId(a.id)
        end
    end
    album_id = map(i -> SpAlbumId(i.track.album.id)  , o.items)
    album_name = map(i -> string(i.track.album.name)  , o.items)
    albumtype = map(i -> string(i.track.album.album_type)  , o.items)
    release_date = map(i -> string(i.track.album.release_date)  , o.items)
    available_markets = map(i -> join(i.track.available_markets, " "), o.items)
    # Make output a NamedTuple...
    field_names = (
        :trackid,
        :trackname,
        :isrc,
        :artists,
        :artist_ids,
        :album_id,
        :album_name,
        :albumtype,
        :release_date,
        :available_markets)
    field_values = [trackid,
        trackname,
        isrc,
        artists,
        artist_ids,
        album_id,
        album_name,
        albumtype,
        release_date,
        available_markets]
    NamedTuple{field_names}(field_values)
end

"delete_track_from_playlist_print(track_id, item::JSON3.Object) ---> Bool"
function delete_track_from_playlist_print(ioc, track_id, playlist_id, item::JSON3.Object)
    if ! (is_track_in_local_data(track_id, playlist_id) || is_track_in_online_playlist(track_id, playlist_id))
        print(ioc, "\n  ❌ Can't delete \"")
        track_album_artists_print(ioc, item)
        print(ioc, "\"\n  - Not in playlist ")
        playlist_details_print(ioc, playlist_id)
        println(ioc)
        return false
    end
    market = ""
    playlist_details = playlist_get(playlist_id; market)[1]
    if isempty(playlist_details)
        print(ioc, "\n  ❌ Delete: Can't get playlist details from ")
        playlist_details_print(ioc, playlist_id)
        println(ioc)
        return false
    end
    plo_id = playlist_details.owner.id
    user_id = get_user_name()
    if plo_id !== String(user_id)
        print(ioc, "\n  ❌ Can't delete \"")
        playlist_details_print(ioc, playlist_id)
        println(ioc, "\" \n  - The playlist is owned by $plo_id, not $user_id.")
        return false
    end
    printstyled(ioc, "\n  ✓ Going to delete ... $(repr("text/plain", track_id)) from ", color=:yellow)
    ioc = color_set(ioc, :yellow)
    playlist_details_print(ioc, playlist_id)
    println(ioc)
    res = playlist_remove_playlist_item(playlist_id, [track_id])[1]
    if isempty(res)
        print(ioc, "\n  ❌  Could not delete \"")
        track_album_artists_print(ioc, item)
        print(ioc, "\"\n  from ")
        playlist_details_print(ioc, playlist_id)
        println(ioc, ". \n  This is due to technical reasons.")
        return false
    else
        printstyled(ioc, "This deletion may take minutes to show everywhere. The playlist's snapshot ID against which you deleted the track:\n", color = :green)
        sleep(1)
        tracks_data_update(; forceupdate = true)
        println(ioc,  "  playlist snapshot id after deletion: ", res.snapshot_id)
        return true
    end
end

"""
    is_track_in_online_playlist(t::SpTrackId, playlist_id::SpPlaylistId)
        ---> Bool

When user commands deleting a track from an (online) playlists,
but the track shouldn't be there according to the local tracks data,
we still don't cancel the command before also checking online.

The online data might take some time to update, and the local data
may also not be updated.
"""
function is_track_in_online_playlist(t::SpTrackId, playlist_id::SpPlaylistId)
    fields = "items(track(name,id)), next"
    market = ""
    o, waitsec = playlist_get_tracks(playlist_id; fields, limit = 100, market);
    track_ids = o.items .|> i -> i.track.id |> SpTrackId
    t in track_ids && return true
    while o.next !== nothing
        if waitsec > 0
            sleep(waitsec)
        end
        o, waitsec = playlist_get_tracks(playlist_id; offset = length(track_ids), fields, limit=100, market);
        new_track_ids = o.items .|> i -> i.track.id |> SpTrackId
        append!(track_ids, new_track_ids)
        t in track_ids && return true
    end
    false
end


"""
    playlist_owned_refs_get(;silent = true)
    ---> Vector{PlaylistRef}, prints to stdout if not `silent`

Storing PlaylistRefs instead of SpPlaylistId enables us to
identify when playlist contents have been updated. There's
no need to refresh our local lists when snapshot_id is
unchanged.

This function is so quick that there's no need to store output
for long (tracks are another matter, and have no snapshot_id).
"""
function playlist_owned_refs_get(;silent = true)
    batchsize = 50
    playlistrefs = Vector{PlaylistRef}()
    user_id  = get_user_name()
    ! silent && println(stdout, "Retrieving playlists currently subscribed to:")
    for batchno = 0:200
        json, waitsec = playlist_get_current_user(limit = batchsize, offset = batchno * batchsize)
        isempty(json) && break
        waitsec > 0 && throw("Too fast, whoa!")
        l = length(json.items)
        l == 0 && break
        for item in json.items
            if item.owner.display_name == user_id
                ! silent && print(stdout, item.name, "    ")
                push!(playlistrefs, PlaylistRef(item))
            else
                ! silent && printstyled(stdout, "(not monitoring $(item.owner.id)'s \"$(item.name)\")    ", color= :light_black)
            end
        end
    end
    ! silent && println(stdout)
    playlistrefs
end

wanted_feature_keys() = [:danceability, :key, :valence, :speechiness, :duration_ms, :instrumentalness, :liveness, :mode, :acousticness, :time_signature, :energy, :tempo, :loudness]
wanted_feature_pair(p) = p[1] ∈ wanted_feature_keys()


"""
    playlist_details_print(playlist_id::SpPlaylistId)
    playlist_details_print(ioc, playlist_id::SpPlaylistId, tracks_data)
    playlist_details_print(ioc, context::JSON3.Object)

This is rather slow because 'details' include fetching the online only description.
"""
function playlist_details_print(ioc, playlist_id::SpPlaylistId)
    playlist_details_print(ioc, playlist_id, tracks_data_update())
end
function playlist_details_print(ioc, playlist_id::SpPlaylistId, tracks_data)
    pld = Spotify.Playlists.playlist_get(playlist_id; market = "")[1]
    if isempty(pld)
        println(ioc, "Can't get playlist details.")
        return
    end
    playlist_no_details_print(ioc, playlist_id, pld.name)
    plo_id = pld.owner.id
    user_id = get_user_name()
    if plo_id !== String(user_id)
        print(ioc, " (owned by $(plo_id))")
    end
    if pld.description != ""
        print(ioc, " -- ",  pld.description, " -- ")
    end
    if pld.public && plo_id == String(user_id)
        print(ioc, " (public, $(pld.total) followers)")
    end
    # We don't trust the web service to make a reliable count of
    # large playlists we own.
    if length(pld.tracks.items) < 100 || plo_id !== String(user_id)
        print(ioc, "  ", length(pld.tracks.items), " tracks")
    else
        tracks_in_playlist_ids = filter(tracks_data) do rw
            any(ref -> ! ismissing(ref) && ref.id == playlist_id, rw[r"playlistref"])
        end[!, :trackid]
        print(ioc, "  ", length(tracks_in_playlist_ids), " tracks")
    end
    nothing
end
function playlist_details_print(ioc, context::JSON3.Object)
    if context.type !== "playlist"
        if context.type == "collection"
            print(ioc, "Library / liked songs.")
        elseif context.type == "album"
            print(ioc, " Context is album as shown in `")
            printstyled(ioc, "track \\ album \\ artist", color = :green)
            print(ioc, "`")
        else
            print(ioc, " Context is not Library, Playlist or Album. It is $(context.type)")
        end
        return
    end
    playlist_id = SpPlaylistId(context.uri)
    playlist_details_print(ioc, playlist_id)
    nothing
end

"""
    playlist_no_details_print(ioc, playlist_ref::PlaylistRef)
    playlist_no_details_print(ioc, playlist_id::SpPlaylistId, playlist_name)
"""
playlist_no_details_print(ioc, p::PlaylistRef) = playlist_no_details_print(ioc, p.id, p.name)
function playlist_no_details_print(ioc, playlist_id::SpPlaylistId, playlist_name)
    print(color_set(ioc, :203), playlist_name)
    color_set(ioc)
    if get(ioc, :print_ids, false)
        print(ioc, "  ")
        show(ioc, MIME("text/plain"), playlist_id)
        color_set(ioc)
    end
    nothing
end


"""
    replace_track_in_playlists(plrefs::Vector{PlaylistRef}, from_to::Pair)
    replace_track_in_playlists(plrefs::Vector{PlaylistRef}, from_to::Pair{SpTrackId, SpTrackId})

All occurences of `from` in the online playlists are replaced with `to` in the same position.

Local data is not updated here, as this is expected to be called from a loop.

```
julia> begin
       from_to = SpTrackId("1cmjxqobVTrgAiJ0btAleN") => SpTrackId("7DsQgIwg23u9gooCxkRTu3")
       plrefs = [PlaylistRef("73-74spm", "MTAsMGFmYTU1OWQ3MzE0ODgzOTljODg5OTgwNGY2YjZjMWUwMmQzMTIxMQ==", SpPlaylistId("1lXn74G3ahYlXQbI0ihbqF"))]
       replace_track_in_playlists(plrefs, from_to)
    end
```

"""
function replace_track_in_playlists(plrefs, from_to::Pair)
    from_track_id =  SpTrackId(from_to[1])
    to_track_id =  SpTrackId(from_to[2])
    replace_track_in_playlists(plrefs, from_track_id => to_track_id)
end

function replace_track_in_playlists(plrefs::Vector{PlaylistRef}, from_to::Pair{SpTrackId, SpTrackId})
    for plref in plrefs
        from_track_id = from_to[1]
        to_track_id = from_to[2]
        @assert from_track_id !== to_track_id
        nt = tracks_namedtuple_from_playlist(plref.id)
        #ids, names, track_isrcs, album_types = tracks_namedtuple_from_playlist(plref.id)
        indices = findall(==(from_track_id), nt.trackid)
        for i in indices
            # The web API uses a zero-based index, Julia a one-based.
            snapshot_id1 = playlist_add_tracks_to_playlist(plref.id, [to_track_id]; position = i - 1)[1].snapshot_id
            sleep(1) # This is probably not needed. But we don't imagine it will be used very often.
            snapshot_id2 = playlist_remove_playlist_item(plref.id, [from_track_id])[1].snapshot_id
            sleep(1) # This is probably not needed.
        end
    end
end
