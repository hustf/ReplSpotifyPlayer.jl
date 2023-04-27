# This file has the functions called directly from the repl-mode.
# After some context checking, most work is done by sub-callees.
# Just a few of these have something interesting to return, like
# e.g. what was selected. Output is to the REPL, to the Spotify 
# player, and to the local dataframe.

"""
    current_playing_print() ---> Bool

Please wait 1 second after changes for correct info.
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
            # If `is_track_in_track_data` returns false, we can avoid the web API call in `is_track_in_playlist`. 
            if ! (is_track_in_track_data(track_id, playlist_id) || is_track_in_playlist(track_id, playlist_id))
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
            artist_tracks_in_data_print(ioc, st.context.uri)
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

"pause_unpause_print(ioc) ---> Bool"
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

Audio features in two columns.
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
     # Consider taking it from tracks data
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
    true
end

"""
   seek_in_track_print(ioc, decileioc)   ---> Bool

Resume playing from decile 0-9 in current track, where 1 is 1 / 10 of track length.
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
    ns = Int(round(new_progress_ms / 1000))
    ts = Int(round(t / 1000))
    println(ioc, "$(ns) s / $(ts) s")
    true
end

"""
    help_seek_syntax_print(ioc) ---> Bool

Some suggestions for using the DataFrame syntax with Spotify.jl and this package.
"""
function help_seek_syntax_print(ioc)
    mymd = md"""

Exit the replmode by pressing 'e'. 

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

Is the rhythm as inspected with `r : rhythm test` really coorect? Get the trackid by `i : toggle ids`. And then
dive deeper:

```
julia> # press :
julia> 
e : exit.     f(→) : forward.     b(←) : back.     p: pause, play.     0-9:  seek.
del(fn + ⌫  ) : delete track from playlist. c : context. m : musician. g : genres.
i : toggle ids. r : rhythm test. a : audio features. h : housekeeping. ? : syntax.
Sort then select  t : by typicality.  o : other features.  ↑ : previous selection.
  Heavenly Shower \ Look To Your Own Heart \ Lisa Ekdahl
 ◍ >i Including ids from now on
  Heavenly Shower \ Look To Your Own Heart \ Lisa Ekdahl  spotify:track:2GAVI4dLjAapIyJekbZb2L
julia> track = "spotify:track:2GAVI4dLjAapIyJekbZb2L"
julia> json = ReplSpotifyPlayer.tracks_get_audio_analysis(track)[1]
JSON3.Object{Base.CodeUnits{UInt8, String}, Vector{UInt64}} with 7 entries:
  :meta     => {…
  :track    => {…
  :bars     => Object[{…
  :beats    => Object[{…
  :sections => Object[{…
  :segments => Object[{…
  :tatums   => Object[{…

julia> begin
        playtracks([track])
        bpb = 3
        for item in json.bars
            print("|")
            for beat in 1:bpb
                sleep(item.duration / bpb)
                print(".")
            end
        end
    end
```


"""
    show(ioc, MIME("text/plain"),mymd)
    println(ioc)
    true
end

"""
    current_artist_and_tracks_in_data_print(ioc)
"""
function current_artist_and_tracks_in_data_print(ioc)
    st = get_player_state(ioc)
    isempty(st) && return false
    if isnothing(st.item)
        io = color_set(ioc, :red)
        print(io, "No current item.")
        color_set(ioc)
    else
        artist_and_tracks_in_data_print(ioc, st.item)
    end
end


