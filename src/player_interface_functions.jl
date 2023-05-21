# This file contains functions used internally by repl_player.jl, the user facing functions.
# These are second-tier, not called directly by keypresses, rather indirect.
# They wrap hierarcical functionality in Spotify/player
# They are based on Spotify.jl/example/
"""
    get_player_state(ioc)\\
    ---> state object
Note: state contains the current track,
but it takes up to a second to update after changes.

If the state isn't useable, prints feedback to stdout directly.
"""
function get_player_state(ioc)
    st = player_get_state(; market = "")[1]
    if isempty(st)
        print(ioc, """Can't get Spotify state.
        - Is $(get_user_name()) running Spotify on any device?
        - Has $(get_user_name()) started playing any track?
        """)
    end
    st
end
