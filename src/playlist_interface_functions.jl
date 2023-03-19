# This file wraps functions from Spotify.jl. Many are based on Spotify.jl/example/playlist_and_library_utilites.jl
# Some of these wrappers translate into ReplSpotifyPlayer types and DataFrame.

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