using ReplSpotifyPlayer
using Test

@testset "trackrefs_dataframe" begin
    @warn "The tests for this package are intended for careful stepping through, considering your own online playlists."
    include("test_tracks_dataframe.jl")
end
