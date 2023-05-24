using Test
using ReplSpotifyPlayer
using ReplSpotifyPlayer: tracks_get_audio_analysis, plot_audio_sections, plot_audio_segments, plot_audio
using ReplSpotifyPlayer: get_player_state, stretch_string_to_length
using UnicodePlots

track_id = SpTrackId("spotify:track:3yKDTSL7IbEGJy7pm8tSgK")
json, waitsec = tracks_get_audio_analysis(track_id)
@test json.meta.detailed_status == "OK"

t = Float64[]
for sec in json.sections
    push!(t, sec.start)
    push!(t, sec.start + sec.duration)
end
t *= 10 /last(t)
tempo = Float64[]
for sec in json.sections
    push!(tempo, sec.tempo)
    push!(tempo, sec.tempo)
end
confidence = Float64[]
for sec in json.sections
    push!(confidence, sec.confidence)
    push!(confidence, sec.confidence)
end

p = lineplot(t, tempo, xlabel="Time", ylabel="Beats per minute ", width = 56, height = 5)
println(stdout, p)
p = lineplot(t, confidence, xlabel="Time", ylabel="Beat confidence ", width = 56, height = 5)
push!(p.decorations, :b => "1    2    3     4     5    6    7     8    9")
println(stdout, p)
plot_audio_sections(stdout, json.sections)
plot_audio_segments(stdout, json.segments)


nsegs = length(json.segments)
segno(t_rel) = Int(max(1, ceil(t_rel * nsegs)))
t_rel(ix) = (ix - 1) / (nsampx - 1)

nsampx = 72 # character width
nsampy = 12 # Pitches

mat = repeat(collect(0:10)', outer=(11, 1))
heatmap(mat, zlabel="z")

mat = repeat(collect(1:nsampx)', outer=(nsampy, 1))
heatmap(mat, zlabel="z", width = nsampx, height = nsampy)
pl = heatmap(mat, width = nsampx, height = nsampy, colorbar = false)
mat = repeat(collect(1:nsampx)', outer=(nsampy, 1))
for i = 1:12
    for j = 0:5
        mat[i, min(j * 12 + i, nsampx)] = 12
    end
end
pl = heatmap(mat, width = nsampx, height = nsampy, colorbar = false, xfact = 10/71)
push!(pl.decorations, :b => "1      2      3      4      5     6     7      8      9")
println(stdout, pl)


mat = repeat(1.0 * collect(1:nsampx)', outer=(nsampy, 1))
for ix = 1:nsampx
    t = t_rel(ix)
    sx = segno(t)
    pitches = json.segments[sx].pitches
    mat[:, ix] = pitches
end
pl = heatmap(mat, width = nsampx, height = nsampy, colorbar = false, xfact = 10 / (nsampx - 1))
push!(pl.decorations, :b => "1    2    3     4     5    6    7     8    9")
println(stdout, pl)

#     6            5            4            3            2            1
p = ["C ", "D♭", "D ", "E♭", "E ", "F ", "G♭", "G ", "A♭", "A ", "B♭", "H "]
push!(pl.labels_left, 6 => p[1]) # Bottom label
push!(pl.labels_left, 5 => p[3])
push!(pl.labels_left, 4 => p[5])
push!(pl.labels_left, 3 => p[7])
push!(pl.labels_left, 2 => p[9])
push!(pl.labels_left, 1 => p[11]) # Top label

pl
plot_audio_segments(stdout, json.segments)


st = get_player_state(stdout)
track_id = SpTrackId(st.item.uri)
json, waitsec = tracks_get_audio_analysis(track_id);
segments = json.segments;


ns = length(segments)
# Plot graphics width
nx = 72 * 4
# Pitches = length(segments.pitches) and graphics height
np = 12
# Map funcs between graphics, time and segment no. 
t_rel(ix) = (ix - 1) / nx
# Define by lookup in increasing dimensionless time
dur_s = segments[ns].start + segments[ns].duration
segment_starts_rel = [seg.start / dur_s for seg in segments]
function segment_no(tr)
    i = findfirst(>=(tr), segment_starts_rel)
    if isnothing(i)
        ns
    else
        i
    end
end


mat = repeat((1 / np ) * collect(1:nx)', outer=(np, 1))
for ix = 1:nx
    is = segment_no(t_rel(ix))
    print("(", ix, " ", is, ") ")
    mat[:, ix] = segments[is].pitches
end




@test stretch_string_to_length("123", 5) == "1 2 3"
stretch_string_to_length("123", 5)