"""
    current_metronome_print(ioc)  ---> Bool

Shows a beat / bar counter asyncronously until the end of track.
"""
function current_metronome_print(ioc)
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
    isempty(af) && return false
    bpm = af[:tempo]
    bpb = Int(af[:time_signature])
    duration_s = af[:duration_ms]  / 1000
    position_s = get_player_state(ioc).progress_ms / 1000
    bars_per_minute = bpm / bpb
    bars_in_track = Int(round(duration_s * bars_per_minute / 60 ))
    current_bar = Int(round(position_s * bars_per_minute / 60)) + 1
    bars = bars_in_track - current_bar
    println(ioc)
    println(ioc, lpad("Tempo            $(bpm)", 40) * " [Beats Per Minute]")
    println(ioc, lpad("Time_signature        $(bpb)", 40), " [Beats Per Bar]")
    println(ioc, lpad("Duration        $(duration_s)", 40), " [s]")
    println(ioc, lpad("Position        $(position_s)", 40), " [s]")
    println(ioc, lpad("Bars in track    $(bars_in_track)", 40))
    println(ioc, lpad("Current bars    $(current_bar)", 40))
    println(ioc, lpad("Remaining bars  $(bars)", 40))
    println(ioc)
    metfunc(stop_channel) = metronome(bpm, bpb; bars, stop_channel)
    # Run the defined metronome asyncronously
    stop_channel = Channel(metfunc, 1)
    println(ioc, "Press a key to stop metronome")
    sleep(1 / (bpm / 60) * bpb)
    # Wait for a key to stop metronome
    read(stdin, 1)
    if isopen(stop_channel) 
        put!(stop_channel, 1)
    end
    println(ioc)
    true
end


"""
    current_playlist_ranked_select_print(f, ioc)

   `f` is a function that takes the argument playlist_tracks_data::DataFrame
        and returns a vector of Float64. Example: `abnormality`.
    `func_name` can be passed as a keyword argument. Use this for anonymous functions.
"""
function current_playlist_ranked_select_print(f, ioc; func_name = "")
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
    if isnothing(st.context) || st.context.type !== "playlist"
        io = color_set(ioc, :red)
        println(io, "Player context is not a playlist; cant find audio statistics.")
        color_set(ioc)
        return false
    end
    playlist_ref, playlist_data = playlist_get_latest_ref_and_data(st.context)
    track_data = subset(playlist_data, :trackid => ByRow(==(track_id)))
    if isempty(track_data)
        io = color_set(ioc, :red)
        println(io, "Past end of playlist, in 'recommendations'.")
        color_set(ioc)
        return false
    end
    # CONSIDER: can this be generalized?
    if f == abnormality
        rpd = build_histogram_data(track_data, playlist_ref, playlist_data)
        histograms_plot(ioc, rpd)
        track_abnormality_rank_in_list_print(ioc, rpd)
    else
        text = func_name == "" ? string(f) : func_name
        fvalues = f(playlist_data)
        height = 3
        track_value = first(f(track_data))
        plot_single_histogram_with_highlight_sample(ioc, text, fvalues, track_value, height)
    end
    playlist_ranked_print_play(f, ioc, playlist_data, playlist_ref, track_id; func_name)
end

"""
    sort_playlist_other_select_print(ioc; pre_selection = nothing)

1. Pick criterion function.
2. Plot distribution of criterion(tracks), with the current track highlighted.
3. Sort tracks in current playlist by criterion function, with the current track highlighted.
4. Offer numerical selection from sorted list to play from.
"""
function sort_playlist_other_select_print(ioc; pre_selection = nothing)
    if isnothing(pre_selection)
        # danceability,key,valence,speechiness,duration_ms,instrumentalness,liveness,mode,acousticness,time_signature,energy,tempo,loudness
        println(ioc, "Track feature select")
        vs = wanted_feature_keys()
        rng = 1:length(wanted_feature_keys())
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
    if picked_key != :abnormality
        # Capture picked_key in this function that we pass on:
        function f(playlist_tracks_data)
            tr_af = playlist_tracks_data[!, picked_key]
            collect(tr_af)
        end
        current_playlist_ranked_select_print(f, ioc; func_name = "$(picked_key)")
    else
        current_playlist_ranked_select_print(abnormality, ioc)
    end
    picked_key
end

housekeeping_clones_print(ioc) = housekeeping_clones_print(ioc, tracks_data_update())


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

Please wait 1 second after changes for correct info.
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



