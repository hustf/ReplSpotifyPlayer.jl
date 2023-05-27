# We define a custom REPL-mode in order to avoid pressing Return
# after every keypress. `read(stdin, 1)` just won't do.
#
# We make a new REPL interface mode for this,
# based off the shell prompt (shell mode would
# be entered by pressing ; at the julia> prompt).
#
# Method strongly inspired by
# https://erik-engheim.medium.com/exploring-julia-repl-internals-6b19667a7a62

# Each menu selection calls a function in 'repl_player.jl'.
# Options are passed down through an IOContext.


"""
This function wraps mini mode commands in this.
This function is called if a keypress corresponds to
the definitions in define_single_keystrokes!
"""
function wrap_command(state::REPL.LineEdit.MIState, repl::LineEditREPL, char::AbstractString)
    # This buffer contain other characters typed so far.
    iobuffer = LineEdit.buffer(state)
    # write character typed into line buffer
    LineEdit.edit_insert(iobuffer, char)
    # Print recognized character in color.
    # Replace arrow control codes with unicode.
    if char == "\e[A"
        printstyled(stdout, '↑' , color = :green)
    elseif char == "\e[B"
        printstyled(stdout, '↓' , color = :green)
    elseif char == "\e[C"
        printstyled(stdout, '→' , color = :green)
    elseif char == "\e[D"
        printstyled(stdout, '←' , color = :green)
    else
        printstyled(stdout, char, color = :green)
    end
    act_on_keystroke(char)
end

"An io context is made based on this at each recognized keystroke"
const IO_DICT = Dict(:context_color => :green, :print_ids => false, :silent => false)

"Remember last selection for single keystroke access later"
const PREVIOUS_FEATURE_SELECTION = Ref{Union{Symbol, Nothing}}(nothing)

"Call the function selected by keystroke with an IOContext. Then print current state."
function act_on_keystroke(char)
    # Most calls from here on
    # will print something.
    ioc = IOContext(stdout, IO_DICT...)
    color_set(ioc)
    c = char[1]
    print_and_delete(color_set(ioc, :yellow), " Calling..")
    color_set(ioc)
    if ! Spotify.credentials_still_valid()
        println(ioc, "DEBUG: We believe you will have problems, credentials are expired.")
    end
    if c == 'b' || char == "\e[D"
        player_skip_to_previous()
        # If we call player_get_current_track() right
        # after changing tracks, we might get the
        # previous state.
        # Ref. https://github.com/spotify/web-api/issues/821#issuecomment-381423071
        sleep(1)
    elseif c == 'f' || char == "\e[C"
        player_skip_to_next()
        # Ref. https://github.com/spotify/web-api/issues/821#issuecomment-381423071
        sleep(1)
    elseif c == 'p'
        pause_unpause_print(ioc)
    elseif c == 'c'
        io = color_set(ioc, :light_blue)
        print(io, "  ")
        current_context_print(io)
        color_set(ioc)
    elseif char == "\e[3~"  || char == "\e\b"
        io = color_set(stdout, :red)
        print(io, "  ")
        delete_current_playing_from_owned_print(io)
        color_set(ioc)
    elseif c == 'a'
        io = color_set(ioc, 176)
        println(io)
        current_audio_features_print(ioc)
        color_set(ioc)
    elseif '0' <= c <= '9'
        print(ioc, " ")
        seek_in_track_print(ioc, Meta.parse(string(c)))
    elseif c == 'i'
        ioc = toggle_ids_print(ioc)
    elseif c == '?'
        io = color_set(ioc, :normal)
        help_seek_syntax_print(io)
        color_set(ioc)
    elseif c == 'm'
        io = color_set(ioc, :yellow)
        current_artist_and_tracks_in_data_print(io)
        color_set(ioc)
    elseif c == 't'
        io = color_set(ioc, :normal)
        PREVIOUS_FEATURE_SELECTION[]  = sort_playlist_other_select_print(io; pre_selection = :abnormality)
        color_set(ioc)
    elseif c == 'o'
        io = color_set(ioc, :normal)
        PREVIOUS_FEATURE_SELECTION[] = sort_playlist_other_select_print(io)
        color_set(ioc)
    elseif c == 'h'
        io = color_set(ioc, :green)
        housekeeping_print(io)
        color_set(ioc)
    elseif char == "\e[A" # up arrow
        io = color_set(ioc, :normal)
        PREVIOUS_FEATURE_SELECTION[] = sort_playlist_other_select_print(io; pre_selection = PREVIOUS_FEATURE_SELECTION[])
        color_set(ioc)
    elseif c == 'g'
        io = color_set(ioc, :green)
        current_genres_print(io)
        color_set(ioc)
    end
    # After the command, a line with the current playing:
    print(ioc, "  ")
    current_playing_print(ioc)
    color_set(ioc)
    nothing
