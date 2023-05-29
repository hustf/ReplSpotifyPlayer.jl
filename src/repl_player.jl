# This file has the functions called directly from the repl-mode.
# After some context checking, most work is done by sub-callees.
# Just a few of these have something interesting to return, like
# e.g. what was selected. Output is to the REPL, to the Spotify
# player, and to the local dataframe.

"""
    current_playing_print() ---> Bool

This is called after every command in the player replmode.
"""
function current_playing_print(ioc)
    # Ref. delay https://github.com/spotify/web-api/issues/821#issuecomment-381423071
    st = get_player_state(ioc)
    isempty(st) && return false
    if ! isnothing(st.item)
        track_album_artists_print(ioc, st.item)
    elseif st.currently_playing_type == "unknown"
        print(ioc, "Currently playing type: unknown")
    else
        print(ioc, "Currently playing type: $(st.currently_playing_type)")
    end
    println(ioc)
    true
end

"""
    current_context_print(ioc) ---> Bool

Shows the playlist name or Library. Also where else the current track appears.

Please wait 1 second after changes for correct info.

key: 'c'
"""
function current_context_print(ioc)
    st = get_player_state(ioc)
    isempty(st) && return false
    if st.currently_playing_type !== "track"
        io = color_set(ioc, :red)
        print(io, "Not currently playing a track.")
        color_set(ioc)
        return false
    end
    track_id = SpTrackId(st.item.uri)
    if isnothing(st.context)
        io = color_set(ioc, :red)
        print(io, "No current context.")
        color_set(ioc)
    else
        type = st.context.type
        if type == "playlist" || type == "collection" || type == "single"
            playlist_details_print(ioc, st.context)
        elseif type == "artist"
            artist_details_print(ioc, st.context.uri)
        elseif type == "album"
            album_details_print(ioc, st.context.uri)
        else
            throw("Didn't think of $(string(type))")
        end
        #
        # Also check if we have played past the end of the playlist and continued into the 'recommendations'.
        if st.context.type == "collection"
            if ! is_track_in_library(track_id)
                print(ioc, " Past end. In 'recommendations'.")
            end
        elseif st.context.type == "playlist"
            playlist_id = SpPlaylistId(st.context.uri)
            # We don't know if this playlist is owned by user yet.
            # If `is_track_in_local_data` returns true, we can avoid the web API call in `is_track_in_online_playlist`.
            if ! (is_track_in_local_data(track_id, playlist_id) || is_track_in_online_playlist(track_id, playlist_id))
                print(ioc, " Past end, in 'recommendations'")
            end
        end
    end
    println(ioc)
    if isnothing(st.context) || st.context.type == "artist"
        color_set(ioc)
        # Print where, if anywhere, this track appears in our playlists and library.
        track_also_in_playlists_print(ioc, track_id, JSON3.Object())
        if is_track_in_library(track_id)
            println(ioc, "       Library")
        end
        if ! isnothing(st.context)
            artist_tracks_in_playlists_print(ioc, st.context.uri)
        end
    else
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
    delete_current_playing_from_owned_print(ioc) ---> Bool

Delete track from playlist or library context, if owned.

key: 'delete' or 'fn + ⌫ '
"""
function delete_current_playing_from_owned_print(ioc)
    st = get_player_state(ioc)
    isempty(st) && return false
    track_id = SpTrackId(st.item.uri)
    if isnothing(st.context)
        io = color_set(ioc, :red)
        print(io, "No current context.")
        color_set(ioc)
    end
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

"""
pause_unpause_print(ioc) ---> Bool

key: 'p'
"""
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
    current_audio_features_print(ioc)  ---> Bool

Audio features as text, then plots. Will end with displaying 
the rhythmic progression for comparison with plot x-axis.

key: 'a'
"""
function current_audio_features_print(ioc)
    st = get_player_state(ioc)
    isempty(st) && return false
    isnothing(st.item) && return false
    if st.currently_playing_type !== "track"
        io = color_set(ioc, :red)
        print(io, "Not currently playing a track.")
        color_set(ioc)
        return false
    end
    track_id = SpTrackId(st.item.uri)
    af = tracks_get_stored_or_api_audio_features(track_id)
    if ! isempty(af)
        println(ioc,  rpad("acousticness     $(af[:acousticness])", 25)     * rpad("key               $(af[:key])", 25))
        println(ioc,  rpad("speechiness      $(af[:speechiness])", 25)      * rpad("mode              $(af[:mode])", 25))
        println(ioc,  rpad("instrumentalness $(af[:instrumentalness])", 25) * rpad("time_signature    $(af[:time_signature])", 25))
        println(ioc,  rpad("liveness         $(af[:liveness])", 25)         * rpad("tempo             $(af[:tempo])", 25))
        println(ioc,  rpad("loudness         $(af[:loudness])", 25)         * rpad("duration_ms       $(af[:duration_ms])", 25))
        println(ioc,  "energy           $( af[:energy])")
        println(ioc,  "danceability     $( af[:danceability])")
        println(ioc,  "valence          $( af[:valence])")
    end
    json, waitsec = tracks_get_audio_analysis(track_id)
    # Mark the current time at once, so we can calculate a current progress later.
    t_0 = time()
    plot_audio(ioc, track_id, json)
    # The plots we just made begs the question: Where are we in the tune?
    # Let's display a 'rhytmic progress' thing!
    color_set(ioc)
    # We listen for keys 0-9 only. Other keypresses will return nothing.
    returnkey  = rhythmic_progress_print(ioc, json, t_0, st.progress_ms / 1000)
    while ! isnothing(returnkey)
        color_set(ioc)
        iob = IOBuffer()
        seek_in_track_print(iob, Meta.parse(string(returnkey)))
        take!(iob)
        # Allow a little time for player to be updated with the actual progress.
        sleep(0.5)
        st = get_player_state(ioc)
        isempty(st) && return false
        isnothing(st.item) && return false
        t_0 = time()
        returnkey  = rhythmic_progress_print(IOContext(ioc, :print_instructions => false), json, t_0, st.progress_ms / 1000)
    end
    color_set(ioc)
    println(ioc)
    true
