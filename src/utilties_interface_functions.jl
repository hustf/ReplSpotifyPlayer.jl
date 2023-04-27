# This file contains functions used internally by repl_player.jl (the user-facing functions).
# These are second-tier, not called directly by keypresses, rather indirect.
# They do not fit neatly in player_interface_functions or playlist_interface_functions.
# They are not supposed to be interesting to call from without the special replmode.

"track_album_artists_print(ioc, item::JSON3.Object)"
function track_album_artists_print(ioc, item::JSON3.Object)
    print(ioc, item.name, " \\ ", item.album.name)
    ars = item.artists
    vs = [ar.name for ar in ars]
    print(ioc, " \\ ", join(vs, " & "))
    if get(ioc, :print_ids, false)
        track_id = SpTrackId(item.id)
        print(ioc, "  ")
        show(ioc, MIME("text/plain"), track_id)
        color_set(ioc)
    end
    nothing
end

"track_album_artists_print(ioc, item::JSON3.Object)"
function genres_print(ioc, item::JSON3.Object)
    ars = item.artists
    # Albums only have empty genres fields (2023).
    for ar in ars
        artist_id = SpArtistId(ar.id)
        artobj = Artists.artist_get(artist_id)[1]
        gen = artobj.genres
        if !isempty(gen)
            print(ioc, "  ", ar.name)
            if get(ioc, :print_ids, false)
                print(ioc, "  ")
                show(ioc, MIME("text/plain"), artist_id)
                color_set(ioc)
            end
            for g in gen
                print(ioc, " ")
                io = color_set(ioc, :reverse)
                print(io, g)
                print(io, text_colors[:normal])
                color_set(ioc)
            end
        else
            print(color_set(ioc, :red), " Genres unknown for this artist")
        end
        println(ioc)
    end
    nothing
end



"track_in_playlists_print(ioc, track_id) ---> Bool"
function track_in_playlists_print(ioc, track_id)
    track_also_in_playlists_print(ioc, track_id, JSON3.Object())
end

"""
    track_also_in_playlists_print(ioc, track_id, otherthan::JSON3.Object) ---> Bool
"""
function track_also_in_playlists_print(ioc, track_id, otherthan::JSON3.Object)
    if ! isempty(otherthan)
        if otherthan.type == "collection" || otherthan.type == "album"
            otherthan_playlistid =  SpPlaylistId("1234567890123456789012")
        elseif otherthan.type == "playlist"
            otherthan_playlistid =  SpPlaylistId(otherthan.uri)
        else
            @show otherthan
            throw("didn't think of that")
        end
    else
        otherthan_playlistid =  SpPlaylistId("1234567890123456789012")
    end
    plls = map(t-> t.id, playlistrefs_containing_track(track_id))
    other_playlists = filter(l -> l !== otherthan_playlistid, plls)
    if ! isempty(other_playlists) && isempty(otherthan)
        println(ioc, " Current track is used in:")
    end
    for l in other_playlists
        print(ioc, "       ")
        playlist_details_print(ioc, l)
        color_set(ioc)
        println(ioc)
    end
    length(other_playlists) > 0 ? true : false
end


struct ReplPlotData
    playlist_name::String
    track_name::String
    height::Integer
    text::Vector{String}
    data_for_bins::Vector{Vector{Float64}}
    track_values::Vector{Float64}
    series::Vector{String}
end
ReplPlotData(;playlist_name = "", track_name = "", height = 3) = ReplPlotData(playlist_name, track_name, height, String[], Vector{Vector{Float64}}(), Float64[], String[])

"""
   build_histogram_data(track_data, playlist_ref, playlist_data) ---> ReplPlotData

Extract and assign the data to a plottable structure.
"""
function build_histogram_data(track_data, playlist_ref, playlist_data)
    playlist_af = select_cols_with_relevant_audio_features(playlist_data)
    track_af = select_cols_with_relevant_audio_features(track_data)
    track_name = track_data[1, :trackname]
    build_histogram_data(track_name, track_af, playlist_ref.name, playlist_af)
end

