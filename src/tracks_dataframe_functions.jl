"""
    tracks_data_load_and_update(;silent = true)

Loads tracks data frame from file and updates it from online playlists.
Does not save to disk, maybe use `tracks_data_update()` instead?

# Example
```julia-repl
julia> TDF[] = tracks_data_load_and_update(; silent = false)
```
"""
function tracks_data_load_and_update(;silent = true)
    tracks_data = load_tracks_data()
    playlistrefs_df = playlist_owned_dataframe_get(;silent)
    sort!(playlistrefs_df)
    # This will append tracks, and also delete old versions.
    tracks_data_append!(tracks_data, playlistrefs_df; silent)
    tracks_data_delete_unsubscribed_playlists!(tracks_data, playlistrefs_df; silent)
    isempty(tracks_data) && return tracks_data
    tracks_data_append_audio_features!(tracks_data; silent)
    tracks_data
end


"""
     tracks_data_update(;forceupdate = false))

Preferred way to access TDF[] and save an updated version.

forceupdate = true => replace in-memory version.
"""
function tracks_data_update(;forceupdate = false)
    if isempty(TDF[]) || forceupdate
        TDF[] = tracks_data_load_and_update(;silent = false)
        if ! isempty(TDF[])
            save_tracks_data(TDF[])
        end
    end
    TDF[]
end

"""
    tracks_data_delete_other_playlist_snapshots!(tracks_data, playlistref)

In-place outdated reference deletion. Reorders so as to place 'missings' in the last ref. columns.
"""
function tracks_data_delete_other_playlist_snapshots!(tracks_data, playlistref::PlaylistRef)
    id = playlistref.id
    snid = playlistref.snapshot_id
    refdata = tracks_data[!, r"playlistref"]
    for rn in 1:nrow(refdata)
        for cn in 1:ncol(refdata)
            plc = refdata[rn, cn] # 'unpack'
            if ! ismissing(plc)
                @assert plc isa PlaylistRef
                if plc.id == id
                    if plc.snapshot_id !== snid
                        refdata[rn, cn] = missing
                    end
                end
            end
        end
        # In-place value sort - all cols are of same type.
        tracks_data[rn, :] = sort_columns_missing_last(tracks_data[rn, :])
    end
end
function tracks_data_delete_other_playlist_snapshots!(tracks_data, playlistrefs_df::DataFrame)
    for rn in 1:nrow(playlistrefs_df)
        playlistref = PlaylistRef(playlistrefs_df[rn,:])
        tracks_data_delete_other_playlist_snapshots!(tracks_data, playlistref)
    end
end

"""
    tracks_data_delete_unsubscribed_playlists!(tracks_data, playlistrefs_df; silent = true)

In-place unsubscribed reference deletion. Reorders so as to place 'missings' in the last ref. columns.
"""
function tracks_data_delete_unsubscribed_playlists!(tracks_data, playlistrefs_df::DataFrame; silent = true)
    if credentials_contain_scope("playlist-read-private")
        ! silent && println(stdout, "\nPruning outdated playlist references.")
        ids = playlistrefs_df.id
        refdata = tracks_data[!, r"playlistref"]
        for rn in 1:nrow(refdata)
            for cn in 1:ncol(refdata)
                plc = refdata[rn, cn] # 'unpack'
                if ! ismissing(plc)
                    @assert plc isa PlaylistRef
                    if plc.id ∉ ids
                        ! silent && print(stdout, "Remove ref. to \"", plc.name, "\"    ")
                        refdata[rn, cn] = missing
                    end
                end
            end
            # In-place value sort - all cols are of same type.
            tracks_data[rn, :] = sort_columns_missing_last(tracks_data[rn, :])
        end
        ! silent && println(stdout)
    else
        ! silent && println(stdout, "\nSkipping pruning playlists, since current grants do not allow to update playlist subscriptions.")
    end
end



