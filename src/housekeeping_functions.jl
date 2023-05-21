function housekeeping_print(ioc, tracks_data::DataFrame)
    remove_tracks_without_refs_and_print!(ioc,  tracks_data)
    # Step 1
    clones_data = tracks_with_clones_data(tracks_data)
    tracks_data = suggest_and_make_clone_track_reductions_print(ioc, clones_data, tracks_data)
    # Step 2
    print(color_set(ioc, :176), "\nShould we suggest replacing tracks in compilations with clone tracks from artist albums and singles? (y/n) ")
    color_set(ioc)
    user_input = read_single_char_from_keyboard("ynYN", 'n')
    println(ioc)
    if user_input == 'y' || user_input == 'Y'
        compilations_data = filter(:albumtype => ==("compilation"), tracks_data)
        print(ioc, "There are currently $(nrow(compilations_data))")
        println(ioc, " tracks in compilations. Using tracks from albums and singles improves searchability.")
        suggest_and_make_compilation_tracks_to_albums_changes_print(ioc, tracks_data)
    end
    color_set(ioc)
    save_tracks_data(tracks_data)
    nothing
end

"Prune tracks that have been deleted from all owned playlists"
function remove_tracks_without_refs_and_print!(ioc,  tracks_data; silent = false)
    io = color_set(ioc, :normal)
    ! silent && println(io, "Pruning unreferred tracks.")
    color_set(ioc)
    filter!(:playlistref => ! ismissing, tracks_data)
end


"""
    suggest_and_make_clone_track_reductions_print(ioc, clones_data, tracks_data)
    --> tracks_data::DataFrame , as far as possible updated.

Clone reduction may make e.g. finding other tracks by an artist easier.

Clone tracks are compared pairwise. If one is preferable to the other, the
user is prompted for a confirmation.

If confirmed, online playlists that refer the unpreferable clone
will be changed to refer the preferable version. The difference is usually
on which album this track appears. The track recording of both versions are the same,
as identified by the 'ISRC' field.

After all suggestions have been acted on (or not), TDF[] is updated from the online database
and saved to disk.
"""
function suggest_and_make_clone_track_reductions_print(ioc, clones_data, tracks_data)
    n = nrow(clones_data)
    io = color_set(ioc, :light_black)
    println(io, "\nAssessing $n clones in pairs with respect to authentic origin. An album is more authentic than e.g. a generic collection.).\n")
    # user_input is defined outside the loop and replacement function, so that if user replies ('Y' or 'N'),
    # no more questions need be asked.
    user_input = 'n'
    # index u, for the 'current' object
    for u in 1:n
        # look for index v above and below u so that they index clones of each other.
        v = u - 1
         if v < 1 || clones_data[u, :isrc] !== clones_data[v, :isrc]
            v = u + 1
            if v > n || clones_data[u, :isrc] !== clones_data[v, :isrc]
                ioco = color_set(io, :yellow)
                println(ioco, "\nUnexpected: Neither above nor below is a clone with u.")
                println(ioco, "u, v = $u, $v")
                @show  clones_data[u, :trackname] clones_data[v, :trackname]
                color_set(io)
                continue
            end
        end
        cur_row = clones_data[u, :]
        adj_row = clones_data[v, :]
        if prefer_adjacent_clone_over_current(cur_row, adj_row)
            # User can choose 'Y' or 'N', which are valid choices for the rest of the loop. 'y' and 'n' are single choices.
            color_set(io)
            print(io, "$u/$n ")
            user_input = make_single_replacement_with_permission_print(io, user_input, cur_row, adj_row, tracks_data)
            user_input == 'N' && break
        else
            # The current clone is not preferrable over the adjacent. Do nothing.
            ioco = IOContext(io, :print_date => true)
            color_set(ioco)
            println(ioco, "$u/$n No preference found for the latter over the former clones:")
            print(ioco, "    ")
            track_album_artists_print(ioco, cur_row)
            print(ioco, "\n    ")
            track_album_artists_print(ioco, adj_row)
            println(ioco)
        end
    end # for
    latest_tracks_data = tracks_data_update(;forceupdate = true)
    color_set(io)
    println(io, "\nFinished assessing clone pairs with respect to authentic origin.")
    color_set(ioc)
    latest_tracks_data
end

