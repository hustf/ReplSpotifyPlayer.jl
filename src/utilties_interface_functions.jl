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


"""
    track_also_in_playlists_print(ioc, track_id, otherthan::JSON3.Object) -> Bool
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
ReplPlotData(;playlist_name = "", track_name = "", height = 4) = ReplPlotData(playlist_name, track_name, height, String[], Vector{Vector{Float64}}(), Float64[], String[])

"""
   build_histogram_data(track_data, playlist_ref, playlist_data) -> ReplPlotData

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
    --> DataFrame

Extract the dataframe columns we need for typicality analysis
"""
function select_cols_with_relevant_audio_features(df)
    bigset =  df[!, wanted_feature_keys()]
    exclude = [:duration_ms, :mode, :loudness, :key]
    select(bigset, Not(exclude))
end

"""
    build_histogram_data(track_name, track_plot_data, playlist_name::String, playlist_plot_data)

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
   histograms_plot(ioc, rpd::ReplPlotData) -> Bool

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

Called from `histograms_plot`
"""
function plot_single_histogram_with_highlight_sample(ioc, text, data_for_bins, track_value, height)
    # Horizontal histograms look better, but the only way to mark the current track's value would
    # be to pick the correct bin and change the bin's color, e.g. through p.graphics.color.
    # A parameter, 'name', can also be given but does not show (without fooling around with margins at least)
    samples = length(data_for_bins)
    nbins = max(5, Int(round(samples / 23)))
    width = Int(round(nbins * 40 / 25))
    ylabel = lpad("$text: $(round(track_value; digits = 3))", 24) 
    p = histogram(data_for_bins, nbins = nbins, ylabel = ylabel,
        height = height, width = width, 
        color = :red, stats = false, labels=true, border =:none, vertical = true)

    # Mark the current track's value to show how typical it is of this playlist.
    # Note this does not always align well with bin values. Some tweaks could be made.
    vline!(p, track_value)
    μ = mean(data_for_bins)
    σ = std(data_for_bins, corrected = true)
    # Coefficient of variation
    Δ = track_value - μ
    if σ == 0
        @assert Δ == 0
        Δ_per_σ = 0
    else
        Δ_per_σ = round((Δ - μ) / σ; digits = 2)
    end
    tracktext = "$text = μ"
    if Δ_per_σ  < 0
        tracktext *= " - $(-Δ_per_σ)σ"
    else
        tracktext *= " + $(Δ_per_σ)σ"
    end
    push!(p.labels_right, 1  => tracktext)
    push!(p.labels_right, 2 => lpad("μ = $(round(μ, digits = 2))", length(tracktext)))
    push!(p.labels_right, 3 => lpad("σ = $(round(σ, digits = 2))", length(tracktext)))
    println(ioc, p)
end

function abnormality_rank_print(ioc, rpd)
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
#        track_values = map(featuretype-> featuretype[track_index], alldata)
#        @assert length(track_values) == length(alldata)
        abnorm = euclidean_normalized_sample_deviation(alldata, track_index)
        push!(abnormalities, abnorm)
    end
    sort!(abnormalities)
    ordinal = findfirst(==(abnormality), abnormalities)
    @assert ! isnothing(ordinal)
    print(io, repeat(' ', length(rpd.track_name)))
    print(io, " takes the ")
    printstyled(io, ordinal_string(ordinal, length(abnormalities)), color=:white)
    color_set(io)
    print(io, " place of ")
    printstyled(io, length(abnormalities))
    color_set(io)
    println(" ranked from most to least typical.")
    color_set(ioc)
end


"""
    ordinal_string(place_in_set)

Returns English description of {1. , 2., ... ,21. }
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
    elseif ordinal == setsize - 1
        "second last"
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

function abnormality_playlist_ranked_print(ioc, playlist_tracks_data)
    tr_af = select_cols_with_relevant_audio_features(playlist_tracks_data)
    names = String[]
    trackids = SpTrackId[]
    audiodata = Vector{Vector{Float64}}()
    for j in 1:ncol(tr_af)
        push!(audiodata, Float64[])
    end
    for i in 1:nrow(tr_af)
        push!(names, playlist_tracks_data[i, :trackname])
        push!(trackids, playlist_tracks_data[i, :trackid])
        for j in 1:ncol(tr_af)
            push!(audiodata[j], tr_af[i, j])
        end
    end
    abnormalities = Float64[]
    for i in 1:nrow(tr_af)
        push!(abnormalities, euclidean_normalized_sample_deviation(audiodata, i))
    end
    # Sort playlist by abnormality
    perm = sortperm(abnormalities)
    names = names[perm]
    trackids = trackids[perm]
    abnormalities = abnormalities[perm]
    for i in 1:nrow(tr_af)
        print(ioc, lpad(names[i], 81))
        print(ioc, "  ")
        print(ioc, lpad(round(abnormalities[i]; digits = 3), 5))
        println(ioc, lpad(ordinal_string(i, nrow(tr_af)), 12))
    end
    println(ioc)
end

