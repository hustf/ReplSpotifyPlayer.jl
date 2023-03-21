# This is included as a part of 'mini_player.jl'
#
# We define a custom REPL-mode in order to avoid pressing Return
# after every keypress. `read(stdin, 1)` just won't do.
#
# We'll make a new REPL interface mode for this,
# based off the shell prompt (shell mode would
# be entered by pressing ; at the julia> prompt).
#
#
# Method based on 
# https://erik-engheim.medium.com/exploring-julia-repl-internals-6b19667a7a62

function print_menu()
    l = text_colors[:light_black]
    b = text_colors[:bold]
    n = text_colors[:normal]
    menu = """
       ¨e : exit.    ¨f(¨→) : forward.  ¨b(¨←) : back.  ¨p: pause, play.  ¨0-9:  seek.
       ¨a : analysis.   ¨l : playlist.      ¨del(¨fn + ¨⌫  ) : delete from playlist.
    """
    menu = replace(menu, "¨" => b , ":" =>  "$n$l:", "." => ".$n", " or" => "$n$l or$n", "+" => "$n+", "(" => "$n(", ")" => "$n)")
    print(stdout, menu)
    print(stdout, n)
end

# How we will respond to pressing enter when in mini player mode
function on_non_empty_enter(s)
    print_menu()
    print(stdout, text_colors[:green])
    println(stdout, "  " * current_playing_string())
    print(stdout, text_colors[:normal])
    nothing
end

# To enter this new repl mode 'minimode', user must be at start of line, just as with the other
# interface modes.
function triggermini(state::LineEdit.MIState, repl::LineEditREPL, char::AbstractString)
    iobuffer = LineEdit.buffer(state)
    if position(iobuffer) == 0
        if Spotify.credentials_still_valid()
            LineEdit.transition(state, PLAYERprompt[]) do
                # Type of LineEdit.PromptState
                prompt_state = LineEdit.state(state, PLAYERprompt[])
                prompt_state.input_buffer = copy(iobuffer)
                println(stdout)
                print_menu()
                s = current_playing_string()
                printstyled(stdout, "\n  " * s * '\n', color = :green)
            end
        end
    else
        LineEdit.edit_insert(state, char)
    end
end

function exit_mini_to_julia_prompt(state::LineEdit.MIState, repl::LineEditREPL, char::AbstractString)
    # Other mode changes require start of line. We want immediate exit.
    iobuffer = LineEdit.buffer(state)
    LineEdit.transition(state, repl.interface.modes[1]) do
        # Type of LineEdit.PromptState
        prompt_state = LineEdit.state(state, PLAYERprompt[])
        prompt_state.input_buffer = copy(iobuffer)
    end
end

# We assume there are six default prompt modes, like in Julia 1.0-1.8 at least.
function add_seventh_prompt_mode(repl::LineEditREPL)
    freshprompt = REPL.Prompt(" ◍ >")
    # Copy every property of the shell mode to freshprompt
    shellprompt = repl.interface.modes[2]
    for name in fieldnames(REPL.Prompt)
        if name == :prompt
        elseif name == :prompt_prefix
            setfield!(freshprompt, name, text_colors[:green])
        elseif name == :on_done
            setfield!(freshprompt, name, REPL.respond(on_non_empty_enter, repl, freshprompt; pass_empty = true))
        elseif name == :keymap_dict
             # Note: We don't want to copy the keymap reference from shell
            # mode, because we're going to tweak some keys later,
            # and don't want to affect other modes.
            # The default keymap is fine, though it misses a mode exit.
            # We add this important one here, at once.
            # Other keys are added after this.
            freshprompt.keymap_dict['e'] = exit_mini_to_julia_prompt
        else
            setfield!(freshprompt, name, getfield(shellprompt, name))
        end
    end
    if length(repl.interface.modes) == 6
        # Add freshprompt as the seventh
        push!(repl.interface.modes, freshprompt)
    else
        # This has been run twice.
        # Replace old with new.
        repl.interface.modes[7] = freshprompt
    end

    # Modify juliamode to trigger mode transition to minimode 
    # when a ':' is written at the beginning of a line
    juliamode = repl.interface.modes[1]
    juliamode.keymap_dict[':'] = triggermini
    freshprompt
end


# We're going to wrap mini mode commands in this.
# That means a shortcut is defined in keymap_dict, but
# what it does is specificed here.
function wrap_command(state::REPL.LineEdit.MIState, repl::LineEditREPL, char::AbstractString)
    # This buffer contain other characters typed so far.
    iobuffer = LineEdit.buffer(state)
    # write character typed into line buffer
    LineEdit.edit_insert(iobuffer, char)
    # change color of recognized character.
    printstyled(stdout, char, color = :green)
    c = char[1]
    if c == 'b' || char == "\e[D"
        player_skip_to_previous()
        s = ""
        # If we call player_get_current_track() right
        # after changing tracks, we might get the
        # previous state.
        # Ref. https://github.com/spotify/web-api/issues/821#issuecomment-381423071
        sleep(1)
    elseif c == 'f' || char == "\e[C"
        player_skip_to_next()
        s = ""
        # Ref. https://github.com/spotify/web-api/issues/821#issuecomment-381423071
        sleep(1)
    elseif c == 'p'
        s = pause_unpause()
    elseif c == 'l'
        s = "  " * current_playlist_context_string() * "\n"
    elseif char == "\e[3~"  || char == "\e\b"
        # This call prints multi-line output
        s = delete_current_playing_from_owned_context()
    elseif c == 'a'
        s = "\n" * current_audio_features() * "\n"
    elseif '0' <= c <= '9'
        s = " " * seek_in_track(Meta.parse(string(c))) * "\n"
    end
    if s !== ""
        printstyled(stdout, s, color = :light_blue)
    end
    scur = "  " * current_playing_string() * "\n"
    printstyled(stdout, scur, color = :green)
end

function define_single_keystrokes!(special_prompt)
    # Single keystroke commands. Sorry for any ugliness.
    let
        special_prompt.keymap_dict['b'] = wrap_command
        special_prompt.keymap_dict['f'] = wrap_command
        special_prompt.keymap_dict['p'] = wrap_command
        special_prompt.keymap_dict['l'] = wrap_command
        special_prompt.keymap_dict['a'] = wrap_command
        special_prompt.keymap_dict['0'] = wrap_command
        special_prompt.keymap_dict['1'] = wrap_command
        special_prompt.keymap_dict['2'] = wrap_command
        special_prompt.keymap_dict['3'] = wrap_command
        special_prompt.keymap_dict['4'] = wrap_command
        special_prompt.keymap_dict['5'] = wrap_command
        special_prompt.keymap_dict['6'] = wrap_command
        special_prompt.keymap_dict['7'] = wrap_command
        special_prompt.keymap_dict['8'] = wrap_command
        special_prompt.keymap_dict['9'] = wrap_command
        # The structure is nested for special keystrokes.
        special_dict = special_prompt.keymap_dict['\e']
        very_special_dict = special_dict['[']
        very_special_dict['C'] = wrap_command
        very_special_dict['D'] = wrap_command
        deletedict = very_special_dict['3']
        deletedict['~'] =  wrap_command
    end
end