"""
    suggest_and_make_compilation_tracks_to_albums_changes_print(ioc, tracks_data)

This is called after suggest_and_make_clone_track_reductions_print. Hence, we can assume
there are no interesting alternatives to compilation tracks in tracks_data, and
we must look online. We look for alternative one by one, so this is slow.
"""
function suggest_and_make_compilation_tracks_to_albums_changes_print(ioc, tracks_data)
    compilations_data = filter(:albumtype => ==("compilation"), tracks_data)
    io = color_set(ioc, :light_black)
    println(io, "\nLooking for replacements for $(nrow(compilations_data)) traks in compilations.\n")
    # user_input is defined outside the loop and replacement function, so that if user replies ('Y' or 'N'),
    # no more questions need be asked.
    user_input = 'n'
    for (i, track_in_compilation_data) in enumerate(eachrow(compilations_data))
        print(color_set(ioc, :light_black), round(i / nrow(compilations_data), digits = 2), " ")
        color_set(ioc)
        user_input = suggest_and_make_compilation_to_album_change_print(ioc, user_input, track_in_compilation_data, tracks_data)
        user_input == 'N' && break
    end
    color_set(io)
    println(io, "\nFinished suggesting replacements for compilation tracks.")
    latest_tracks_data = tracks_data_update(;forceupdate = true)
    color_set(ioc)
    latest_tracks_data
end

function make_single_replacement_with_permission_print(ioc, user_input, du::DataFrameRow, dv::DataFrameRow, tracks_data)
    plrefs_u = playlistrefs_containing_track(du.trackid, tracks_data)
    # tracks data might temporarily contain tracks which are no longer
    # referred in a playlist. We will delete unreferred tracks
    # elsewhere.
    isempty(plrefs_u) && return user_input
    if user_input == 'Y' # carried over
        println(ioc, text_colors[:normal], text_colors[:bold], "Using your permission to change playlist:", text_colors[:normal])
    else
        println(ioc, text_colors[:normal], text_colors[:bold], "Permission to change playlist?", text_colors[:normal])
    end
    io = IOContext(color_set(ioc, :green), :print_date => true)
    color_set(io)
    print(io, '\t')
    track_album_artists_print(io, du)
    print(color_set(io, :light_black), "\n\t which is on a ")
    color_set(io)
    print(io, du.albumtype)
    print(color_set(io, :light_black), " and is referred in ")
    for plref in plrefs_u
        length(plrefs_u) > 1 && print(io, "\n  ")
        playlist_no_details_print(color_set(io, :blue), plref)
        print(ioc, "  ")
    end
    color_set(ioc)
    @assert du.isrc == dv.isrc
    println(color_set(ioc, :light_black), "\n\t...we suggest to change with the identical International Standard Recording Code ", dv.isrc)
    print(io, '\t')
    track_album_artists_print(color_set(io, :green), dv)
    print(color_set(ioc, :light_black), "\n\twhich is on an ")
    color_set(ioc)
    print(color_set(ioc, :green), dv.albumtype)
    plrefs_v = playlistrefs_containing_track(dv.trackid, tracks_data)
    if length(plrefs_v) > 0
        print(color_set(ioc, :light_black), " and is referred in ")
        for plref in plrefs_v
            length(plrefs_v) > 1 && print(ioc, "\n  ")
            playlist_no_details_print(color_set(ioc, :blue), plref)
            print(ioc, "  ")
        end
    else
        print(color_set(ioc, :light_black), " and is not yet referred in your playlists.")
    end
    if du.albumtype == dv.albumtype
        print(color_set(ioc, :light_black), "\n\tThe current track's available markets is ")
        show(IOContext(color_set(ioc, :green), :limit => true), du.available_markets)
        #print(color_set(ioc, :green), du.available_markets)
        if dv.available_markets == String[]
            print(color_set(ioc, :light_black), "\n\t\t while the replacement is unlimited.")
        else
            print(color_set(ioc, :light_black), "\n\t\t while replacement available markets includes ")
            color_set(ioc)
            print(color_set(ioc, :green), get_user_country())
        end
    end
    if user_input ∉ "YN"
        user_input = pick_ynYNp_and_print(ioc, 'n', first(plrefs_u), du.trackid)
    end
    color_set(ioc)
    if user_input ∈ "Yy"
        println(color_set(ioc, :normal), "\n\tReplacing clone track with suggested original.")
        replace_track_in_playlists(plrefs_u, du.trackid => dv.trackid)
    else
        println(color_set(ioc, :normal), "\tNothing changed.")
    end
    color_set(ioc)
    println(ioc)
    user_input
end


