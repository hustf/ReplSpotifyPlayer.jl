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
    println(stdout, "Loading and updating tracks data.")
    tracks_data = load_tracks_data()
    playlistrefs_df = playlist_owned_dataframe_get(;silent)
    if isempty(playlistrefs_df)
        println(stdout, "Aborting update of tracks data; received no owned playlists from web service.")
        return tracks_data
    end
    sort!(playlistrefs_df)
    # This will append tracks, and also delete old versions.
    tracks_data_append!(tracks_data, playlistrefs_df; silent)
    isempty(tracks_data) && return tracks_data
    tracks_data_delete_unsubscribed_playlists!(tracks_data, playlistrefs_df; silent)
    remove_tracks_without_refs_and_print!(stdout,  tracks_data; silent)
    isempty(tracks_data) && return tracks_data
    if ! isequal(tracks_data, load_tracks_data())
        tracks_data_append_audio_features!(tracks_data; silent)
    end
    tracks_data
end


"""
     tracks_data_update(;forceupdate = false, silent = false)

Preferred way to access TDF[] and save an updated version.

# Arguments
forceupdate = true => replace in-memory version.
silent = true => less printed noise.
"""
function tracks_data_update(;forceupdate = false, silent = false)
    if isempty(TDF[]) || forceupdate
        TDF[] = tracks_data_load_and_update(;silent)
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
        tracks_data[rn, :] = sort_playlistrefs_missing_last(tracks_data[rn, :])
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
        ! silent && println(stdout, "Pruning outdated playlist references.")
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
            tracks_data[rn, :] = sort_playlistrefs_missing_last(tracks_data[rn, :])
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
            tracks_data_append_playlist!(tracks_data, pl_ref)
            @assert !isempty(tracks_data)
        else
            # Already up to date
            ! silent && printstyled(stdout, pl_ref.name * "  ",  color = :light_black)
        end
    end
    println(stdout)
    tracks_data
end


"""
    tracks_data_append_playlist!(tracks_data::DataFrame, pl_ref::PlaylistRef; silent = true)

# Arguments

- tracks_data    Each row describes a track and playlist references. Taken from TDF[].
- pl_ref      Playlist reference to add tracks from
- silent    Repl feedback
"""
function tracks_data_append_playlist!(tracks_data::DataFrame, pl_ref::PlaylistRef; silent = true)
    nt_playlist = tracks_namedtuple_from_playlist(pl_ref.id)
    tracks_data_append_namedtuple_from_playlist!(tracks_data, pl_ref, nt_playlist; silent) # 0.000115s (600+ tracks)
    @assert !isempty(tracks_data)
    tracks_data
end


