# This file contains smallish functions used internally by repl_player.jl (the user-facing functions).
# These are second-tier, not called directly by keypresses, rather indirect via repl_player.jl.
# Functions of some length or clearly belonging to a category is moved to separate files.

# Functions are not supposed to be interesting to call from without the special replmode.

"""
    track_album_artists_print(ioc, item::JSON3.Object)
    track_album_artists_print(ioc, rw::DataFrameRow)
"""
function track_album_artists_print(ioc, item::JSON3.Object)
    color_set(ioc)
    track_no_details_print(ioc, item.name, SpTrackId(item.id))
    print(ioc, " \\ ")
    album_no_details_print(ioc, item.album.name, item.album.release_date, SpAlbumId(item.album.id))
    print(ioc, " \\ ")
    ars = item.artists
    artist_no_details_print(ioc, [ar.name for ar in ars], [ar.id for ar in ars])
    color_set(ioc)
    nothing
end
function track_album_artists_print(ioc, rw::DataFrameRow)
    track_no_details_print(ioc, rw)
    print(ioc, " \\ ")
    album_no_details_print(ioc, rw)
    print(ioc, " \\ ")
    artist_no_details_print(ioc, rw)
    nothing
end

"""
   genres_print(ioc, item::JSON3.Object)
   Also print artists

   genres_print(ioc, gen::Vector{String}):
"""
function genres_print(ioc, item::JSON3.Object)
    ars = item.artists
    # Albums only have empty genres fields (2023).
    for ar in ars
        artist_id = SpArtistId(ar.id)
        artobj = Artists.artist_get(artist_id)[1]
        print(ioc, "  ", ar.name)
        if get(ioc, :print_ids, false)
            print(ioc, "  ")
            show(ioc, MIME("text/plain"), artist_id)
            color_set(ioc)
        end
        gen = String.(artobj.genres)
        if ! isempty(artobj.genres)
            genres_print(ioc, gen)
        else
            print(color_set(ioc, :red), " Genres unknown for this artist")
        end
        println(ioc)
    end
    nothing
end
function genres_print(ioc, gen::Vector{String})
    io = color_set(ioc, :normal)
    if !isempty(gen)
        for g in gen
            print(io, " ")
            io = color_set(io, :reverse)
            print(io, g)
            color_set(io, :normal)
        end
    else
        print(color_set(ioc, :red), " Genres unknown for this artist")
    end
    color_set(ioc)
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


"""
    current_context_ranked_select_print(f, ioc; func_name = "", alphabetically = false)

   `f` is a function that takes the argument context_tracks_data::DataFrame
        and returns a vector of Float64. Example: `abnormality`. 'deviation' is a special case and takes two.
    `func_name` can be passed as a keyword argument. Use this when passing anonymous functions.
"""
function current_context_ranked_select_print(f, ioc; func_name = "", alphabetically = false)
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
    if isnothing(st.context)
        io = color_set(ioc, :red)
        println(io, "Player context is not a playlist, album or artist; cant find context track data.")
        color_set(ioc)
        return false
    end
    if st.context.type == "playlist"
        context_typed_ref, context_tracks_data = playlist_get_latest_ref_and_data(st.context)
        if func_name == "popularity"
            # We do not store 'popularity' in the local playlist track data file
            # because it can vary quickly with time. But it can be interesting, so 
            # let's add it temporarily here.
            o = get_multiple_tracks(context_tracks_data.trackid)
            @assert length(o) == nrow(context_tracks_data)
            vpop = map(i -> i.popularity , o)
            context_tracks_data.popularity = vpop
        end
    elseif st.context.type == "album"
        context_typed_ref, context_tracks_data = album_get_id_and_data(st.context)
    elseif st.context.type == "artist"
        context_typed_ref, context_tracks_data  = artist_get_id_and_top_data(st.context)
    else
        throw(st.context.type)
    end
    current_i = findfirst( ==(track_id), context_tracks_data.trackid)
    if isnothing(current_i) 
        println(color_set(ioc, :yellow), "The currently playing song is not part of the $(st.context.type ) context.")
        println(color_set(ioc, :yellow), "We may have played past the end, or deleted the track from this playlist.")
        println(color_set(ioc, :yellow), "Ranking current with context songs is not implemented.")
        return false
    else
        context_ranked_select_print(f, ioc, context_typed_ref, context_tracks_data, context_tracks_data[current_i, :]; func_name, alphabetically)
    end