"""
    select_cols_with_relevant_audio_features(df) 
    ---> DataFrame

Extract the dataframe columns we need for typicality analysis
"""
function select_cols_with_relevant_audio_features(df)
    bigset =  df[!, wanted_feature_keys()]
    exclude = [:duration_ms, :mode, :loudness, :key]
    select(bigset, Not(exclude))
end

"""
    build_histogram_data(track_name, track_plot_data, playlist_name::String, playlist_plot_data)
    ---> ReplPlotData

Assign dataframe data to ad-hoc structure
"""
function build_histogram_data(track_name, track_plot_data, playlist_name::String, playlist_plot_data)
    bpd = ReplPlotData(; playlist_name, track_name)
    for (s, p, t) in zip(propertynames(playlist_plot_data), eachcol(playlist_plot_data), eachcol(track_plot_data))
        build_histogram_data!(bpd, s, Float64(first(t)), Float64.(p))
    end
    bpd
end
function build_histogram_data!(rpd, column_symbol, t::T, p::Vector{T}) where T <: Float64
    push!(rpd.text, "$column_symbol")
    push!(rpd.data_for_bins, p)
    push!(rpd.track_values, t)
    rpd
end


"""
   histograms_plot(ioc, rpd::ReplPlotData)

Plots several histograms with highlighted samplas and a common title
"""
function histograms_plot(ioc, rpd::ReplPlotData)
    # Print the title
    println(ioc)
    printstyled(ioc, rpd.track_name, color = :green)
    printstyled(ioc, "   <---->    ", color = :light_black)
    printstyled(ioc, rpd.playlist_name, color = :blue)
    printstyled(ioc, "   ", length(rpd.data_for_bins[1]), " tracks ", color = :light_black)
    println(ioc)
    for (text, data_for_bins, track_value) in zip(rpd.text, rpd.data_for_bins, rpd.track_values)
        plot_single_histogram_with_highlight_sample(ioc, text, data_for_bins, track_value, rpd.height)
    end
    true
end

"""
    plot_single_histogram_with_highlight_sample(ioc, text, data_for_bins, track_value, height)

Called from `histograms_plot`.

# Arguments

- data_for_bins is a vector of values
- track_value is a value within the limits of data_for_bins to highlight
   It could be one of the values, and does not affect mean μ and deviation σ.
- text is what values represent, e.g. "tempo"
"""
function plot_single_histogram_with_highlight_sample(ioc, text, data_for_bins, track_value, height)
    # Horizontal histograms look better, but the only way to mark the current track's value would
    # be to pick the correct bin and change the bin's color, e.g. through p.graphics.color.
    # A parameter, 'name', can also be given but does not show (without fooling around with margins at least)
    samples = length(data_for_bins)
    nbins = UnicodePlots.sturges(samples)
    width = max(25, Int(round(nbins * 40 / 25)))
    s_track_value = string(round(track_value; digits = 3))
    title_with_format_characters = "~Distribution of §$(text)~ with highlighted track value of §$(s_track_value)"
    title = characters_to_ansi_escape_sequence(title_with_format_characters)
    p = histogram(data_for_bins, nbins = nbins, title = title,
        height = height, width = width, 
        color = :red, stats = true, labels=true, border =:none, vertical = true)
    #
    # Use the 'xlabel' to mark the current track's value to show how typical it is of this playlist values.
    #
    mi = minimum(data_for_bins)
    ma = maximum(data_for_bins)
    if ma == mi
        rel_track_value = 0.5
    else
        rel_track_value = (track_value - mi) / (ma - mi)
    end
    wi = UnicodePlots.ncols(p.graphics)
    # Column number corresponding to track_value
    c = max(1, Int(ceil(wi * rel_track_value)))
    s = rpad(s_track_value, 8)
    xlabel = rpad(repeat(' ', c - 1 ) * "↑ " * s, wi)
    p.xlabel[] = xlabel
    #
    # Show mean and sample standard deviation 
    #
    μ = mean(data_for_bins)
    σ = std(data_for_bins, corrected = true)
    # Coefficient of variation
    Δ = track_value - μ
    if σ == 0
        @assert Δ == 0
        Δ_per_σ = 0
    else
        Δ_per_σ = round(Δ / σ; digits = 2)
    end
    tracktext = "$text = μ"
    tracktext *= text_colors[:normal]
    if Δ_per_σ  < 0
        tracktext *= " - $(-Δ_per_σ)"
    else
        tracktext *= " + $(Δ_per_σ)"
    end
    tracktext *= text_colors[:light_black]
    tracktext *= "σ"
    push!(p.labels_right, 1  => tracktext)
    push!(p.labels_right, 2 => lpad("μ = $(round(μ, digits = 2))", length(tracktext)))
    push!(p.labels_right, 3 => lpad("σ = $(round(σ, digits = 2))", length(tracktext)))
    println(ioc, p)
    true
