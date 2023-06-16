# This file contains functions used indirectly by repl_player.jl, the user facing functions.
# Reading from keyboard while in the specially defined replmode.

function input_number_in_range_and_print(ioc, rng)
    io = color_set(ioc, :176)
    print(io, "Type number ∈ ")
    print(color_set(ioc), "$rng")
    print(color_set(io), " to play! Press ")
    print(color_set(ioc), " ⏎ ")
    print(color_set(io), " to do nothing: ")
    inpno = read_number_from_keyboard(rng)
    println(io)
    color_set(ioc)
    inpno
end

"""
    read_number_from_keyboard(rng)
    ---> Union{Nothing, Int64}

We can't use readline(stdin) while in our special replmode - that would block.

If this is called from the normal REPL mode, it will be necessary
to press enter after the number. Only the characters necessary for
a number in `rng` will be read, and the remaining characters in buffer
are processed by REPL as usual.
"""
function read_number_from_keyboard(rng)
    remaining_digits = length(string(maximum(rng)))
    buf = ""
    print(stdout, repeat('_', remaining_digits))
    REPL.Terminals.cmove_left(REPL.Terminals.TTYTerminal("", stdin, stdout, stderr), remaining_digits)

    while remaining_digits >= minimum(rng)
        remaining_digits -= 1
        c = Char(first(read(stdin, 1)))
        print(stdout, c)
        c < '0' && break
        c > '9' && break
        buf *= c
    end
    inpno = tryparse(Int64, buf)
    isnothing(inpno) && return nothing
    inpno ∉ rng && return nothing
    inpno
end

"""
    read_single_char_from_keyboard(string_allowed_characters, default::Char)
    ---> Union{Nothing, Char}

We can't use readline(stdin) while in our special replmode - that would block.

If this is called from the normal REPL mode, it will be necessary
to press enter after the character.

If a character not in string_allowed_characters is pressed, returns default.

Keys like arrow up consists of TWO characters, so this function is not suitable for that.
"""
function read_single_char_from_keyboard(string_allowed_characters, default::Char)
    c = Char(first(read(stdin, 1)))
    print(stdout, c)
    if c ∈ string_allowed_characters
        c
    else
        default
    end
end

"""
    read_single_char_or_control_from_keyboard(string_allowed_characters, default::Char)
    ---> Union{Nothing, Char}

We can't use readline(stdin) while in our special replmode - that would block.

If this is called from the normal REPL mode, it will be necessary
to press enter after the character.

If a character not in string_allowed_characters (or in arrow right / left) is pressed, returns default.
"""
function read_single_char_or_control_from_keyboard(string_allowed_characters, default::Char)
    c = Char(first(read(stdin, 1)))
    # Some control keys take more characters.
    if c == '\e'
        # TODO test on apple. We would probably want to use "\e\b", which may crash.
        d = String(collect(read(stdin, 2)))
        if d == "[3" || d == "[2"
            e = Char(first(read(stdin, 1)))
            char = c * d * e
        else
            char = c * d
        end
        if char == "\e[C" 
            print(stdout, char)
            c = '→' 
        elseif char == "\e[D"
            print(stdout, char)
            c = '←'
        elseif char == "\e[3~"
            # With 'delete', it is easier to rewrite the edited line in the calling function.
            # It is easier to rewrite the edited line in the calling function.
            c = '\x7f' # ascii delete
        elseif char == "\e[2~"
            # The insert key: We won't change mode, but insert a space. Return the unicode symbol for ins.
            c = '⎀'
        else
            c = '\r'
            print(stdout, c)
        end
    elseif c == '\b'  # TODO Apple equiv.
        # With backspace, it is easier to rewrite the edited line in the calling function.
    else
        print(stdout, c)
    end
    if c ∈ string_allowed_characters || c ∈ "→←" || c == '\b' || c == '\x7f' || c == '⎀'
        c
    else
        default
    end
end


function read_line_with_predefined_text_print(ioc, suggestion)
    print(color_set(ioc, :light_black), suggestion, '\r')
    print(ioc, text_colors[:normal])
    allowed_characters = " abcdefghijklmnopqrstuvwxyz{|}~ ¡¢£¤¥¦§¨©ª«¬­®¯°±²³´µ¶·¸¹º»¼½¾¿ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖ×ØÙÚÛÜÝÞßàáâãäåæ"
    allowed_characters *= uppercase(allowed_characters)
    allowed_characters *= "0123456789.,"
    allowed_characters *= "-()&!ö'ıПеснкаипрочтлЧуьвАф/é\":?èïø[]Оіцюхêホワイル・マギタージェントリウィプス;НдгяüДйКыМЯ강남스타일レРб̇ḉЗмшЦЬУ_жС+`"
    user_response = Char.(codeunits(suggestion))
    i = 0
    while true
        c = read_single_char_or_control_from_keyboard(allowed_characters, '\r')
        if c == '\r'
            break
        end
        if c == '→'
            i += 1
            if i > length(user_response)
                push!(user_response, ' ')
            end
        elseif c == '←' && i > 1
            i -= 1
        elseif c == '\b' && i > 0
            # Backspace (delete to left)
            popat!(user_response, i)
            if i > 1 
                i -= 1
            end
            clear_line(REPL.Terminals.TTYTerminal("", stdin, stdout, stderr))
            print(color_set(ioc, :normal), String(user_response), '\r')
            # Now move i to right, as we were..
            print(ioc, repeat("\e[C", i ))
        elseif c == '\x7f' && i < length(user_response)
            # Backspace (delete to right)
            popat!(user_response, i + 1)
            clear_line(REPL.Terminals.TTYTerminal("", stdin, stdout, stderr))
            print(color_set(ioc, :normal), String(user_response), '\r')
            # Now move i to right, as we were..
            print(ioc, repeat("\e[C", i ))
        elseif c == '⎀' && i < length(user_response)
            # Insert a space here (we don't have insert mode)
            insert!(user_response, i, ' ')
            clear_line(REPL.Terminals.TTYTerminal("", stdin, stdout, stderr))
            print(color_set(ioc, :normal), String(user_response), '\r')
            # Now move i to right, as we were..
            print(ioc, repeat("\e[C", i ))
        elseif c ∈ allowed_characters
            i += 1
            if i < 1
                i = 1
            elseif i <= length(user_response)
                user_response[i] = c
            else
                push!(user_response, c)
            end
        end
    end
    color_set(ioc)
    strip(String(user_response))
end
