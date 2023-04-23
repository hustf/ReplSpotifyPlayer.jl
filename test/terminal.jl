using REPL
function print_and_delete(ioc, s)
    n = length(s)
    print(ioc, s)
    sleep(0.2)
    REPL.Terminals.cmove_left(REPL.Terminals.TTYTerminal("", stdin, stdout, stderr), n)
    print(ioc, repeat(' ', n))
    REPL.Terminals.cmove_left(REPL.Terminals.TTYTerminal("", stdin, stdout, stderr), n)
end


begin
    print(stdout, "Starting")
    print_and_delete(stdout, "HI there!")
    print(stdout, "Ending")
end