end


"""
    track_abnormality_rank_in_list_print(ioc, rpd)

Print the current track's "abnormality" and
how it ranks compared to the other tracks in the 
playlist.
"""
function track_abnormality_rank_in_list_print(ioc, rpd)
    alldata = rpd.data_for_bins
    abnormality = euclidean_normalized_sample_deviation(alldata, rpd.track_values)
    io = color_set(ioc, :light_black)
    println(io)
    printstyled(io, rpd.track_name, color = :green)
    color_set(io)
    print(io, " has abnormality ")
    printstyled(io, round(abnormality, digits = 3), color=:white)
    color_set(io)
    print(io, " from mean of playlist ")
    printstyled(io, rpd.playlist_name, color = :blue)
    color_set(io)
    println(io, ".")
    # Compare with the other tracks
    abnormalities = Float64[]
    for track_index in 1:length(first(alldata))
        abnorm = euclidean_normalized_sample_deviation(alldata, track_index)
        push!(abnormalities, abnorm)
    end
    sort!(abnormalities, rev = true)
    ordinal = findfirst(==(abnormality), abnormalities)
    @assert ! isnothing(ordinal)
    print(io, repeat(' ', length(rpd.track_name)))
    print(io, " takes the ")
    printstyled(io, ordinal_string(ordinal, length(abnormalities)), color=:white)
    color_set(io)
    print(io, " place of ")
    printstyled(io, length(abnormalities))
    color_set(io)
    println(" ranked from most to least abnormal.")
    color_set(ioc)
    ordinal
end


"""
    ordinal_string(place_in_set)
    ---> String

Returns English description of {1. , 2., ... ,21. } place number in a set.
"""
function ordinal_string(ordinal, setsize)
    isnan(ordinal) && return "$ordinal."
    ld = first(digits(ordinal))
    @assert ordinal <= setsize
    if ordinal == 1
        "first"
    elseif ordinal == 2
        "second"
    elseif ordinal == 3
        "third"
    elseif ordinal == 4
        "fourth"
    elseif ordinal == setsize 
        "last"
    elseif ld == 1 && ordinal > 20
        "$(ordinal)st"
    elseif ld == 2 && ordinal > 20
        "$(ordinal)nd"
    elseif ld == 3 && ordinal > 20
        "$(ordinal)rd"
    else
        "$(ordinal)th"
    end
end

"""
    playlist_ranked_print_play(f::Function, ioc, playlist_tracks_data, playlist_ref,
        current_track_id; func_name = "")\\
    ---> true
    
Calculate f(playlist_tracks_data) for all tracks. Sort by rising
return values.

Print the sorted list, emphasize track_id. For no emphasis, set track_id = nothing.

Ask for input: a track number in list to resume playing from.

# Arguments

`f` is a function that takes the argument playlist_tracks_data::DataFrame
and returns a vector of Float64. Example: `abnormality`.
 For example, 'danceability', 'popularity' (if that still exists.)
"""
function playlist_ranked_print_play(f::Function, ioc, playlist_tracks_data, playlist_ref,
     current_track_id; func_name = "")
    track_ids = playlist_tracks_data[!,:trackid]
    track_names = playlist_tracks_data[!,:trackname]
    fvalues = f(playlist_tracks_data)
    playlist_no_details_print(color_set(ioc, :blue), playlist_ref)
    print(color_set(ioc, :light_black), " sorted decreasing by ")
    color_set(ioc, :white)
    if func_name == ""
        print(ioc, f)
    else
        print(ioc, func_name)
    end
    color_set(ioc)
    println(ioc, ":")
    sorted_track_ids, sorted_names, sorted_values = sort_playlist_by_decreasing_values(track_ids, track_names, fvalues)
    playlist_values_ordinal_print(ioc, sorted_track_ids, sorted_names, sorted_values, current_track_id)
    select_trackno_and_play_print(ioc, playlist_ref, sorted_track_ids, sorted_names)
