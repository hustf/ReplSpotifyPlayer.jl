# This file contains functions used internally by repl_player.jl, the user facing functions.
# These are second-tier, not called directly by keypresses, rather indirect.
# They wrap hierarcical functionality in Spotify/player
# They are based on Spotify.jl/example/
"""
    get_player_state_print_feedback()
    --> state object
Note: state contains the current track,
but it takes up to a second to update after changes.
"""
function get_player_state_print_feedback()
    st = player_get_state()[1]
    if isempty(st)
        print(stdout, """Can't get Spotify state.
        - Is $(Spotify.get_user_name()) running Spotify on any device? 
        - Has $(Spotify.get_user_name()) started playing any track?
        """)
    end
    st
end