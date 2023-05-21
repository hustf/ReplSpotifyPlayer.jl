using REPL
"print_and_delete(ioc, s; delay_s = 0.2)"
function test_print_and_delete(ioc, s; delay_s = 0.2)
    n = length(s)
    print(ioc, s)
    sleep(delay_s)
    out = REPL.Terminals.cmove_left(REPL.Terminals.TTYTerminal("", stdin, stdout, stderr), n)
    print(ioc, repeat(' ', n))
    REPL.Terminals.cmove_left(REPL.Terminals.TTYTerminal("", stdin, stdout, stderr), n)
    out
end


begin
    print(stdout, "Starting")
    test_print_and_delete(stdout, "HI there!")
    print(stdout, "Ending")
end

