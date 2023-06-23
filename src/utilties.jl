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
    @assert ! isempty(v)
    player_resume_playback(;uris = SpTrackId.(v))
    println(length(v))
end

"""
    euclidean_normalized_sample_deviation(sets::Vector{Vector{T}}, single_sample_values::Vector{T}) where T
    ---> Float64

This method shows how well a multi-dimensional sample would fit in 'sets'. 

Note that actually adding the sample to the set would change the mean and deviation. This method can be
used to determine which sets a sample would fit best to.
"""
function euclidean_normalized_sample_deviation(sets::Vector{Vector{T}}, single_sample_values::Vector{T}) where T
    param_deviation_norm = normalized_sample_deviation(sets, single_sample_values)
    sqrt(sum(param_deviation_norm.^2))
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

"""
    normalized_sample_deviation(sets::Vector{Vector{T}}, single_sample_values::Vector{T}) where T
    --> Vector{Float64}

Called from `euclidean_normalized_sample_deviation` and `deviation`
"""
function normalized_sample_deviation(sets::Vector{Vector{T}}, single_sample_values::Vector{T}) where T
    @assert length(sets) == length(single_sample_values)
    param_deviation_norm = Float64[]
    for (vec, x) in zip(sets, single_sample_values)
        Δ_per_σ = normalized_sample_deviation(vec, x)
        push!(param_deviation_norm, Δ_per_σ)
    end
    param_deviation_norm
end

"called normalized_sample_deviation"
function normalized_sample_deviation(vec, x)
    μ = mean(vec)
    σ = std(vec, corrected = true)
    Δ = x - μ
    if σ == 0
        @assert Δ == 0
        0.0
    else
        Δ / σ
    end
end