
function plot_audio(ioc, track_id) 
    json, waitsec = tracks_get_audio_analysis(track_id)
    plot_audio(ioc, track_id, json)
end
function plot_audio(ioc, track_id, json)
    plot_audio_beats_bars_and_tatums(ioc, json.beats, json.bars, json.tatums, json.segments)
    println(ioc)
    plot_audio_sections(ioc, json.sections)
    println(ioc)
    plot_audio_segments(ioc, json.segments)
end


function plot_audio_beats_bars_and_tatums(ioc, beats, bars, tatums, segments)
    # Plot graphics width - margin, gutter, border etc.
    nx = displaysize(ioc)[2] - 9
    # Map from graphics to time 
    t_rel(ix) = (ix - 1) / nx
    # Map from time to section
    dur_s = bars[end].start + bars[end].duration
    beat_starts_rel = [beat.start / dur_s for beat in beats]
    beat_no(tr) = findlast(<=(tr), beat_starts_rel)
    bar_starts_rel = [bar.start / dur_s for bar in bars]
    bar_no(tr) = findlast(<=(tr), bar_starts_rel)
    tatum_starts_rel = [tatum.start / dur_s for tatum in tatums]
    tatum_no(tr) = findlast(<=(tr), tatum_starts_rel)
    segment_starts_rel = [segment.start / dur_s for segment in segments]
    segment_no(tr) = findlast(<=(tr), segment_starts_rel)

    # Build the vectors with the same number of elements as we are able to show.
    t = map(t_rel, 1:nx)
    vec_beats = map(1:nx) do ix
        i = beat_no(t_rel(ix))
        beats[isnothing(i) ? 1 : i].duration
    end
    replace!(vec_beats, 0 => NaN)
    vec_bars = map(1:nx) do ix
        i = bar_no(t_rel(ix))
        bars[isnothing(i) ? 1 : i].duration
    end
    replace!(vec_bars, 0 => NaN)
    vec_tatums = map(1:nx) do ix
        i = tatum_no(t_rel(ix))
        tatums[isnothing(i) ? 1 : i].duration
    end
    replace!(vec_tatums, 0 => NaN)
    vec_segments = map(1:nx) do ix
        i = segment_no(t_rel(ix))
        segments[isnothing(i) ? 1 : i].duration
    end
    replace!(vec_segments, 0 => NaN)
    aligned_vecs = hcat(vec_beats, vec_bars, vec_tatums, vec_segments)
    plot_as_line_stretched_to_width(ioc, t, aligned_vecs, "Bar, beat, tatum, segment duration [s]", height = 10)
end

function plot_loudness_variation(ioc, segments)
    # Plot graphics width - margin, gutter, border etc.
    nx = displaysize(ioc)[2] - 9
    # Map from graphics to time 
    t_rel(ix) = (ix - 1) / nx
    # Map from time to segment
    dur_s = segments[end].start + segments[end].duration
    segment_starts_rel = [segment.start / dur_s for segment in segments]
    segment_no(tr) = findlast(<=(tr), segment_starts_rel)
    # Build the vectors with the same number of elements as we are able to show.
    t = map(t_rel, 1:nx)
    vec_loudness_max = map(1:nx) do ix
        i = segment_no(t_rel(ix))
        segments[isnothing(i) ? 1 : i].loudness_max
    end
    replace!(vec_loudness_max, 0 => NaN)
    vec_loudness_start = map(1:nx) do ix
        i = segment_no(t_rel(ix))
        segments[isnothing(i) ? 1 : i].loudness_start
    end
    replace!(vec_loudness_start, 0 => NaN)
    aligned_vecs = hcat(vec_loudness_max, vec_loudness_start)
    plot_as_line_stretched_to_width(ioc, t, aligned_vecs, "Loudness at start and max of segments[dB]", height = 10)
end