"""
    tracks_data_append!(tracks_data, playlistrefs_df; silent = true)

# Arguments

- tracks_data      Each row describes a track and playlist references. Taken from TDF[].
- playlistrefs_df  Playlist references dataframe to add tracks from
- silent           Repl feedback
"""
function tracks_data_append!(tracks_data, playlistrefs_df; silent = true)
    ! silent && println(stdout, "\nUpdating local tracks from playlists ")
    for x in eachrow(playlistrefs_df)
        pl_ref = PlaylistRef(x)
        if is_other_playlist_snapshot_in_data(tracks_data, pl_ref)
            ! silent && printstyled(stdout, x.name * " - deleting old local version.   ", color = :light_red)
            tracks_data_delete_other_playlist_snapshots!(tracks_data, pl_ref)
        end
        if ! is_playlist_snapshot_in_data(tracks_data, pl_ref)
            # Add latest version
            ! silent && print(stdout, x.name, "    ")
            tracks_data_append!(tracks_data, pl_ref; silent)
            @assert !isempty(tracks_data)
        else
            # Already up to date
            ! silent && printstyled(stdout, pl_ref.name * "  ",  color = :light_black)
        end
    end
    tracks_data
end


"""
    tracks_data_append!(tracks_data::DataFrame, pl_ref::PlaylistRef; silent = true)

# Arguments

- tracks_data    Each row describes a track and playlist references. Taken from TDF[].
- pl_ref      Playlist reference to add tracks from
- silent    Repl feedback
"""
function tracks_data_append!(tracks_data::DataFrame, pl_ref::PlaylistRef; silent = true)
    track_ids, the_names = track_ids_and_names_in_playlist(pl_ref.id)
    tracks_data_append!(tracks_data::DataFrame, pl_ref::PlaylistRef, track_ids, the_names; silent)
    @assert !isempty(tracks_data)
    tracks_data
end



"""
    tracks_data_append!(tracks_data::DataFrame, pl_ref::PlaylistRef, track_ids::Vector{SpTrackId}, the_names::Vector{String}; silent = true)

# Arguments

- tracks_data    Each row describes a track and playlist references. Taken from TDF[].
- pl_ref      Playlist reference to add tracks from
- track_ids Tracks in pl_ref
- the_names    Names in pl_ref
- silent    Repl feedback
"""
function tracks_data_append!(tracks_data::DataFrame, pl_ref::PlaylistRef, track_ids::Vector{SpTrackId}, the_names::Vector{String}; silent = true)
    for (id, name) in zip(track_ids, the_names)
        if ! is_track_in_data(tracks_data, id)
            namedtuple = (trackid = id, trackname = name, playlistref = pl_ref,)
            push!(tracks_data, namedtuple; cols = :subset)
        else
            r = findfirst(rid -> id == rid, view(tracks_data, :, :trackid))
            if is_playlist_snapshot_in_data(view(tracks_data, r, :), pl_ref)
                # TODO: Check why false positives here. At least from a blank start.
                ! silent && println(stdout, "Duplicate track ", name, " in playlist ", pl_ref.name)
            else
                admixture = DataFrame(;trackid = id, trackname = name, playlistref = pl_ref)
                # Add this playlistref as a new column. In other rows, a 'missing' may be added to fill in.
                colprev = ncol(tracks_data)
                leftjoin!(tracks_data, admixture, on = [:trackid, :trackname], makeunique = true)
                @assert ncol(tracks_data) > colprev
                @assert ncol(tracks_data) - colprev == 1
                # We may have something like [...PlaylistRef, missing, PlaylistRef] now.
                # Which would cause the table to grow unnecesarily. Move 'missing' to the last column!
                r = findfirst(rid -> id == rid, view(tracks_data, :, :trackid))
                tracks_data[r, :] = sort_columns_missing_last(tracks_data[r, :])
                rkeep = findfirst(! ismissing, tracks_data[:, colprev + 1])
                if isnothing(rkeep)
                    # After moving 'missing' to the last column of the row, all the last column has only 'missing', so delete it!
                    select!(tracks_data, 1:colprev)
                    @assert ncol(tracks_data) == colprev
                else
                    ! silent && println(stdout, "    -*Track ", name, " also appears in playlist ", pl_ref.name)
                end
            end
        end
    end
    @assert !isempty(tracks_data)
    tracks_data
