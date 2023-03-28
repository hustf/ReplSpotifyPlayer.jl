# This file wraps functions from Spotify.jl.
# Used by tracks_dataframe_functions.jl, and
# 'is_track_in_playlist' by repl_player.jl.
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
    track_ids_and_names_in_playlist(playlist_id::SpPlaylistId)
        -> (Vector{SpTrackId}, Vector{String})

Currently, Spotify's player shows tracks which have become unavalable as grey. This function
will exclude most of the 'grey' ones, but not all.

If you don't own a playlist, there are additional limits, see `Spotify.Playlists.playlist_get_tracks`.

```julia-repl
julia> playlist_id = SpPlaylistId("2oJVHrxclWP0f9IHE7Bj7a")
spotify:playlist:2oJVHrxclWP0f9IHE7Bj7a

julia> track_ids_names = hcat(track_ids_and_names_in_playlist(playlist_id)...)
7×2 Matrix{Any}:
 spotify:track:6nek1Nin9q48AVZcWs9e9D  "Paradise"
 spotify:track:0Yo9z0PItxg3vXI83HLIFx  "Boli Panieh"
 spotify:track:7LA2VebH12tu9jU0JodX9N  "Banghra Bros"
 spotify:track:5ENZgmiqcT9gdQ4Q9wJoOt  "Calcutta (Taxi, Taxi, Taxi)"
 spotify:track:3YhzLZG5zHPHlteiuv7Ne1  "Ode to the Prostitute"
 spotify:track:2epYMlXJ4ZfexISPrH0urQ  "Ville Hester"
 spotify:track:4bjPx9eLSPcXod7mSzoo5z  "Panj Bindiyaan"
```
"""
function track_ids_and_names_in_playlist(playlist_id::SpPlaylistId)
    fields = "items(track(name,id,is_playable)), next"
    o, waitsec = Spotify.Playlists.playlist_get_tracks(playlist_id; fields, limit = 100);
    track_ids = [SpTrackId(it.track.id) for it in o.items if is_item_track_playable(it)]
    track_names = [string(it.track.name) for it in o.items if is_item_track_playable(it)]
    while o.next !== nothing
        if waitsec > 0
            sleep(waitsec)
        end
        o, waitsec = Spotify.Playlists.playlist_get_tracks(playlist_id; offset = length(track_ids), fields, limit=100);
        append!(track_ids, [SpTrackId(it.track.id) for it in o.items if is_item_track_playable(it)])
        append!(track_names, [string(it.track.name) for it in o.items if is_item_track_playable(it)])
    end
    track_ids, track_names
end


function append_missing_audio_features!(tracks_data)
    prna = propertynames(tracks_data)
    notpresent = setdiff(wanted_feature_keys(), prna)
    if ! isempty(notpresent)
        v = Vector{Any}(fill(missing, nrow(tracks_data)))
        nt = map(k-> k => copy(v), notpresent)
        insertcols!(tracks_data, 3, nt...)
    end
end
function insert_audio_feature_vals!(trackrefs_rw)
    ! ismissing(trackrefs_rw[first(wanted_feature_keys())]) && return trackrefs_rw
    fdic = get_audio_features_dic(trackrefs_rw[:trackid])
    for (k,v) in fdic
        trackrefs_rw[k] = v
    end
    trackrefs_rw
end






"playlist_details_print(context::JSON3.Object) -> nothing"
function playlist_details_print(ioc, context::JSON3.Object)
    if context.type !== "playlist"
        print(ioc, "Context is not playlist.")
        if context.type == "collection"
            print(ioc, " It is library / liked songs.")
        elseif context.type == "album"
            print(ioc, " It is album as shown in `")
            printstyled(ioc, "track \\ album \\ artist", color = :green)
            print(ioc, "`")
        else
            print(ioc, " It is $(context.type)")
        end
        return
    end
    playlist_id = SpPlaylistId(context.uri)
    playlist_details_print(ioc, playlist_id)
    nothing
end




"delete_track_from_playlist_print(track_id, item::JSON3.Object) -> Bool"
function delete_track_from_playlist_print(ioc, track_id, playlist_id, item::JSON3.Object)
    if ! (is_track_in_track_data(track_id, playlist_id) || is_track_in_playlist(track_id, playlist_id))
        print(ioc, "\n  ❌ Can't delete \"")
        track_album_artists_print(ioc, item)
        print(ioc, "\"\n  - Not in playlist ")
        playlist_details_print(ioc, playlist_id)
        println(ioc)
        return false
    end
    playlist_details = Spotify.Playlists.playlist_get(playlist_id)[1]
    if isempty(playlist_details)
        print(ioc, "\n  ❌ Delete: Can't get playlist details from ")
        playlist_details_print(ioc, playlist_id)
        println(ioc)
        return false
    end
    plo_id = playlist_details.owner.id
    user_id = Spotify.get_user_name()
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
    res = Spotify.Playlists.playlist_remove_playlist_item(playlist_id, [track_id])[1]
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
        TDF[] = tracks_data_get(;silent = true)
        save_tracks_data(TDF[])
        println(ioc,  "  ", res.snapshot_id)
        return true
    end
end

"""
    is_track_in_playlist(t::SpTrackId, playlist_id::SpPlaylistId)
        -> Bool
    