end

"""
    context_ranked_select_print(f, ioc, context_typed_ref, context_tracks_data::DataFrame, current_data_rw::DataFrameRow; func_name, alphabetically)

Called from  current_context_ranked_select_print
"""
function context_ranked_select_print(f, ioc, context_typed_ref, context_tracks_data::DataFrame, current_data_row::DataFrameRow; func_name, alphabetically)
    if ! alphabetically
        if f == abnormality
            rpd = build_histogram_data(current_data_row, context_typed_ref, context_tracks_data)
            if nrow(context_tracks_data) > 1
                histograms_plot(ioc, rpd)
            end
            track_abnormality_rank_in_list_print(ioc, rpd)
        elseif f == deviation # This takes two arguments, as calculated values depends on the current track.
            text = func_name == "" ? string(f) : func_name
            fvalues = Number.(f(context_tracks_data, current_data_row))
            height = 3
            i = findfirst( ==(current_data_row.trackid), context_tracks_data.trackid)
            track_value = fvalues[i]
            plot_single_histogram_with_highlight_sample(ioc, text, fvalues, track_value, height)
        else
            text = func_name == "" ? string(f) : func_name
            fvalues = Number.(f(context_tracks_data))
            height = 3
            i = findfirst( ==(current_data_row.trackid), context_tracks_data.trackid)
            track_value = isnothing(i) ? throw("calculate this") : fvalues[i]
            if length(fvalues) > 1
                plot_single_histogram_with_highlight_sample(ioc, text, fvalues, track_value, height)
            end
        end
    end
    context_ranked_print_play(f, ioc, context_tracks_data, context_typed_ref, current_data_row.trackid; func_name, alphabetically)
end


"""
    context_ranked_print_play(f::Function, ioc, context_tracks_data, context_typed_ref,
        current_track_id; func_name = "")\\
    ---> true

Calculate f(context_tracks_data) for all tracks in the playlist or album 'context_typed_ref'. Sort by 
return values.

Print the sorted list, emphasize track_id. For no emphasis, set track_id = nothing.

Ask for input: a track number in the list of tracks to resume playing from. Context will not be changed.

# Arguments

`f` is a function that takes the argument context_tracks_data::DataFrame
and returns a vector of Float64. Examples: `abnormality`, 'danceability', 
'trackname' (if that still exists.)
"""
function context_ranked_print_play(f::Function, ioc, context_tracks_data, context_typed_ref,
     current_track_id; func_name = "", alphabetically = false)
    track_ids = context_tracks_data[!,:trackid]
    track_names = context_tracks_data[!,:trackname]
    if f == deviation
        i = findfirst( ==(current_track_id), context_tracks_data.trackid)
        current_data_row = context_tracks_data[i,:]
        fvalues = Number.(f(context_tracks_data, current_data_row))
    else
        fvalues = f(context_tracks_data)
    end
    if context_typed_ref isa PlaylistRef
        playlist_no_details_print(color_set(ioc, :blue), context_typed_ref)
    elseif context_typed_ref isa SpAlbumId
        album_details_print(ioc, context_typed_ref)
    elseif context_typed_ref isa SpArtistId
        artist_details_print(ioc, context_typed_ref)
    else    
        throw("not implemented")
    end
    if ! alphabetically
        print(color_set(ioc, :light_black), " sorted decreasing by ")
    else
        print(color_set(ioc, :light_black), " sorted alphabetically by ")
    end
    color_set(ioc, :white)
    if func_name == ""
        print(ioc, f)
    else
        print(ioc, func_name)
    end
    color_set(ioc)
    println(ioc, ":")
    sorted_track_ids, sorted_names, sorted_values = sort_context_tracks_by_decreasing_values(track_ids, track_names, fvalues)
    context_track_values_ordinal_print(ioc, sorted_track_ids, sorted_names, sorted_values, current_track_id; alphabetically)
    if context_typed_ref isa SpArtistId
        select_trackno_and_play_print(ioc, context_typed_ref, sorted_track_ids, sorted_names; original_order = track_ids)
    else
         select_trackno_and_play_print(ioc, context_typed_ref, sorted_track_ids, sorted_names)
    end