function plot_audio_sections(ioc, sections)
    # Confidence (commented out because it does not seem to be that useful)
    #plot_audio_sections_as_line(ioc, sections, :confidence, "Confidence in tempo")
    # Time signature (beats per bar)
    if length(unique(map(s -> s.time_signature, sections))) > 1
        plot_audio_sections_as_line(ioc, sections, :time_signature, "Time signature (beats per bar)"; height = 4)
        println(ioc)
    end
    # Tempo
    plot_audio_sections_as_line(ioc, sections, :tempo, "Tempo [bpm]"; height = 6)
end

function plot_audio_sections_as_line(ioc, sections, property::Symbol, title; height = 8)
    # Plot graphics width - margin, gutter, border etc.
    nx = displaysize(ioc)[2] - 9
    # Map from graphics to time 
    t_rel(ix) = (ix - 1) / nx
    # Map from time to section
    dur_s = sections[end].start + sections[end].duration
    section_starts_rel = [sec.start / dur_s for sec in sections]
    section_no(tr) = findlast(<=(tr), section_starts_rel)
    # Build the vectors with the same number of elements as we are able to show.
    t = map(t_rel, 1:nx)
    v = map(1:nx) do ix
        is = section_no(t_rel(ix))
        sections[is][property]
    end
    replace!(v, 0 => NaN)
    if property == :tempo
        mi = round(minimum(v), digits = 1)
        ma = round(maximum(v), digits = 1)
        title *= " ($mi - $ma)"
    end
    plot_as_line_stretched_to_width(ioc, t, v, title; height)
end

"""
    plot_as_line_stretched_to_width(ioc, t, v, title)

t and v lengths ought to be based on displaysize(ioc)[2]
"""
function plot_as_line_stretched_to_width(ioc, t, v, title; height = 5)
    nx = size(v, 1)
    if size(v, 2) > 1
        ymax = round(maximum(v), digits = 2)#Int(ceil(maximum(v)))
        ymin = Int(floor(minimum(v)))
        pl = lineplot(t, v; width = nx, height, title, name = repeat([""], size(v, 1)), ylim = (ymin, ymax), padding = 0)
    else
        pl = lineplot(t, v; width = nx, height, title, padding = 0)
    end
    # The margins argument does not work intuitively, so modify instead:
    pl.margin[] = max(0, 5 - maximum(length.(values(pl.labels_left))))
    # Modify x-labels.
    pop!(pl.decorations, :bl)
    pop!(pl.decorations, :br)
    push!(pl.decorations, :b => stretch_string_to_length(0:10, nx))
    println(ioc, pl)
    pl
end

function plot_audio_segments(ioc, segments)
    plot_loudness_variation(ioc, segments)
    # Timbre
    ti = ["Lo", "Br", "Fl", "At", "5 ", "6 ", "7 ", "8 ", "9 ", "10", "11", "12"]
    plot_as_matrix_stretched_to_width(ioc, segments, :timbre, ti, "Timbre - time")
    # Pitches
    to = ["C ", "D♭", "D ", "E♭", "E ", "F ", "G♭", "G ", "A♭", "A ", "B♭", "H "]
    plot_as_matrix_stretched_to_width(ioc, segments, :pitches, to, "Pitches - time")
end

