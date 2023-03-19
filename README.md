# ReplSpotifyPlayer
Built on [Spotify.jl](https://github.com/kwehmeyer/Spotify.jl)'s REPL player. Try the master version out first!

This package has a similar REPL player-mode, which also maintains a local tracks dataframe with helpful info:

- In which of your playlists does this track appear?
- What are the musical features of this track?
- Statistics of the music in this playlist?

The local dataframe is stored in `~home/.repl_player_tracks.csv`.
It is created, loaded, maintained behind the scenes.

# Example
```julia-repl
(@v1.8) pkg> registry add https://github.com/hustf/M8

(@v1.8) pkg> add ReplSpotifyPlayer

julia> using ReplSpotifyPlayer

Now press ; to enter player mode!
```