"""
    metronome(bpm::Real=72, bpb::Int=4; bars = 5)

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
"""
function metronome(bpm::Real=72, bpb::Int=4; bars = 10)
    pause = 60 / bpm
    counter = 0
    bar = 0
    while bar < bars
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
end


"""
    playtracks(v)

An example of making a useful one-argument function for pipelining syntax. 

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