end



function deviation(context_tracks_data::DataFrame, reference_row)
    tracks_af = select_cols_with_relevant_audio_features(context_tracks_data)
    # Each track has several 'dimensions'. We are going to look at
    # all the values in order to establish a comparable 'length' for 
    # each of the dimensions.
    #
    # Rearrange from dataframe to nested vector. Top level is each audio feature type.
    # The next level contains a value from each track in the set.
    #
    # The reference vector also contains a value per audio feature type.
    # The reference is what we're comparing with. 
    #
    # The nine dimensions for each sample has different scales.
    # So we transform the coordinates to a normalized space.
    audio_values_nested = Vector{Vector{Float64}}()
    audio_values_nested_normalized = Vector{Vector{Float64}}()
    reference_values = Vector{Float64}()
    reference_values_normalized = Vector{Float64}()
    for symb in propertynames(tracks_af)
        push!(audio_values_nested, Float64[])
        push!(audio_values_nested_normalized, Float64[])
        push!(reference_values, reference_row[symb])
    end
    for i in 1:nrow(tracks_af)
        for (j, symb) in enumerate(propertynames(tracks_af))
            push!(audio_values_nested[j], tracks_af[i, symb])
        end
    end
    reference_values_normalized = normalized_sample_deviation(audio_values_nested, reference_values)
    for i in 1:nrow(tracks_af)
        track_values = Float64.(collect(tracks_af[i,:]))
        audio_values_normalized = normalized_sample_deviation(audio_values_nested, track_values)
        for (j, symb) in enumerate(propertynames(tracks_af))
            push!(audio_values_nested_normalized[j], audio_values_normalized[j])
        end
    end
    # This is now in normalized space: reference_values_normalized and audio_values_nested_normalized
    # Let's find the nested distance vector. That is, the distance in each dimension for all tracks.
    distance_values_nested_normalized  = Vector{Vector{Float64}}()
    for (j, symb) in enumerate(propertynames(tracks_af))
        vec = audio_values_nested_normalized[j]
        distances = vec .- reference_values_normalized[j]
        push!(distance_values_nested_normalized, distances)
    end
    # Nobody's interested in multidimensional distances. Let's reduce this to a single distance 
    # for every track.
    distance_values_normalized = Vector{Float64}()
    for i in 1:nrow(tracks_af)
        distance_coordinates = Vector{Float64}()
        for (j, symb) in enumerate(propertynames(tracks_af))
            push!(distance_coordinates, distance_values_nested_normalized[j][i])
        end
        euclid_dist = sqrt(sum(distance_coordinates.^2))
        push!(distance_values_normalized, euclid_dist)
    end
    distance_values_normalized
end

"""
Making a structure from ReplPlotData was not a good choice in retrospect. 
We ought to have used dataframes consistently for style points.
"""
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
   build_histogram_data(track_data, context_typed_ref, context_data) ---> ReplPlotData

