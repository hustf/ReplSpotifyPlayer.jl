# This file wraps functions from Spotify.jl.
# Used by tracks_dataframe_functions.jl, i.e. not user initiated but
# used to build and maintain the local data.
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






"playlist_details_string(context::JSON3.Object) -> String"
function playlist_details_string(context::JSON3.Object; link_for_copy = true)
    if context.type !== "playlist"
        s = "Context is not playlist."
        if context.type == "collection"
            s *= " It is library / liked songs."
        elseif context.type == "album"
            s *= " It is album as shown in `"
            s *=  text_colors[:green]
            s *= "track \\ album \\ artist"
            # This assumes we will print this string in the color of _repl_player/wrap_command. Consider rewriting colors.
            s *= text_colors[:light_blue] * "`"
        else
            s *= " It is $(context.type)"
            @show context
        end
        return s
    end
    playlist_id = SpPlaylistId(context.uri)
    playlist_details_string(playlist_id; link_for_copy)
end


"""
    is_track_in_playlist(t::SpTrackId, playlist_id::SpPlaylistId)
        -> Bool
    
"""
function is_track_in_playlist(t::SpTrackId, playlist_id::SpPlaylistId)
    # TODO: Move to local lookup file.
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


"delete_track_from_own_playlist(track_id, playing_now_desc) -> String, prints to stdout"
function delete_track_from_own_playlist(track_id, playlist_id, playing_now_desc)
    # TODO: Update TDF[] afterwards. Consider checking snapshot version first...
    playlist_description = "\"" * playlist_details_string(playlist_id) * " \""
    if ! is_track_in_playlist(track_id, playlist_id)
        printstyled(stdout, "\n  Can't delete \"" * playing_now_desc * "\"\n  - Not in playlist $(playlist_description)\n", color = :red)
       return "❌"
    end
    playlist_details = Spotify.Playlists.playlist_get(playlist_id)[1]
    if isempty(playlist_details)
        printstyled(stdout, "\n  Delete: Can't get playlist details from $(playlist_description).\n", color = :red)
        return "❌"
    end
    plo_id = playlist_details.owner.id
    user_id = Spotify.get_user_name()
    if plo_id !== String(user_id)
        printstyled(stdout, "\n  Can't delete " * playing_now_desc * "\n  - The playlist $(playlist_description) is owned by $plo_id, not $user_id.\n", color = :red)
        return "❌"
    end
    printstyled(stdout, "Going to delete ... $(repr("text/plain", track_id)) from $(playlist_description) \n", color = :yellow)
    res = Spotify.Playlists.playlist_remove_playlist_item(playlist_id, [track_id])[1]
    if isempty(res)
        printstyled(stdout, "\n  Could not delete " * playing_now_desc * "\n  from $(playlist_description). \n  This is due to technical reasons.\n", color = :red)
        return "❌"
    else
        printstyled("This deletion may take minutes to show everywhere. The playlist's snapshot ID against which you deleted the track:\n  $(res.snapshot_id)", color = :green)
        return ""
    end
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
    for batchno = 0:200
        json, waitsec = Spotify.Playlists.playlist_get_current_user(limit = batchsize, offset = batchno * batchsize)
        isempty(json) && break
        waitsec > 0 && throw("Too fast, whoa!")
        l = length(json.items)
        l == 0 && break
        for item in json.items
            if item.owner.display_name == get_user_name()
                ! silent && println(stdout, item.name)
                push!(playlistrefs, PlaylistRef(item))
            else
                ! silent && printstyled(stdout, "We're not monitoring playlist $(item.name), which is owned by $(item.owner.id)\n", color= :176)
            end
        end
    end
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



"playlist_details_string(playlist_id::SpPlaylistId; link_for_copy = true) -> String"
function playlist_details_string(playlist_id::SpPlaylistId; link_for_copy = true)
    pld = Spotify.Playlists.playlist_get(playlist_id)[1]
    if isempty(pld)
        return "Can't get playlist details."
    end
    s  = String(pld.name)
    plo_id = pld.owner.id
    user_id = Spotify.get_user_name()
    if plo_id !== String(user_id)
        s *= " (owned by $(plo_id))"
    end
    if pld.description != ""
        s *= "  ($(pld.description))"
    end
    if pld.public && plo_id == String(user_id)
        s *= " (public, $(pld.total) followers)"
    end
    if link_for_copy
        s *= "  " 
        iob = IOBuffer()
        show(IOContext(iob, :color => true), "text/plain", playlist_id)
        s *= String(take!(iob))
    end
    s
end