"""
function is_track_in_playlist(t::SpTrackId, playlist_id::SpPlaylistId)
    fields = "items(track(name,id)), next"
    o, waitsec = Spotify.Playlists.playlist_get_tracks(playlist_id; fields, limit = 100);
    track_ids = o.items .|> i -> i.track.id |> SpTrackId
    t in track_ids && return true
    while o.next !== nothing
        if waitsec > 0
            sleep(waitsec)
        end
        o, waitsec = Spotify.Playlists.playlist_get_tracks(playlist_id; offset = length(track_ids), fields, limit=100);
        track_ids = o.items .|> i -> i.track.id |> SpTrackId
        t in track_ids && return true
    end
    false
end

########################
# Internal to this file:
########################

"""
    playlist_owned_refs_get(;silent = true)
    -> Vector{PlaylistRef}, prints to stdout

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
    for batchno = 0:200
        json, waitsec = Spotify.Playlists.playlist_get_current_user(limit = batchsize, offset = batchno * batchsize)
        isempty(json) && break
        waitsec > 0 && throw("Too fast, whoa!")
        l = length(json.items)
        l == 0 && break
        ! silent && batchno == 0 && println(stdout, "Retrieving playlists currently subscribed to:")
        for item in json.items
            if item.owner.display_name == user_id 
                ! silent && print(stdout, item.name, "    ")
                push!(playlistrefs, PlaylistRef(item))
            else
                ! silent && printstyled(stdout, "(not monitoring \"$(item.name)\", which is owned by $(item.owner.id))    ", color= :light_black)
            end
        end
    end
    ! silent && println(stdout)
    playlistrefs
end

"""
    is_item_track_playable(it::JSON3.Object)
        -> Bool

Makes no web API calls.

This set of criteria is not complete. We'd rather include
a non-playable track than exclude it.

First example, this may deem a track playable, but
explicit content, or that the album is unavailable may decide.

Second example, even though 'available markets' is empty,
a track may actually be playable. So we don't check this field.

"""
function is_item_track_playable(it::JSON3.Object)
    ! haskey(it, :track) && return false
    ! haskey(it.track, :id) && return false
    isnothing(it.track.id) && return false
    haskey(it.track, :is_playable) && ! it.track.is_playable && return false
    true
end

wanted_feature_keys() = [:danceability, :key, :valence, :speechiness, :duration_ms, :instrumentalness, :liveness, :mode, :acousticness, :time_signature, :energy, :tempo, :loudness]
wanted_feature_pair(p) = p[1] ∈ wanted_feature_keys()
function get_audio_features_dic(trackid)
    jsono, waitsec = tracks_get_audio_features(trackid)
    if waitsec > 0
        @info waitsec
        sleep(waitsec)
    end
    filter(wanted_feature_pair, jsono)
end



"playlist_details_print(playlist_id::SpPlaylistId)"
function playlist_details_print(ioc, playlist_id::SpPlaylistId)
    pld = Spotify.Playlists.playlist_get(playlist_id)[1]
    if isempty(pld)
        println(ioc, "Can't get playlist details.")
    end
    print(ioc, pld.name)
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
    if get(ioc, :print_ids, false)
        print(ioc, "  ")
        show(ioc, MIME("text/plain"), playlist_id)
    end
    nothing
end