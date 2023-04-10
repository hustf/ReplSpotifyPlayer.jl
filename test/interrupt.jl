using REPL
function metronome(bpm::Real=72, bpb::Int=4; bars = 10, stop_channel = Channel(1))
    println("Starting met")
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

function mother()
    println("Press enter to stop counting")
    bpm = 60
    bpb = 5
    bars = 10

    metfunc(stop_channel) = metronome(bpm, bpb; bars, stop_channel)
    stop_channel = Channel(metfunc, 1)
    println("Mother keeps going")
    sleep(2)
    println("Readline return now (is this blocking?):")
    readline(stdin)
    println("Now sending a put!")
    put!(stop_channel, 1)
    nothing
end