Extract and assign the data to a plottable structure.
"""
function build_histogram_data(track_data_row, context_typed_ref, context_data)
    playlist_af = select_cols_with_relevant_audio_features(context_data)
    track_af = select_cols_with_relevant_audio_features(track_data_row)
    track_name = track_data_row[:trackname]
    if context_typed_ref isa PlaylistRef
        context_name = context_typed_ref.name
    elseif context_typed_ref isa SpAlbumId
        context_name = context_data[1, :album_name]
    elseif context_typed_ref isa SpArtistId
        context_name = context_data[1, :artists][1] * " top ten"
    end
    build_histogram_data(track_name, track_af, context_name, playlist_af)
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
function select_cols_with_relevant_audio_features(df_row::DataFrameRow)
    select_cols_with_relevant_audio_features(DataFrame(df_row))
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
    print(color_set(ioc, 183), rpd.track_name)
    color_set(ioc)
    print(color_set(ioc, :light_black), "   <---->    ")
    print(color_set(ioc, :203), rpd.playlist_name)
    print(color_set(ioc, :light_black), "   ", length(rpd.data_for_bins[1]), " tracks ")
    println(color_set(ioc))
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
    # We might want to use dataframes, get rid of the stuct rpd, and reuse printing + menu functions.
    alldata = rpd.data_for_bins
    abnormality = euclidean_normalized_sample_deviation(alldata, rpd.track_values)
    io = color_set(ioc, :light_black)
    println(io)
    printstyled(io, rpd.track_name, color = :183)
    color_set(io)
    print(io, " has abnormality ")
    printstyled(io, round(abnormality, digits = 3), color=:white)
    color_set(io)
    print(io, " from mean of ")
    printstyled(io, rpd.playlist_name, color = :203)
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
    if isnothing(ordinal)
        ordinal = 1
    end
    @assert ! isnothing(ordinal)
    print(io, repeat(' ', length(rpd.track_name)))
    print(io, " takes the ")
    printstyled(io, ordinal_string(ordinal, length(abnormalities)), color=:white)
    color_set(io)
    print(io, " place of ")
    printstyled(io, length(abnormalities))
    color_set(io)
    println(io, " ranked from most to least abnormal.")
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


function abnormality(context_tracks_data::DataFrame)
    tr_af = select_cols_with_relevant_audio_features(context_tracks_data)
    # Each track has several 'dimensions'. We are going to look at
    # all the values in order to establish a comparable 'length' for 
    # each of the dimensions.
    #
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

function sort_context_tracks_by_decreasing_values(track_ids, track_names, values)
    @assert length(track_ids) == length(track_names) == length(values)
    perm = sortperm(values, rev = true)
    return track_ids[perm], track_names[perm], values[perm]
end
function context_track_values_ordinal_print(ioc, sorted_track_ids, sorted_track_names, sorted_values, emphasize_track_id; alphabetically = false)
    n = length(sorted_track_ids)
    for i in 1:n
        print(color_set(ioc, 183), lpad(sorted_track_names[i], 81))
        color_set(ioc)
        print(ioc, "  ")
        if ! alphabetically
            print(ioc, lpad(round(sorted_values[i]; digits = 3), 5))
        else
            print(ioc, "     ")
        end
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


function select_trackno_and_play_print(ioc, context_typed_ref, sorted_track_ids, sorted_track_names; original_order = SpTrackId[])
    inpno = input_number_in_range_and_print(ioc, 1:length(sorted_track_ids))
    isnothing(inpno) && return nothing
    track_id = sorted_track_ids[inpno]
    track_name = sorted_track_names[inpno]
    color_set(ioc)
    io = color_set(ioc, :light_black)
    print(io, "You picked: ")
    track_no_details_print(io, track_name, track_id)
    color_set(io)
    print(io, " from ")
    if context_typed_ref isa PlaylistRef
        playlist_no_details_print(color_set(ioc, :blue), context_typed_ref)
        context_uri = context_typed_ref.id
    elseif context_typed_ref isa SpAlbumId
        album_details_print(ioc, context_typed_ref)
        context_uri = context_typed_ref
    elseif context_typed_ref isa SpArtistId
        artist_details_print(ioc, context_typed_ref)
        context_uri = context_typed_ref
    else
        throw("not implemented")
    end
    println(io)
    offset = Dict("uri" => track_id)
    if context_typed_ref isa SpArtistId
        # (response message): Can't have offset for context type: ARTIST
        # This will play the most popular track, the first one.
        player_resume_playback(;context_uri)
        # Let's skip forward until the right track.
        println(ioc, "Skipping forward to artist context track no. ", original_index, ". Please wait.")
        for i = 1:(original_index - 1)
            player_skip_to_next()
            sleep(0.2)
        end

    else
        player_resume_playback(;context_uri, offset)
    end
    # Avoid having the previous track shown in status line...
    sleep(1)
    true
end

"""
    select_track_context_and_play_print(ioc, artist_track_context_data)