"""
    tracks_data_append_namedtuple_from_playlist!(tracks_data::DataFrame, pl_ref::PlaylistRef, nt_playlist::NamedTuple; silent = true)

# Arguments

- tracks_data    Each row describes a track and playlist references. Taken from TDF[].
- pl_ref         Playlist reference for admixture.
- nt_playlist    column names and vectors of data
- silent         Repl feedback
"""
function tracks_data_append_namedtuple_from_playlist!(tracks_data::DataFrame, pl_ref::PlaylistRef,  nt_playlist::NamedTuple; silent = false)
    df = DataFrame(nt_playlist)
    # We could add this column in the original namedtuple, but we did not. Add it now.
    df.playlistref .= [pl_ref]
    if isempty(tracks_data)
        append!(tracks_data, df)
    else
        # We could do this in one 'outerjoin', but there is no mutating version of it!
        # outerjoin(tracks_data, df, on=[keys(nt_playlist)...], makeunique = true)
        #
        # Instead, we do this track by track....
        for (i, rw) in enumerate(eachrow(df))
            if ! is_track_in_data(tracks_data, rw.trackid)
                push!(tracks_data, rw; cols = :subset) # 5.04μs
            else
                id = rw[:trackid]
                r = findfirst(rid -> id == rid, view(tracks_data, :, :trackid))
                if is_playlist_snapshot_in_data(view(tracks_data, r, :), pl_ref) # 1.9μs
                    ! silent && println(stdout, "Duplicate track '", rw[:trackname], "' in playlist '", pl_ref.name, "'")
                else
                    # Add this playlistref as a new column. In other rows, a 'missing' may be added to fill in.
                    colprev = ncol(tracks_data)
                    leftjoin!(tracks_data, DataFrame(rw), on=[keys(nt_playlist)...], makeunique = true, matchmissing = :equal)
                    @assert ncol(tracks_data) == colprev + 1
                    # If playlists have been deleted, we may have rw ending in something like
                    # [...playlist_ref_A, missing, playlist_ref_B] now.
                    # Which would cause the table to grow unnecessarily. Move 'missing' to the last column!
                    tracks_data[r, :] = sort_playlistrefs_missing_last(tracks_data[r, :]) # 6.860 μs
                    if isempty(skipmissing(tracks_data[!, end]))
                        select!(tracks_data, 1:((ncol(tracks_data) - 1)))
                    end
                end
            end # if is track
        end # for
    end # if isempty
    @assert !isempty(tracks_data)
    delete_the_last_and_missing_playlistref_columns!(tracks_data)
    tracks_data
end

function delete_the_last_and_missing_playlistref_columns!(tracks_data)
    coltyps = eltype.(eachcol(tracks_data))
    cols = findall(x -> x <: Union{Missing, PlaylistRef}, coltyps)
    while isequal(tracks_data[!, last(cols)], [missing])
        select!(tracks_data, Not(last(cols)))
        coltyps = eltype.(eachcol(tracks_data))
        cols = findall(x -> x <: Union{Missing, PlaylistRef}, coltyps)
    end
    tracks_data
end


function tracks_data_append_audio_features!(tracks_data; silent = true)
    append_missing_audio_features!(tracks_data)
    tracks_missing_audio_features = subset(tracks_data, :danceability => ByRow(ismissing); view = true)
    nr = nrow(tracks_missing_audio_features)
    if isempty(tracks_missing_audio_features)
        ! silent && println(stdout, "\nNo missing audio features in ", nr, " tracks.")
        return tracks_data
    end
    ! silent && println(stdout, "\nAdding missing audio features in ", nr, " tracks. Progress:")
    for (i, trackrefs_rw) in enumerate(eachrow(tracks_missing_audio_features))
        insert_audio_feature_vals!(trackrefs_rw)
        if mod(i, 10) == 1
            if ! silent
                REPL.Terminals.clear_line(REPL.Terminals.TTYTerminal("", stdin, stdout, stderr))
                print(stdout, "   ", round(i / nr; digits = 2))
                sleep(0.001)
            end
        end
    end
    ! silent && println(stdout)
    # We worked with views and mutating arguments, but still:
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
    sort_playlistrefs_missing_last(rw::DataFrameRow)

Reorder the column values of type {Union, Missing}.
"""
function sort_playlistrefs_missing_last(rw::DataFrameRow)
    coltyps = eltype.(eachcol(parent(rw)))
    cols = findall(x -> x <: Union{Missing, PlaylistRef}, coltyps)
    v = @view rw[cols]
    vs = sort(collect(v), by = (x -> ismissing(x) ? 1 : 0))
    for (i, newval) in zip(cols, vs)
        rw[i] = newval
    end
    rw
end


"""
    remove_tracks_without_refs_and_print!(ioc,  tracks_data; silent = false)

Prune tracks that have been deleted from all owned playlists
"""
function remove_tracks_without_refs_and_print!(ioc,  tracks_data; silent = false)
    io = color_set(ioc, :normal)
    ! silent && println(io, "Pruning unreferred tracks.")
    color_set(ioc)
    filter!(:playlistref => ! ismissing, tracks_data)
end