end


function tracks_data_append_audio_features!(tracks_data; silent = true)
    append_missing_audio_features!(tracks_data)
    nr = nrow(tracks_data)
    ! silent && println(stdout, "\nAdding missing audio features in ", nr, " tracks. Progress:")
    for (i, trackrefs_rw) in enumerate(eachrow(tracks_data))
        insert_audio_feature_vals!(trackrefs_rw)
        if mod(i, 10) == 1
            if ! silent
                REPL.Terminals.clear_line(REPL.Terminals.TTYTerminal("", stdin, stdout, stderr))
                print(stdout, "   ", round(i / nr; digits = 2))
                sleep(0.002)
            end
        end
    end
    ! silent && println(stdout)
    tracks_data
end

function append_missing_audio_features!(tracks_data)
    prna = propertynames(tracks_data)
    notpresent = setdiff(wanted_feature_keys(), prna)
    if ! isempty(notpresent)
        v = Vector{Any}(fill(missing, nrow(tracks_data)))
        nt = map(k-> k => copy(v), notpresent)
        insertcols!(tracks_data, 3, nt...)
    end
end

function insert_audio_feature_vals!(trackrefs_rw)
    ! ismissing(trackrefs_rw[first(wanted_feature_keys())]) && return trackrefs_rw
    fdic = get_audio_features_dic(trackrefs_rw[:trackid])
    for (k,v) in fdic
        trackrefs_rw[k] = v
    end
    trackrefs_rw
end




"""
    sort_columns_missing_last(rw::DataFrameRow)

Reorder the column values of type {Union, Missing}.
"""
function sort_columns_missing_last(rw::DataFrameRow)
    coltyps = eltype.(eachcol(parent(rw)))
    first_potential_missing = findfirst(x -> x <: Union{Missing, PlaylistRef}, coltyps)
    last_potential_missing = findlast(x -> x <: Union{Missing, PlaylistRef}, coltyps)
    ite = first_potential_missing:last_potential_missing
    v = @view rw[ite]
    vs = sort(collect(v), by = (x -> ismissing(x) ? 1 : 0))
    for (i, newval) in zip(ite, vs)
        rw[i] = newval
    end
    rw
end



function housekeeping_clones_print(ioc, tracks_data::DataFrame)
    suspects_data = tracks_with_clones_data(tracks_data)
    # Get tracks objects inlculding potential 'linked_from' fields. 
    suspected_objects = get_multiple_tracks(suspects_data[!, :trackid])
    clones_metadata_print(ioc, suspects_data, suspected_objects)
    suggest_and_make_replacements_print(ioc, suspects_data, suspected_objects, tracks_data)
    remove_unreferred_tracks!(tracks_data)
    save_tracks_data(tracks_data)
end


# There is playlistref, playlistref_1, etc.
# However, if the first value is missing, all 
# of the columns are missing.
remove_unreferred_tracks!(tracks_data) = filter!(:playlistref => ! ismissing, tracks_data)

