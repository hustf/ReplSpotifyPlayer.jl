"""
    get_all_search_result_track_objects(q)
    ---> Vector{JSON3.Object}

The web API used directly has a limit of 50 results,
default is 20.

This is called from `suggest_and_make_compilation_to_album_change_print`, with
a query object q limited to searching for isrc. Other search results
are not very precise or helpful in my experience.
"""
function get_all_search_result_track_objects(q)
    results = Vector{JSON3.Object}()
    type = "track"
    limit = 50
    o, waitsec = Search.search_get(q, type = type, limit = limit)
    append!(results, collect(o.tracks.items))
    while o.tracks.next !== nothing && ! isempty(o.tracks.items) && length(o.tracks.items) > 1
        offset = length(results)
        o, waitsec = Search.search_get(q, type = type, limit = limit, offset = offset)
        append!(results, collect(o.tracks.items))
    end
    results
end



"""
    search_then_select_print(ioc, tracks_data)

Prompts user for a search string and shows results at pressing enter.
If relevant track results, print an enumerated list and offer selection, then exit to menu.
If not, but playlist results exists, print an enumerated playlist list and offer selection. 
This will play the first (probably) track in the playlist.

Search strings are stored in a global variable, so pressing 's' again allows modifying
the previous search string.

Search results internally are lines in a flattened data frame, like:
```
 Row │ trackid                 trackname                          album_name                         artist               release_date   pl_ref
     │ SpTrackId               String                             String                             String               String15       Playlist…
─────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
```

Because the data frame is 'flattened' on arist, some results will be for the same track.
"""
function search_then_select_print(ioc, tracks_data)
    global SEARCHString
    search_data = select(tracks_data, Cols(:trackname, :album_name, :artists, :release_date, :trackid, :album_id, :artist_ids, r"playlistref"))
    # Collect all playlistref columns to a joined one.
    transform!(search_data, r"playlistref"  => ByRow((cells...) -> filter(! ismissing, cells)) => :pl_refs)
    # Drop collected cols
    select!(search_data, Not(r"playlistref"))
    # One playlist ref per row
    search_data1 = flatten(search_data, [:pl_refs])
    rename!(search_data1, :pl_refs => :pl_ref)
    # One artist name per row
    df = flatten(search_data1, [:artists, :artist_ids])
    rename!(df, :artists => :artist, :artist_ids => :artist_id)
    # Fetch query from user
    search_query_prompt_print(ioc)
    q = string(read_line_with_predefined_text_print(ioc, SEARCHString[]))
    if q !== "" && q !== "..."
        trackname_hits = filter(:trackname => s -> semantic_contains(s, q), df)
        albumname_hits = filter(:album_name => s -> semantic_contains(s, q), df)
        artist_hits = filter(:artist =>  s -> semantic_contains(s, q), df)
        date_hits = filter(:release_date =>  s -> semantic_contains(string(s), q), df)
        playlist_hits_vector = unique(filter(:pl_ref =>  ref -> semantic_contains(ref.name, q), df)[!, :pl_ref])
        hits = DataFrame()
        append!(hits, trackname_hits)
        append!(hits, albumname_hits)
        append!(hits, artist_hits)
        append!(hits, date_hits)
        summary_short_search_results_print(ioc, q, trackname_hits, albumname_hits, artist_hits, date_hits, hits, playlist_hits_vector)
        if ! isempty(hits) > 0
            sort!(hits, :trackname)
            if ! isempty(date_hits)
                io = IOContext(ioc, :print_date => true)
            else
                io = ioc
            end
            println(ioc, "Listing hits:")
            rng = enumerated_track_album_artist_context_print(io, hits)
            println(ioc)
            select_track_context_and_play_print(ioc, hits)
        else
            if ! isempty(playlist_hits_vector)
                rng = enumerated_playlist_print(ioc, playlist_hits_vector, tracks_data)
                println(ioc)
                # Selecting a playlist intuitively means playing the first song in 
                # the playlist. We don't actually know the actual tracks sequence.
                # Instead of making a web service call, we will simply
                # jump to the first track.....
                # On Apple, the default terminal may produce ugly plots, e.g. ITerm2 is better.
                first_track_data = DataFrame()
                for playlist_ref in playlist_hits_vector
                    rw = subset(search_data1, :pl_ref => ByRow(==(playlist_ref)))[1, :]
                    push!(first_track_data, rw)
                end
                select_track_context_and_play_print(ioc, first_track_data)
            else
                println("Press s to search again.")
            end
        end
        println(ioc)
    else
        println(ioc, "\nEmpty search string, exiting search.")
    end
    color_set(ioc)
    return q
end

function search_query_prompt_print(ioc)
    println(ioc)
    println(color_set(ioc, :176), "Empty search returns to menu! Type text to search in: trackname, artist, playlist and album.")
    print(ioc, "Leading and trailing spaces are ignored. Control keys: ")
    print(color_set(ioc), " ⏎  →  ← ⌫  ins del")
    println(ioc)
end


function summary_short_search_results_print(ioc, q, trackname_hits, albumname_hits, artist_hits, date_hits, unique_track_hits, playlist_hits_vector)
    println(ioc, "\tSearch hits for '", q, "':" )
    nrow(trackname_hits) > 0 && println(ioc, "\t\ttrackname: ", nrow(trackname_hits), "  ")
    nrow(albumname_hits) > 0 && println(ioc, "\t\talbum_name: ", nrow(albumname_hits), "  ")
    nrow(artist_hits) > 0 && println(ioc, "\t\tartist:", nrow(artist_hits), "  ")
    nrow(date_hits) > 0 && println(ioc, "\t\tdate:", nrow(date_hits), "  ")
    println(ioc, "\t    Condensed to ", nrow(unique_track_hits), " track hits (one hit per involved artist)")
    length(playlist_hits_vector) > 0 && println(ioc, "\t\tplaylist hits: ", length(playlist_hits_vector))
end