end

function abnormality(playlist_tracks_data::DataFrame)
    tr_af = select_cols_with_relevant_audio_features(playlist_tracks_data)
    # Rearrange from dataframe to nested vector - one vector 
    # contains a feature per track.
    audiodata = Vector{Vector{Float64}}()
    for j in 1:ncol(tr_af)
        push!(audiodata, Float64[])
    end
    for i in 1:nrow(tr_af)
        for j in 1:ncol(tr_af)
            push!(audiodata[j], tr_af[i, j])
        end
    end
    abnormalities = Float64[]
    for i in 1:nrow(tr_af)
        push!(abnormalities, euclidean_normalized_sample_deviation(audiodata, i))
    end
    abnormalities
end
function sort_playlist_by_decreasing_values(track_ids, track_names, values)
    @assert length(track_ids) == length(track_names) == length(values)
    perm = sortperm(values, rev = true)
    return track_ids[perm], track_names[perm], values[perm]
end
function playlist_values_ordinal_print(ioc, sorted_track_ids, sorted_track_names, sorted_values, emphasize_track_id)
    n = length(sorted_track_ids)
    for i in 1:n
        print(ioc, lpad(sorted_track_names[i], 81))
        print(ioc, "  ")
        print(ioc, lpad(round(sorted_values[i]; digits = 3), 5))
        print(ioc, lpad(ordinal_string(i, n), 12))
        if sorted_track_ids[i] == emphasize_track_id
             print(ioc, " ←")
        else
            print(ioc, "  ")
        end
        if get(ioc, :print_ids, false)
            print(ioc, " ")
            show(ioc, MIME("text/plain"), sorted_track_ids[i])
            color_set(ioc)
        end
        println(ioc)
    end
    return sorted_track_ids, sorted_track_names, sorted_values
end
function select_trackno_and_play_print(ioc, playlist_ref, sorted_track_ids, sorted_track_names)
    inpno = input_number_in_range_and_print(ioc, 1:length(sorted_track_ids))
    isnothing(inpno) && return nothing
    track_id = sorted_track_ids[inpno]
    track_name = sorted_track_names[inpno]
    color_set(ioc)
    io = color_set(ioc, :light_black)
    print(io, "You picked: ")
    color_set(ioc)
    print(ioc, "  ", track_name)
    if get(ioc, :print_ids, false)
        print(ioc, "  ")
        show(ioc, MIME("text/plain"), track_id)
        color_set(ioc)
    end
    color_set(io)
    print(io, " from ")
    playlist_no_details_print(color_set(ioc, :blue), playlist_ref)
    println(io)
    context_uri = playlist_ref.id
    offset = Dict("uri" => track_id)

    player_resume_playback(;context_uri, offset)
    # Avoid having the previous track shown in status line...
    sleep(1)
    true
end

function input_number_in_range_and_print(ioc, rng)
    io = color_set(ioc, :176)
    print(io, "Type number ∈ $rng to play! Press enter to do nothing: ")
    inpno = read_number_from_keyboard(rng)
    println(io)
    color_set(ioc)
    inpno
end

"""
    read_number_from_keyboard(rng)
    ---> Union{Nothing, Int64}

We can't use readline(stdin) while in our special replmode - that would block.

If this is called from the normal REPL mode, it will be necessary
to press enter after the number. Only the characters necessary for
a number in `rng` will be read, and the remaining characters in buffer
are processed by REPL as usual.
"""
function read_number_from_keyboard(rng)
    remaining_digits = length(string(maximum(rng)))
    buf = ""
    print(stdout, repeat('_', remaining_digits))
    REPL.Terminals.cmove_left(REPL.Terminals.TTYTerminal("", stdin, stdout, stderr), remaining_digits)

    while remaining_digits >= minimum(rng)
        remaining_digits -= 1
        c = Char(first(read(stdin, 1)))
        print(stdout, c)
        c < '0' && break
        c > '9' && break
        buf *= c
    end
    inpno = tryparse(Int64, buf)
    isnothing(inpno) && return nothing
    inpno ∉ rng && return nothing
    inpno
