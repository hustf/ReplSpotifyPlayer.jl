using UnicodePlots
data = [0.0, 0.281, 0.51, 0.748, 1.0]
p = histogram(data, nbins=10, vertical = true, height=10, color =:red, name="A", width = 80, stats=false)
vline!(p, 0.5, color=:green)