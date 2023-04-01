# This file contains functions used internally by repl_player.jl (the user-facing functions).
# These are second-tier, not called directly by keypresses, rather indirect.
# They do not fit neatly in player_interface_functions or playlist_interface_functions.
# They are based on Spotify.jl/example/

"track_album_artists_print(ioc, item::JSON3.Object)"
function track_album_artists_print(ioc, item::JSON3.Object)
    print(ioc, item.name, " \\ ", item.album.name)
    ars = item.artists
    vs = [ar.name for ar in ars]
    print(ioc, " \\ ", join(vs, " & "))
    if get(ioc, :print_ids, false)
        track_id = SpTrackId(item.id)
        print(ioc, "  ")
        show(ioc, MIME("text/plain"), track_id)
        color_set(ioc)
    end
    nothing
end


"""
    track_also_in_playlists_print(ioc, track_id, otherthan::JSON3.Object) -> Bool
"""
function track_also_in_playlists_print(ioc, track_id, otherthan::JSON3.Object)
    if ! isempty(otherthan)
        if otherthan.type == "collection" || otherthan.type == "album"
            otherthan_playlistid =  SpPlaylistId("1234567890123456789012")
        elseif otherthan.type == "playlist"
            otherthan_playlistid =  SpPlaylistId(otherthan.uri)
        else
            @show otherthan
            throw("didn't think of that")
        end
    else
        println("CHECL")
        otherthan_playlistid =  SpPlaylistId("1234567890123456789012")
    end
    plls = map(t-> t.id, playlistrefs_containing_track(track_id))
    other_playlists = filter(l -> l !== otherthan_playlistid, plls)
    if ! isempty(other_playlists) && isempty(otherthan)
        println(ioc, " Current track is used in:")
    end
    for l in other_playlists
        print(ioc, "       ")
        playlist_details_print(ioc, l)
        color_set(ioc)
        println(ioc)
    end
    length(other_playlists) > 0 ? true : false
end