function plot_as_matrix_stretched_to_width(ioc, segments, pitches_or_timbre::Symbol, potential_ylabels, title)
    # Pitches or timbres vector length = graphics height in "pixels"
    np = 12
    # Plot graphics width - margin, gutter, border etc.
    nx = displaysize(ioc)[2] - 9
    # Map from graphics to time 
    t_rel(ix) = (ix - 1) / nx
    # Map from time to segment
    dur_s = segments[end].start + segments[end].duration
    segment_starts_rel = [seg.start / dur_s for seg in segments]
    segment_no(tr) = findlast(<=(tr), segment_starts_rel)
    # Build the matrix
    mat = repeat((1 / np ) * collect(1:nx)', outer=(np, 1))
    for ix = 1:nx
        is = segment_no(t_rel(ix))
        mat[:, ix] = segments[is][pitches_or_timbre]
    end
    # The matrix as graphics
    pl = heatmap(mat; width = nx, height = np, colorbar = false, xfact = 10 / (nx - 1), title, padding = 0)
    # The margins argument does not work intuitively, so modify instead:
    pl.margin[] = max(0, 4 - maximum(length.(values(pl.labels_left))))
    # Modify labels and decorations. Each line takes two "pixel heights".
    pop!(pl.decorations, :bl)
    pop!(pl.decorations, :br)
    push!(pl.decorations, :b => stretch_string_to_length(0:10, nx))
    push!(pl.labels_left, 6 => potential_ylabels[1]) # Bottom label
    push!(pl.labels_left, 5 => potential_ylabels[3])
    push!(pl.labels_left, 4 => potential_ylabels[5])
    push!(pl.labels_left, 3 => potential_ylabels[7])
    push!(pl.labels_left, 2 => potential_ylabels[9])
    push!(pl.labels_left, 1 => potential_ylabels[11]) # Top label
    # Display plot prior to return.
     println(ioc, pl)
    pl
end

function rhythmic_progress_print(ioc, json, t_0, progress_0)
    # Line width to use, all of it at full time
    nx = displaysize(ioc)[2] - 9
    # Currently progressed time
    current_progress() = time() - t_0 + progress_0
    # Map from time to column
    dur_s = json.beats[end].start + json.beats[end].duration
    column_no(t_passed) = t_passed < dur_s ? Int(floor(nx * t_passed / dur_s + 1)) : nothing
    current_column_no() = column_no(current_progress())
    # Map from time to beat no.
    beat_starts = [beat.start for beat in json.beats]
    beat_no(time_progress) = findlast(<=(time_progress), beat_starts)
    # Map from time to bar no.
    bar_starts = [bar.start for bar in json.bars]
    bar_no(time_progress) = findlast(<=(time_progress), bar_starts)
    beat_duration(time_progress) = time_progress < dur_s ? json.beats[beat_no(time_progress)][:duration] : nothing
    # No-argument functions to pass.
    current_pausetime() = beat_duration(current_progress())
    current_beat_no() = beat_no(current_progress())
    current_bar_no() = bar_no(current_progress())
    # Feedback
    get(ioc, :print_instructions, false)  &&  println(ioc, "Menu keys 0-9 active, other keys exit to menu.")
    # Define task with stopping mechanism
    func(stop_channel) = rhythmic_progress_print(ioc, current_column_no, current_pausetime, current_beat_no, current_bar_no; stop_channel)
    # Run the defined task asyncronously
    stop_channel = Channel(func, 1)
    # Perhaps unnecessary, but allow some time for the other task here
    sleep(0.3)
    # Wait for a key to stop rhytmic progress print
    returnkey = String(read(stdin, 1))
    if isopen(stop_channel)
        put!(stop_channel, 1)
        # Allow scheduler to finish async task
        yield()
        if '0' <= Char(returnkey[1]) <= '9'
            return returnkey
        end
    end
    nothing
end

function rhythmic_progress_print(ioc, current_column_no, current_pausetime, current_beat_no, current_bar_no; stop_channel = Channel(1))
    ccno = current_column_no()
    cbeno = current_beat_no()
    cbano = current_bar_no()
    beatcount = 0
    while !isnothing(ccno) && ! isready(stop_channel)
        color_set(ioc)
        iseven(cbano) && color_set(ioc, :normal)
        print(ioc, lpad("$cbano/$beatcount", 5))
        print(ioc, repeat(" ", ccno), "↑")
        print(ioc, beatcount)
        sleep(current_pausetime())
        REPL.Terminals.clear_line(REPL.Terminals.TTYTerminal("", stdin, stdout, stderr))
        ccno = current_column_no()
        cbeno = current_beat_no()
        if cbano !== current_bar_no()
            beatcount = 1
            cbano = current_bar_no()
        else
            beatcount += 1
        end
    end
    if ! isready(stop_channel)
         println(ioc, "Track finished, any key to continue.")
    end
    # Cleanup
    isready(stop_channel) && take!(interruptchannel)
    nothing
end