end

"""
   seek_in_track_print(ioc, decileioc)   ---> Bool

Resume playing from decile 0-9 in current track, where 1 is 1 / 10 of track length.

'0' <= key <= '9'
"""
function seek_in_track_print(ioc, decile)
    st = get_player_state(ioc)
    isempty(st) && return false
    isnothing(st.item) && return false
    if st.currently_playing_type !== "track"
        io = color_set(ioc, :red)
        print(io, "Not currently playing a track.")
        return false
    end
    t = st.item.duration_ms
    new_progress_ms = Int(round(decile * t / 10))
    player_seek(new_progress_ms)
    ns = duration_sec(new_progress_ms)
    ts = duration_sec(t)
    println(ioc, "$(ns) s / $(ts) s = $(Int(round(10 * ns / ts))) / 10")
    true
end

"""
    help_seek_syntax_print(ioc) ---> Bool

Some suggestions for using the DataFrame syntax with Spotify.jl and this package.

key: '?'
"""
function help_seek_syntax_print(ioc)
    mymd = md"""

Exit the replmode by pressing 'e' or 'backspace'.

Find track ids, artist ids, album ids, playlist ids by pressing 'i' and then 'c'. The context
you are in is what kind of list you are currently playing from in Spotify's app.

## Save typing with shorthand single-argument functions:

```julia-repl
julia> playtracks(x) = begin;Player.player_resume_playback(;uris = x);println(length(x));end
```

(`playtracks` is already defined and exported by this module.)

# Examples

Seek for " love " in the Tracks DataFrame TDF[] and play all results.

```julia-repl
julia> filter(:trackname => n -> contains(uppercase(n), " LOVE "), TDF[])[!, :trackid] |> playtracks
12
```

"""
    show(ioc, MIME("text/plain"),mymd)
    println(ioc)
    true
end

"""
    current_artists_tracks_request_play_in_context_print(ioc)

key: 'm'
"""
function current_artists_tracks_request_play_in_context_print(ioc)
    st = get_player_state(ioc)
    isempty(st) && return false
    if isnothing(st.item)
        io = color_set(ioc, :red)
        print(io, "No current item.")
        color_set(ioc)
    else
        println(ioc)
        artists_tracks_request_play_in_context_print(ioc, st.item)
    end
end


"""
    sort_playlist_other_select_print(ioc; pre_selection = nothing)

1. Pick criterion function.
2. Plot distribution of criterion(tracks), with the current track highlighted.
3. Sort tracks in current playlist by criterion function, with the current track highlighted.
4. Offer numerical selection from sorted list to play from.

key: 'o' or 't'
"""
function sort_playlist_other_select_print(ioc; pre_selection = nothing)
    if isnothing(pre_selection)
        println(ioc, "\nTrack feature select")
        # danceability,key,valence,speechiness,duration_ms,instrumentalness,liveness,mode,acousticness,time_signature,energy,tempo,loudness
        vs = wanted_feature_keys()
        push!(vs, :trackname)
        rng = 1:length(vs)
        for (i, s) in enumerate(vs)
            println("  ", lpad(i, 3), "  ", s)
        end
        io = color_set(ioc, :176)
        print(io, "Type feature number ∈ $rng to sort playlist by! Press enter to do nothing: ")
        inpno = read_number_from_keyboard(rng)
        println(io)
        color_set(ioc)
        isnothing(inpno) && return nothing
        picked_key = vs[inpno]
    else
        picked_key = pre_selection
    end
    if picked_key == :abnormality
        current_playlist_ranked_select_print(abnormality, ioc)
    elseif picked_key ∈ wanted_feature_keys()
        current_playlist_ranked_select_print(ioc; func_name = "$(picked_key)") do playlist_tracks_data
            collect(playlist_tracks_data[!, picked_key])
        end
    else
        current_playlist_ranked_select_print(ioc; func_name = "$(picked_key)", alphabetically = true) do playlist_tracks_data
            # An unsorted vector
            v = playlist_tracks_data[!, picked_key]
            # The sequence of indexes that would sort v
            p = sortperm(v; rev = true)
            # The sorted position for each element in v
            map( i-> findfirst(==(i), p), 1:length(v))
        end
    end
    picked_key
end

"""
    housekeeping_print(ioc)

key: 'h'
"""
function housekeeping_print(ioc)
    println(ioc)
    housekeeping_print(ioc, tracks_data_update())
end

"""
    toggle_ids_print(ioc)

key: 'i'
"""
function toggle_ids_print(ioc)
    if get(ioc, :print_ids, false)
        println(ioc, " No ids from now on")
        push!(IO_DICT, :print_ids => false)
    else
        println(ioc, " Including ids from now on")
        push!(IO_DICT, :print_ids => true)
    end
    IOContext(stdout, IO_DICT...)
end

"""
    current_genres_print() ---> Bool

key: 'g'
"""
function current_genres_print(ioc)
    # Ref. delay https://github.com/spotify/web-api/issues/821#issuecomment-381423071
    st = get_player_state(ioc)
    isempty(st) && return false
    if ! isnothing(st.item)
        genres_print(ioc, st.item)
    elseif st.currently_genres_type == "unknown"
        print(ioc, "Currently playing type: unknown")
    else
        print(ioc, "Currently playing type: $(st.currently_playing_type)")
    end
    println(ioc)
    true
end
