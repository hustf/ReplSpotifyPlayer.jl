"""
    metronome(bpm::Real=72, bpb::Int=4; bars = 5, interruptchannel = Channel(1))

Sometimes, Spotify's rhytm analysis feels wrong. Check it with the metronome!

We doubt if the song below has three beats per bar ('time signature'), and tempo
107.809 beats per minute. Let's check!

# Example 
```
julia>    e : exit.    f(→) : forward.  b(←) : back.  p: pause, play.  0-9:  seek.
   a : analysis.   l : playlist.      del(fn + ⌫  ) : delete from playlist.
   i : toggle ids. s : search syntax.
  Puppy Toy \\ Knowle West Boy \\ Tricky
 ◍ >a
acousticness     0.175   key               7      
speechiness      0.0653  mode              1
instrumentalness 1.09e-6 time_signature    3
liveness         0.304   tempo             107.809
loudness         -2.401  duration_ms       214507
energy           0.844
danceability     0.362
valence          0.576
  Puppy Toy \\ Knowle West Boy \\ Tricky

julia> metronome(107.809, 3)
         1 2 3|10/10|
```

# Advanced use

The Repl mode runs this asyncronously, and can stop it before 
it's finished by putting something on `stop_channel`.
"""
function metronome(bpm::Real=72, bpb::Int=4; bars = 10, stop_channel = Channel(1))
    pause = 60 / bpm
    counter = 0
    bar = 0
    while bar < bars && ! isready(stop_channel)
        counter += 1
        bar = Int(floor(counter / bpb))
        counter % bpb == 1 && print(repeat(' ', bar))
        if counter % bpb != 0
            print(counter % bpb, " ")
            sleep(pause)
        else
            print(bpb, "|", bar, "/", bars, "|")
            sleep(pause)
            if bar  < bars
                REPL.Terminals.clear_line(REPL.Terminals.TTYTerminal("", stdin, stdout, stderr))
            end
        end
    end
    # Cleanup
    isready(stop_channel) && take!(interruptchannel)
    nothing
end


"""
    playtracks(v)

An example of a one-argument function, useful for pipelining syntax like in the example:

# Example 
```
julia> filter(:trackname => n -> contains(uppercase(n), " LOVE "), TDF[])[!, :trackid] |> playtracks
12
```
"""
function playtracks(v)
    player_resume_playback(;uris = v)
    println(length(v))
end


"""
    euclidean_normalized_sample_deviation(sets::Vector{Vector{T}}, single_sample_values::Vector{T}) where T
    ---> Float64

This method shows how well a multi-dimensional sample would fit in 'sets'. If the sample is 
already part of the set, use the method below.

Note that actually adding the sample to the set would change the mean and deviation. This method can be
used to determine which sets a sample would fit best to.
"""
function euclidean_normalized_sample_deviation(sets::Vector{Vector{T}}, single_sample_values::Vector{T}) where T
    @assert length(sets) == length(single_sample_values)
    param_distances = Float64[]
    for (vec, x) in zip(sets, single_sample_values)
        μ = mean(vec)
        σ = std(vec, corrected = true)
        Δ = x - μ
        if σ == 0
            @assert Δ == 0
            push!(param_distances, 0.0)
        else
            Δ_per_σ = Δ / σ
            push!(param_distances, Δ_per_σ)
        end
    end
    sqrt(sum(param_distances.^2))
end

""""
    euclidean_normalized_sample_deviation(sets::Vector{Vector{Float64}}, sample_no::Int64) 
    ---> Float64

This could be called the coefficient of variation for multi-dimensional samples.

# Example

Here, 'sets' is two-dimensional. The mean μ = [2, 20].
```
julia> sets = [
       [1, 2, 3],
       [10, 20, 30]]
2-element Vector{Vector{Int64}}:
 [1, 2, 3]
 [10, 20, 30]

julia> euclidean_normalized_sample_deviation(sets, 2)
0.0
```

The return value for sample no. 2 is zero because the sample is precisely the mean, \\
deviation to mean is [0, 0].

```
julia> euclidean_normalized_sample_deviation(sets, 1)
1.4142135623730951
```

The return value for sample no. 1 is √2 because norrmalized devation σₙ = [1, 1].
"""
function euclidean_normalized_sample_deviation(sets::Vector{Vector{T}}, sample_no::Int64) where T
    single_sample_values = map(featuretype-> featuretype[sample_no], sets)
    euclidean_normalized_sample_deviation(sets, single_sample_values)
end