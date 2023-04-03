# ReplSpotifyPlayer
Built on [Spotify.jl](https://github.com/kwehmeyer/Spotify.jl)'s REPL player. Try the master version out first!

This package has an extended REPL player-mode. It helps where Spotify's current player is lacking.

- In which of your playlists does this track appear?
- What are the musical features of this track?
- Is this artist already in your playlists, and which?
- Statistics of the music in this playlist?
- Is the rhythm as judged by Spotify's algorithm? Check with the metronome!

The Tracks DataFrame TDF[] is a global, stored between sessions and updated behind the scenes.

# Example
```julia-repl
(@v1.8) pkg> registry add https://github.com/hustf/M8

(@v1.8) pkg> add ReplSpotifyPlayer

julia> dev Spotify.jl  # Check that you have the 'master' version. 

julia> using ReplSpotifyPlayer

julia> # Press ':'

julia>    e : exit.    f(→) : forward.  b(←) : back.  p: pause, play.  0-9:  seek.
   a : analysis.    l : context.       del(fn + ⌫  ) : delete from playlist.
   i : toggle ids.     s : search syntax.      m : musician         r : rhythm
  Rose \ Hybrid \ Swingrowers
 ◍ >
```