end

"Respond to pressing enter when in mini player mode"
on_non_empty_enter(s) = print_menu_and_current_playing()


function print_menu_and_current_playing()
    print_menu()
    ioc = IOContext(stdout, IO_DICT...)
    color_set(ioc)
    print(ioc, "  ")
    current_playing_print(ioc)
    nothing
end

"""
To enter this new repl mode 'minimode', user must be at start of line, just as with the other
interface modes.
Printed output is what you get when pressing 'enter' afterwards.
"""
function triggermini(state::LineEdit.MIState, repl::LineEditREPL, char::AbstractString)
    iobuffer = LineEdit.buffer(state)
    if position(iobuffer) == 0
        if ! Spotify.credentials_still_valid()
            apply_and_wait_for_implicit_grant(;scopes = Spotify.spotcred().ig_scopes)
        end
        if Spotify.credentials_still_valid()
            LineEdit.transition(state, PLAYERprompt[]) do
                # Type of LineEdit.PromptState
                prompt_state = LineEdit.state(state, PLAYERprompt[])
                prompt_state.input_buffer = copy(iobuffer)
                println(stdout)
                print_menu_and_current_playing()
            end
        end
    else
        LineEdit.edit_insert(state, char)
    end
end

function exit_mini_to_julia_prompt(state::LineEdit.MIState, repl::LineEditREPL, char::AbstractString)
    # Other mode changes require start of line. We want immediate exit.
    PREVIOUS_FEATURE_SELECTION[] = nothing
    iobuffer = LineEdit.buffer(state)
    LineEdit.transition(state, repl.interface.modes[1]) do
        # Type of LineEdit.PromptState
        prompt_state = LineEdit.state(state, PLAYERprompt[])
        prompt_state.input_buffer = copy(iobuffer)
    end
end

"We assume there are six default prompt modes, like in Julia 1.0-1.8 at least."
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
            freshprompt.keymap_dict['e'] = exit_mini_to_julia_prompt  # 'e' key exits
            freshprompt.keymap_dict['\b'] = exit_mini_to_julia_prompt # backspace exits. TODO test on Mac.
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

function define_single_keystrokes!(special_prompt)
    # Single keystroke commands. Sorry for any ugliness.
    # Take care to check; some keys won't work.
    let
        d = special_prompt.keymap_dict
        d['b'] = wrap_command
        d['f'] = wrap_command
        d['p'] = wrap_command
        d['c'] = wrap_command
        d['a'] = wrap_command
        d['i'] = wrap_command
        d['?'] = wrap_command
        d['m'] = wrap_command
        d['t'] = wrap_command
        d['h'] = wrap_command
        d['o'] = wrap_command
        d['g'] = wrap_command
        d['0'] = wrap_command
        d['1'] = wrap_command
        d['2'] = wrap_command
        d['3'] = wrap_command
        d['4'] = wrap_command
        d['5'] = wrap_command
        d['6'] = wrap_command
        d['7'] = wrap_command
        d['8'] = wrap_command
        d['9'] = wrap_command
        # The structure is nested for special keystrokes.
        special_dict = special_prompt.keymap_dict['\e']
        very_special_dict = special_dict['[']
        very_special_dict['A'] = wrap_command # up arrow
        very_special_dict['C'] = wrap_command # right arrow
        very_special_dict['D'] = wrap_command # left arrow
        deletedict = very_special_dict['3']
        deletedict['~'] =  wrap_command
    end
end


function print_menu()
    menu = """
    ¨e : exit.     ¨f(¨→) : forward.     ¨b(¨←) : back.     ¨p: pause, play.     ¨0-9:  seek.
    ¨del(¨fn + ¨⌫  ) : delete track from playlist. ¨c : context. ¨m : musician. ¨g : genres.
    ¨i : toggle ids.       ¨a : audio features.       ¨h : housekeeping.      ¨? : syntax.
    ~Sort then select § ¨t : by typicality.  ¨o : other features.  ¨↑ : previous selection.
    """
    print(stdout, characters_to_ansi_escape_sequence(menu))
end