function suggest_and_make_replacements_print(ioc, suspects_data, suspected_objects, tracks_data)
    # suspects_data and suspected_objects are sorted and of the same length
    @assert length(suspected_objects) == nrow(suspects_data) 
    n = nrow(suspects_data)
    println(color_set(ioc, :light_black), "\nAssessing $n clones in pairs with respect to authentic origin. An album is more genuine than e.g. a generic collection.).\n")
    # If user replies ('Y' or 'N'), no more questions will be asked. So this variable is defined outside the loop.
    user_input = 'n'
    # index u, for the 'current' object
    for u in 1:n
        # look for v above and below u.
        v = u - 1
        if v < 1 || suspects_data[u, :trackname] !== suspects_data[v, :trackname]
            v = u + 1
            if v > n || suspects_data[u, :trackname] !== suspects_data[v, :trackname]
                continue # Neither above nor below is a clone with current. Which is unexpected.
            end
        end
        ou = suspected_objects[u]
        ov = suspected_objects[v]
        this_market = get_user_country()
        if prefer_adjacent_over_current(ou, ov, this_market)
            track_id_u = SpTrackId(ou.uri)
            plrefs_u = playlistrefs_containing_track(track_id_u, tracks_data)
            # tracks data might temporarily contain tracks which are no longer
            # referred in a playlist. We will delete unreferred tracks
            # elsewhere. For now, just skip to the next item!
            isempty(plrefs_u) && continue
            io = color_set(ioc, :green)
            track_album_artists_print(io, ou)
            print(color_set(io, :light_black), "\n which is on a ")
            color_set(io)
            print(io, ou.album.album_type)
            print(color_set(io, :light_black), " and is referred in ")

            for plref in plrefs_u
                length(plrefs_u) > 1 && print(io, "\n  ")
                playlist_no_details_print(color_set(io, :blue), plref)         
                print(ioc, "  ")
            end
            color_set(ioc)
            println(color_set(ioc, :light_black), "\n  ...we suggest to change to the identical track ")
            track_album_artists_print(color_set(ioc, :green), ov) 
            print(color_set(ioc, :light_black), "\n which is on an ")
            color_set(ioc)
            print(color_set(ioc, :green), ov.album.album_type)
            print(color_set(ioc, :light_black), " and is referred in ")
            track_id_v = SpTrackId(ov.uri)
            plrefs_v = playlistrefs_containing_track(track_id_v, tracks_data)
            for plref in plrefs_v
                length(plrefs_v) > 1 && print(ioc, "\n  ")
                playlist_no_details_print(color_set(ioc, :blue), plref)         
                print(ioc, "  ")
            end
            if ou.album.album_type == ov.album.album_type
                print(color_set(ioc, :light_black), " The suggestion is based on market availability.")
            end
            if user_input ∉ "YN"
                user_input = pick_ynYNp_and_print(ioc, 'n', first(plrefs_u), track_id_u)
            end
            color_set(ioc)
            if user_input ∈ "Yy"
                println(color_set(ioc, :normal), "\n  Replacing clone track with suggested original.")
                replace_track_in_playlists(plrefs_u, track_id_u => track_id_v)
            else 
                println(color_set(ioc, :normal), "\n  Nothing changed.")
            end
            color_set(ioc)
            println(ioc)
        else
            # The current clone ou is preferrable over the adjacent, ov. Do nothing.
            println(ioc, "No suggestion for clones ",     (ou.album.album_type, ov.album.album_type) )
            print(ioc, "    ")
            track_album_artists_print(ioc, ou)
            print(ioc, "\n    ") 
            track_album_artists_print(ioc, ov)
            println(ioc) 
        end
    end # for
    tracks_data_update(;forceupdate = true)
    println(color_set(ioc, :light_black), "\nFinished assessing clone pairs with respect to authentic origin.\n")
end


"prefer_adjacent_over_current(o_cur, o_adj) ---> Bool"
function prefer_adjacent_over_current(o_cur, o_adj, this_market)
    # CONSIDER Note, this does not yet cover the case:
    # An album has been re-released, but is essentially the same.
    # An example is "Made In Medina": spotify:album:3hBjCRF8nbh374xqB66Ojl and spotify:album:5umeFXcIuIdkNJc0fpvIwt
    # Not having a good solution, we do nothing so far (return false). But other checks could be added 
    # when the first return false.
    #
    # Criteria compares ("this album type", "adjacent album type"), both considered clones
    # of each other 
    criteria = Set([
        ("single", "album"),
        ("compilation", "album"),
        ("compilation", "single"),
        ("appears_on", "album"),
        ("appears_on", "single"),
        ("appears_on", "compilation")])
    if (o_cur.album.album_type, o_adj.album.album_type) ∈ criteria
        return true
    end
    available_markets_cur = get(o_cur, :available_markets, String[])
    available_markets_adj = get(o_adj, :available_markets, String[])

    market_state_cur = market_state(available_markets_cur, this_market)
    market_state_adj = market_state(available_markets_adj, this_market)
    # Criteria compares (market_state_cur , market_state_adj), both considered clones
    # of each other 

    market_criteria = Set([
        (:empty, :included),
        (:not_included, :included),
        (:not_included, :empty)
    ])
    if (market_state_cur , market_state_adj) ∈ market_criteria
        return true
    end
    false
