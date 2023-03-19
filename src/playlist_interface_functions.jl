# This file copies some 'interface' functions from Spotify.jl/example/playlist_and_library_utilites.jl

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
