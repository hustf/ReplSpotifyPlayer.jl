# This file has the functions called from the repl-mode.
# They do something, then returns a string with feedback.

"""
    current_playing_print() -> Bool

Please wait 1 second after changes for correct info.
"""
function current_playing_print(ioc)
    # Ref. delay https://github.com/spotify/web-api/issues/821#issuecomment-381423071
    st = get_player_state(ioc)
    isempty(st) && return false
    if ! isnothing(st.item)
        track_album_artists_print(ioc, st.item)
    elseif st.currently_playing_type == "unknown"
        print(ioc, "currently playing type: unknown")
    end
    println(ioc)
    true
end
"""
    current_context_print(ioc) -> Bool

Shows the playlist name or Library. Also where else the current track appears.

Please wait 1 second after changes for correct info.
"""
function current_context_print(ioc)
    st = get_player_state(ioc)
    isempty(st) && return false
    if isnothing(st.context)
        io = color_set(ioc, :red)
        print(io, "No current context")
        color_set(ioc)
        return true
    end
    if st.context.type == "playlist" || st.context.type == "collection"
        playlist_details_print(ioc, st.context)
    elseif st.context.type == "artist"
        artist_details_print(ioc, st.context.uri)
    else
        throw("Didn't think of $(st.context.type)")
    end
    # Also check if we have played past the end of the playlist and continued into the 'recommendations'.

    if st.context.type == "collection"
        track_id = SpTrackId(st.item.uri)
        if ! is_track_in_library(track_id)
            print(ioc, " Past end. In 'recommendations'.")
        end
    elseif st.context.type == "playlist"
        track_id = SpTrackId(st.item.uri)
        playlist_id = SpPlaylistId(st.context.uri)
        # We don't know if this playlist is owned by user yet.
        # is_track_in_playlist makes an api call, so avoid if the first returns true
       if ! (is_track_in_track_data(track_id, playlist_id) || is_track_in_playlist(track_id, playlist_id))
           print(ioc, " Past end, in 'recommendations'")
       end
    end
    println(ioc)
    if st.context.type !== "artist"
        # Now also print where the track also appears.
        io = color_set(ioc, :light_black)
        track_also_in_playlists_print(io, track_id, st.context)
        if st.context.type !== "collection" && is_track_in_library(track_id)
            println(io, "       Library")
        end
        color_set(ioc)
    end
    true
end


"""
    delete_current_playing_from_owned_print(ioc) -> Bool

Delete track from playlist or library context, if owned.
"""
function delete_current_playing_from_owned_print(ioc)
    st = get_player_state(ioc)
    isempty(st) && return false
    track_id = SpTrackId(st.item.uri)
    if st.context.type == "collection"
        return delete_track_from_library_print(ioc, track_id, st.item)
    elseif st.context.type !== "playlist"
        print(ioc, "\n  Can't delete \"")
        track_album_artists_print(ioc, st.item)
        println(ioc)
        println(ioc, "  - Not currently playing from a known playlist or user's library.\n")
        return false
    end
    playlist_id = SpPlaylistId(st.context.uri)
    delete_track_from_playlist_print(ioc, track_id, playlist_id, st.item)
end

"pause_unpause_print(ioc) -> Bool"
function pause_unpause_print(ioc)
    st = get_player_state(ioc)
    isempty(st) && return false
    if st.is_playing
        player_pause()
    else
        player_resume_playback()
    end
    true
end


"""
    current_audio_features_print(ioc)  -> Bool

Audio features in two columns.
"""
function current_audio_features_print(ioc)
    st = get_player_state(ioc)
    isempty(st) && return false
    curitem = st.item
    current_playing_id = curitem.id
    af = tracks_get_audio_features( current_playing_id)[1]
    if ! isempty(af)
        println(ioc,  rpad("acousticness     $(af.acousticness)", 25)     * rpad("key               $(af.key)", 25))
        println(ioc,  rpad("speechiness      $(af.speechiness)", 25)      * rpad("mode              $(af.mode)", 25))
        println(ioc,  rpad("instrumentalness $(af.instrumentalness)", 25) * rpad("time_signature    $(af.time_signature)", 25))
        println(ioc,  rpad("liveness         $(af.liveness)", 25)         * rpad("tempo             $(af.tempo)", 25))
        println(ioc,  rpad("loudness         $(af.loudness)", 25)         * rpad("duration_ms       $(af.duration_ms)", 25))
        println(ioc,  "energy           $( af.energy)")
        println(ioc,  "danceability     $( af.danceability)")
        println(ioc,  "valence          $( af.valence)")
    end
    true
end

"""
   seek_in_track_print(ioc, decileioc)   -> Bool

Resume playing from decile 0-9 in current track, where 1 is 1 / 10 of track length.
"""
function seek_in_track_print(ioc, decile)
    st = get_player_state(ioc)
    isempty(st) && return false
    t = st.item.duration_ms
    new_progress_ms = Int(round(decile * t / 10))
    player_seek(new_progress_ms)
    ns = Int(round(new_progress_ms / 1000))
    ts = Int(round(t / 1000))
    println(ioc, "$(ns) s / $(ts) s")
    true
end

"""
    help_seek_syntax_print(ioc) -> Bool

Some suggestions for using the DataFrame syntax with Spotify.jl and this package.
"""
function help_seek_syntax_print(ioc)
    mymd = md"""

Exit the replmode by pressing 'e'. 

## Save typing with shorthand single-argument functions:

```julia-repl
julia> playtracks(x) = begin;Player.player_resume_playback(;uris = x);println(length(x));end
```

# Use the tracks dataframe TDF! 
```julia-repl
julia> filter(:trackname => n -> contains(n, " love "), TDF[])[!, :trackid] |> playtracks
1-element Vector{SpTrackId}:
 spotify:track:7IQlwZBtL05beQqJCpCaZA

 julia> player_resume_playback(;uris = v)
 ({}, 0)
```

    """
    show(ioc, MIME("text/plain"),mymd)
    true
end