end

function pick_ynYNp_and_print(ioc, default::Char, playlist_ref, track_id)
    io = color_set(ioc, :176)
    uinp = 'p'
    count = 0
    while uinp == 'p' && count < 3
        color_set(io)
        print(io, "\n$(repeat("  ", count))What does you say? (y: yes, Y: yes to all, n: no, N: no to all, p: play track to replace)")
        uinp = read_single_char_from_keyboard("yYnNp", default)
        println(io)
        if uinp == 'p'
            context_uri = playlist_ref.id
            offset = Dict("uri" => track_id, "market" => "NO")  
            response = player_resume_playback(;context_uri, offset)
            print(ioc, "\n  ")
            sleep(1)
            current_playing_print(ioc)
            color_set(ioc)
        end
        count += 1
    end
    color_set(ioc)
    uinp
end

"""
    read_single_char_from_keyboard(string_allowed_characters, default::Char)
    ---> Union{Nothing, Char}

We can't use readline(stdin) while in our special replmode - that would block.

If this is called from the normal REPL mode, it will be necessary
to press enter after the character. 

If a character not in string_allowed_characters is pressed, returns default.
"""
function read_single_char_from_keyboard(string_allowed_characters, default::Char)
    c = Char(first(read(stdin, 1)))
    print(stdout, c)
    if c ∈ string_allowed_characters
        c
    else
        default
    end
end


"""
    characters_to_ansi_escape_sequence(s)

Shorthands that make writing mixed-formatting more Wysiwyg.
This 'returns' to :normal, which most often is not what we want
in this program. So most prints modify IOContext instead and
can't use these shorthands.

# Example

```
begin
menu =  \"\"\"
        ¨e : exit.     ¨f(¨→) : forward.     ¨b(¨←) : back.     ¨p: pause, play.     ¨0-9:  seek.
        ¨del(¨fn + ¨⌫  ) : delete from playlist.          ¨c : context.          ¨m : musician.
        ¨i : toggle ids. ¨r : rhythm test. ¨a : audio features. ¨h : housekeeping. ¨? : syntax.
            Sort list, play selected          ¨t : by typicality.     ¨o : other features.
        \"\"\"
    print(stdout, characters_to_ansi_escape_sequence(menu))
end
```

"""
function characters_to_ansi_escape_sequence(s)
    l = text_colors[:light_black]
    b = text_colors[:bold]
    n = text_colors[:normal]
    s = replace(s, "¨" => b , 
        ":" =>  "$n$l:",
        "." => ".$n",
        " or" => "$n$l or$n",
        "+" => "$n+",
        "(" => "$n(",
        ")" => "$n)",
        "~" => "$n$l",
        "§" => n)
    s *= n
end


"""
    color_set(io, col::Union{Int64, Symbol})\\
    color_set(ioc::IO)\\
    ---> IOContext

We want to a 'context color' down through the function hierarcy, where
the replmode menue is topmost.
"""
function color_set(io, col::Union{Int64, Symbol})
    ioc = IOContext(io, :context_color => col)
    color_set(ioc)
    ioc
end
function color_set(ioc::IO)
  col = get(ioc, :context_color, :normal)
  print(ioc, text_colors[col])
  ioc
end


"""
    print_and_delete(ioc, str; duration_s = 0.2)

Display str for duration_s seconds.

Fast feedback to show that something is happening. Unfortunately
will wait for compilation delays, which we should get rid of.
"""
function print_and_delete(ioc, str, duration_s = 0.2)
    n = length(str)
    print(ioc, str)
    sleep(duration_s)
    REPL.Terminals.cmove_left(REPL.Terminals.TTYTerminal("", stdin, stdout, stderr), n)
    print(ioc, repeat(' ', n))
    REPL.Terminals.cmove_left(REPL.Terminals.TTYTerminal("", stdin, stdout, stderr), n)
end
