using UnicodePlots
data = [0.0, 0.281, 0.51, 0.748, 1.0]
p = histogram(data, nbins=10, vertical = true, height=10, color =:red, name="A", width = 80, stats=false)
vline!(p, 0.5, color=:green)
track_value = 0.3
vline!(p, [track_value], [track_value, 0.001], color=:yellow)
p = histogram(data, nbins=10, vertical = true, height=10, color =:red, name="A", width = 80, stats=false)
canvas = p.graphics
using UnicodePlots: lines!, points!, pixel!
lines!(canvas, 0., 0., 1., 1.; color=:cyan)

data_for_bins = rand(10000) .* 3 .- 1 
p = histogram(data_for_bins, nbins=10, vertical = true, height=10, color =:red, name="A", width = 80, stats=true)
canvas = p.graphics
mi = minimum(data_for_bins)
ma = maximum(data_for_bins)
wi = UnicodePlots.ncols(canvas)
track_value = 0.0
rel_track_value = (track_value - mi) / (ma - mi)
c = Int(ceil(wi * rel_track_value))
xlab = "|" * repeat(' ', c - 2 ) * "↑" * repeat(' ', wi - c - 1) * "|"
@assert length(xlab) == wi
p.xlabel[] = xlab
#rel_mi = 0.0
#rel_ma = 1.0
#points!(canvas, [rel_mi, rel_ma, rel_track_value], [0.0, 0.0, 0.0]; color=:yellow)