"prefer_adjacent_clone_over_current(cur_row, adj_row) ---> Bool"
function prefer_adjacent_clone_over_current(cur_row, adj_row)
    criteria = Set([
        ("single", "album"),
        ("compilation", "album"),
        ("compilation", "single"),
        ("appears_on", "album"),
        ("appears_on", "single"),
        ("appears_on", "compilation")])
    (cur_row.albumtype, adj_row.albumtype) ∈ criteria && return true
    # Secondary criteria, then?
    this_market = get_user_country()
    market_status_cur = market_status(cur_row.available_markets, this_market)
    market_status_adj = market_status(adj_row.available_markets, this_market)
    # Criteria compares (market_status_cur , market_status_adj), both considered clones
    # of each other.
    # If a track has no value for 'available_markets', that is perfectly fine and acceptable.
    # If track data were retrieved without a 'market' argument, the 'available_markets' field
    # that was returned from the API would not be populated.
    market_criteria = Set([
        (:not_included, :included),
        (:not_included, :empty)
    ])
    (market_status_cur , market_status_adj) ∈ market_criteria && return true
    if cur_row.album_id == adj_row.album_id || semantic_equals(cur_row.album_name, adj_row.album_name)
        # If the references are to the same album, we can prefer
        # the adjacent clone with less restraint.
        loose_market_criteria = Set([
            (:not_included, :included),
            (:not_included, :empty),
            (:empty, :included)
        ])
       (market_status_cur , market_status_adj) ∈ loose_market_criteria && return true
    end
    false
end


function tracks_with_clones_data(tracks_data)
    # Filter to tracks which have .isrc identifier appearing at least twice. These have
    # different Spotify ids because they are contained in different albums, singles or compilations.
    countdic = countmap(tracks_data.isrc)
    clones_data = filter(row -> countdic[row.isrc] > 1, tracks_data)
    sort!(clones_data, :isrc)
    clones_data
end


function suggest_and_make_compilation_to_album_change_print(ioc, user_input, track_in_compilation_data, tracks_data)
    isrc = track_in_compilation_data[:isrc]
    q = Spotify.HTTP.escapeuri("isrc:$isrc")
    vec_objs = get_all_search_result_track_objects(q)
    length(vec_objs) == 0 && return user_input
    candidates_data = dataframe_from_search_objects(vec_objs)
    tracks_data_append_audio_features!(candidates_data; silent = true)
    filter!(:albumtype => ! ==("compilation"), candidates_data)
    isempty(candidates_data) && return user_input
    this_market = get_user_country()
    filter!(:available_markets => x -> market_status(x, this_market) ∈ [:included, :empty] , candidates_data)
    isempty(candidates_data) && return user_input
    # Contrary to definition, isrc codes (in Spotify data) do
    # not always uniquely identify a track recording. E.g.
    # isrc NLRD51412049 is associated with both of
    # ["Boops (Here To Go)", "So Simple - Da \"Inuyasha\""]
    #
    # We avoid making such replacement recommendations by a rough check on duration.
    # (fractions of a second can be due to re-encoding the same recording)
    filter!(candidates_data) do x
        abs(duration_sec(x.duration_ms)- duration_sec(track_in_compilation_data.duration_ms)) < 2
    end
    isempty(candidates_data) && return user_input
    # Suggest the newest of the remaining candidates. This is because Spotify's audio analysis
    # algorithms have improved, and we believe the latest added album has the best audio analysis.
    sort!(candidates_data, :release_date)
    track_in_album_data = candidates_data[end, :]
    make_single_replacement_with_permission_print(ioc, user_input, track_in_compilation_data, track_in_album_data, tracks_data)
end

# This is similar to 'make_named_tuple_from_json_object', but unfortunately
# the structure retrieved from search result is quite different, so little reuse here.
function dataframe_from_search_objects(vec_objs)
    admixture = DataFrame()
    for o in vec_objs
        artist_ids = Vector{SpArtistId}()
        artists = Vector{String}()
        for a in o.artists
            push!(artist_ids, SpArtistId(a.id))
            push!(artists, a.name)
        end
        available_markets = join(o.available_markets, " ")
        trackid = SpTrackId(o.id)
        album = o.album
        album_id = SpAlbumId(album.id)
        albumtype = album.album_type
        album_name = album.name
        release_date = album.release_date
        trackname = o.name
        isrc = o.external_ids[:isrc]
        field_names = (:trackid,
            :artists,
            :artist_ids,
            :album_id,
            :release_date,
            :available_markets,
            :album_name,
            :trackname,
            :albumtype,
            :isrc)
        field_values = [trackid,
            artists,
            artist_ids,
            album_id,
            release_date,
            available_markets,
            album_name,
            trackname,
            albumtype,
            isrc]
        namedtuple = NamedTuple{field_names}(field_values)
        if namedtuple[:albumtype] !== albumtype
            throw("Failed check !")
        end
        if isempty(admixture)
            admixture = DataFrame((namedtuple,))
        else
            append!(admixture, DataFrame((namedtuple,)))
        end
    end
    admixture
end