This is called from artists_tracks_request_play_in_context_print and others.
artist_track_context_data has a column pl_refs with exactly one playlist reference per cell.
"""
function select_track_context_and_play_print(ioc, artist_track_context_data)
    # The tracks and pl_refs in df has already been printed along with a number for selection.
    color_set(ioc)
    inpno = input_number_in_range_and_print(ioc, 1:nrow(artist_track_context_data))
    isnothing(inpno) && return nothing
    rw = artist_track_context_data[inpno, :]
    track_id = rw.trackid
    track_name = rw.trackname
    playlist_ref = rw.pl_ref
    color_set(ioc)
    io = color_set(ioc, :light_black)
    print(io, "You picked: ")
    track_no_details_print(io, track_name, track_id)
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



function pick_ynYNp_and_print(ioc, default::Char, playlist_ref, track_id)
    io = color_set(ioc, :176)
    uinp = 'p'
    count = 0
    msg = characters_to_ansi_escape_sequence("\nSelect option: ¨y : yes, ¨Y : yes to all, ¨n : no, ¨N : no to all, ¨p : play the replacement track ")
    while uinp == 'p' && count < 3
        color_set(io)
        print(io, "\n$(repeat("  ", count))$msg")
        uinp = read_single_char_from_keyboard("yYnNp", default)
        println(io)
        if uinp == 'p'
            color_set(ioc)
            context_uri = playlist_ref.id
            offset = Dict("uri" => track_id, "market" => "NO")
            player_resume_playback(;context_uri, offset)
            print(ioc, "\n  ")
            sleep(1)
            current_playing_print(ioc)
        end
        count += 1
    end
    color_set(ioc)
    uinp
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
¨⌫  / e : exit.  ¨? : help.  ¨⏎ / space : refresh.   ¨f / → : forward.   ¨b / ← : back. 
¨p : pause, play.   ¨0-9 : seek.  ¨c : context.  ¨m : musician.  ¨g : genres.  ¨i : ids. 
¨a : audio display.  ¨s : search.   ¨h : housekeeping.   ¨del / fn + ¨⌫ : delete track. 
~Sort then select § ¨t : by typicality.  ¨o : other features.  ¨↑ : previous selection.
        \"\"\"
    print(stdout, characters_to_ansi_escape_sequence(menu))
end
```
"""
function characters_to_ansi_escape_sequence(s)
    l = "-light_black-"# text_colors[:light_black]
    b = "-bold-" # text_colors[:bold]
    n = "-normal-"# text_colors[:normal]
    l = text_colors[:light_black]
    n = text_colors[:normal]
    b = n * text_colors[:bold]
    s = replace(s, "¨" => b ,
        ":" =>  "$n$l:",
        "/" =>  "$n$l/$b",
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
    print_and_delete(ioc, s; delay_s = 0.2)

Display s for delay_s seconds, then remove s again.

Fast feedback to show that something is happening. Unfortunately
won't run prior to compilation delays, which we should get rid of
in other ways.

Note: In VSCode terminal, this may temporarily hide previous output.
"""
function print_and_delete(ioc, s, delay_s = 0.2)
    n = length(s)
    print(ioc, s)
    sleep(delay_s)
    REPL.Terminals.cmove_left(REPL.Terminals.TTYTerminal("", stdin, stdout, stderr), n)
    print(ioc, repeat(' ', n))
    REPL.Terminals.cmove_left(REPL.Terminals.TTYTerminal("", stdin, stdout, stderr), n)
    nothing
end

"""
    duration_sec(duration_ms)
    ---> Int
Tracks may re-encode with millisecond differences that are uninteresting.
"""
duration_sec(duration_ms) = Int.(round.(duration_ms ./ 1000))

# This is intentionally duck-typed
function market_status(state, this_market::AbstractString)
    if state isa Vector
        if isempty(state)
            :empty
        elseif this_market ∈ state
            :included
        elseif this_market ∉ state
            :not_included
        else
            throw("Not expected .available_market: $state \n $this_market")
        end
    else
        if isequal(state, missing) || state == ""
            :empty
        elseif occursin(this_market, state)
            :included
        elseif ! occursin(this_market, state)
            :not_included
        else
            throw("Unpected .available_market: $state \n $this_market")
        end
    end
end

"""
    semantic_equals(x::AbstractString, y::AbstractString)

Compare lowercase version, letters and digits only
"""
function semantic_equals(x::AbstractString, y::AbstractString)
    semantic_string(x) == semantic_string(y)
end
function semantic_string(x)
    e = lowercase(x)
    f = filter(e) do c
           isletter(c) || isdigit(c)
    end
end

"""
    semantic_contains(haystack::AbstractString, y::AbstractString)

Return true if haystack contains needle.
Both arguments are stripped anything but letters and digits,
and converted to lowercase.
"""
function semantic_contains(haystack::AbstractString, needle::AbstractString)
    contains(semantic_string(haystack), semantic_string(needle))
end

"""
    stretch_string_to_length(s, l)

# Examples
```
julia> stretch_string_to_length("123", 5)
"1 2 3"

julia> stretch_string_to_length("123", 6)
"1  2 3"

julia> stretch_string_to_length(1:3,5)
"1 2 3"

julia> stretch_string_to_length(8:10,5)
"8 910"

julia> stretch_string_to_length(8:10,6)
"8 9 10"
```
"""
function stretch_string_to_length(s, l)
    ngaps = length(s) - 1
    ls = length(join(string.(s)))
    avg_gaplength = (l - ls) / ngaps
    r = ""
    for (c, g) in zip(s[1:(end - 1)], 1:ngaps)
        r *= string(c) * repeat(" ", Int(floor(avg_gaplength)))
        r *= repeat(" ", Int(ceil(g * (avg_gaplength + 1))) - length(r))
    end
    r *= string(s[end])
    @assert length(r) == l "$(length(r)) > $l: $r"
    r
end


"""
    enumerated_track_album_artist_context_print(ioc, df::DataFrame; enumerator = 1)
    --> range starting with enumerator, one count per rows in df
    enumerated_track_album_artist_context_print(ioc, dfrw::DataFrameRow; enumerated::String = "", no_track_album_artist = false)
"""
function enumerated_track_album_artist_context_print(ioc, dfrw::DataFrameRow; enumerated::String = "", no_track_album_artist = false)
    color_set(ioc)
    if ! no_track_album_artist
        println(ioc)
        track_album_artists_print(ioc, dfrw)
    end
    # playlist(s)
    if hasproperty(dfrw, :pl_ref)
        # One playlist ref in this data
        print(color_set(ioc), "\n", lpad(enumerated, 7), "    ")
        playlist_no_details_print(color_set(ioc, :blue), dfrw[:pl_ref])
    elseif hasproperty(dfrw, :playlistref)
        # Possibly several playlist refs in this data
        for c in dfrw[r"playlistref"]
            ismissing(c) && continue
            print(color_set(ioc), "\n", lpad(enumerated, 7), "    ")
            playlist_no_details_print(color_set(ioc, :blue), c)
        end
    end
    color_set(ioc)
end
function enumerated_track_album_artist_context_print(ioc, df::DataFrame; enumerator = 1)
    start = enumerator
    color_set(ioc)
    i = 0
    while i < nrow(df) 
        enumerated = string(start + i)
        i += 1
        if i == 1
            enumerated_track_album_artist_context_print(ioc, df[i,:]; enumerated)
        else
            rwp = df[i - 1, :]
            rwt = df[i, :]
            no_track_album_artist = rwp.trackid == rwt.trackid
            enumerated_track_album_artist_context_print(ioc, df[i,:]; enumerated, no_track_album_artist)
        end
    end
    start:(start + i - 1)
end

"""
    enumerated_playlist_print(ioc, playlist_refs, tracks_data; enumerator = 1)
"""
function enumerated_playlist_print(ioc, playlist_refs, tracks_data; enumerator = 1)
    start = enumerator
    color_set(ioc)
    println(ioc)
    i = 0
    while i < length(playlist_refs)
        enumerated = string(start + i)
        i += 1
        print(color_set(ioc), "\n", lpad(enumerated, 7), "    ")
        # This is rather slow because 'details' include fetching the online only description.
        playlist_details_print(color_set(ioc, :blue), playlist_refs[i].id, tracks_data)
    end
    start:(start + i - 1)
end