end

function market_state(state, this_market)
    if state ==  Union{}[]
        :empty
    elseif this_market ∈ state
        :included
    elseif this_market ∉ state
        :not_included
    else
        throw("Not expected .available_market: $state \n $this_market")
    end
end


"""
    clones_metadata_print(ioc, suspects_data, suspected_objects)

Prior to housekeeping, print metadata about clones. This aids in
housekeeping. 

Clones sound identical, but have different metadata.
Some clone tracks are acceptable, but not nice.
"""
function clones_metadata_print(ioc, suspects_data, suspected_objects)
    this_market = get_user_country()
    println(color_set(ioc, :light_black), "Checking $(length(suspected_objects)) clone tracks for relinking and unavailability.")
    for (track_object, track_row) in zip(suspected_objects, eachrow(suspects_data))
        linkedfrom = get(track_object, :linked_from, nothing)
        if ! isnothing(linkedfrom)
            from_track_id = SpTrackId(linkedfrom.uri)
            if from_track_id == track_row[:trackid]
                track_id_o = SpTrackId(track_object.uri)
                if from_track_id !== track_id_o
                    printstyled(stdout, track_row[:trackname], color = :green)
                    printstyled(stdout, " with track object id  ")
                    print(stdout, track_id_o)
                    printstyled(stdout, " was relinked from tracks data entry ", color = :yellow)
                    print(stdout, from_track_id)
                else
                    throw("unexpected.")
                end
            else
                printstyled(stdout, track_row[:trackname], " has a different linkedfrom field.", color = :yellow)
                throw("Unexpected value. Decide what to do (replace trackid in playlist?).")
            end
        else
            available_markets = get(track_object, :available_markets, String[])
            if available_markets ==  Union{}[]
                io = IOContext(color_set(ioc, :white), :print_ids => true)
                print(io,  "'available markets' is empty:    ")
                print(io, "    ")
                track_album_artists_print(io, track_object)
                println(ioc) 
            else
                if this_market ∈ available_markets
                    io = IOContext(color_set(ioc, :green), :print_ids => true)
                    print(io,  "'available markets' includes $this_market and $(length(available_markets) - 1) others: ")
                    print(io, "    ")
                    track_album_artists_print(io, track_object)
                    println(ioc) 
                else
                    io = IOContext(color_set(ioc, :magenta), :print_ids => true)
                    print(io,  "'available markets' excludes $this_market: ")
                    print(io, "    ")
                    track_album_artists_print(io, track_object)
                    println(io, "                'available markets' = $available_markets\n")
                end
            end
        end
    end
end 
function tracks_with_clones_data(tracks_data)
    df1 = select(tracks_data, :trackid, :trackname, :duration_ms)
    # We know that trackid cells are unique. 
    df2 = select(tracks_data, :trackname, :duration_ms)
    # To compare two tracks, milliseconds is considered too accurate.
    # Add a column for the less strict criterion.
    df2.duration_s = Int.(round.(df2[!, :duration_ms] ./ 1000))
    # Drop the old column
    df2 = select(df2, :trackname, :duration_s)
    # Capture df2 in function definition to make single-argument function.
    function iscopy(row::DataFrameRow)
        rowno = rownumber(row)
        trackname = row[:trackname]
        duration_s = row[:duration_s]
        for rw in eachrow(df2)
            rownumber(rw) == rowno && continue
            duration_s == rw[:duration_s] && trackname == rw[:trackname] && return true
        end
        false
    end
    # Add a column showing a track was duplicated (or triplicated, quadruplicated, complicated)
    df1.copy = map(iscopy, eachrow(df2))
    # Filter to keep only trackids from rows that have copies.
    df3 = filter(row -> row.copy, df1)
    sort(select(df3, :trackid, :trackname, :duration_ms), :trackname)
end
