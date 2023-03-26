"""
    tracks_data_get(;silent = true)

Loads tracks data frame from file and updates it. Called when loading the module.

# Example
```julia-repl
julia> TDF[] = tracks_data_get(; silent = false)
```
"""
function tracks_data_get(;silent = true)
    tracks_data = load_tracks_data()
    playlistrefs_df = playlist_owned_dataframe_get(;silent)
    tracks_data_delete_unsubscribed_playlists!(tracks_data, playlistrefs_df)
    sort!(playlistrefs_df)
    tracks_data_append!(tracks_data, playlistrefs_df; silent)
    tracks_data_append_audio_features!(tracks_data; silent)
    tracks_data
end


"""
    tracks_data_delete_other_playlist_snapshots!(tracks_data, playlistref)

In-place outdated reference deletion. Reorders so as to place 'missings' in the last ref. columns.
"""
function tracks_data_delete_other_playlist_snapshots!(tracks_data, playlistref)
    id = playlistref.id
    snid = playlistref.snapshot_id
    refdata = @view tracks_data[!, r"playlistref"]
    for rn in 1:nrow(tracks_data)
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

"""
    tracks_data_delete_unsubscribed_playlists!(tracks_data, playlistrefs_df)

In-place unsubscribed reference deletion. Reorders so as to place 'missings' in the last ref. columns.
"""
function tracks_data_delete_unsubscribed_playlists!(tracks_data, playlistrefs_df)
    ids = playlistrefs_df.id
    refdata = tracks_data[!, r"playlistref"]
    for rn in 1:nrow(refdata)
        for cn in 1:ncol(refdata)
            plc = refdata[rn, cn] # 'unpack'
            if ! ismissing(plc)
                @assert plc isa PlaylistRef
                if plc.id ∉ ids
                    refdata[rn, cn] = missing
                end
            end
        end
        # In-place value sort - all cols are of same type.
        tracks_data[rn, :] = sort_columns_missing_last(tracks_data[rn, :])
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
    ! silent && println("\nUpdating local data.. ")
    for x in eachrow(playlistrefs_df)
        pl_ref = PlaylistRef(x)
        if ! is_playlist_snapshot_in_data(tracks_data, pl_ref)
            if is_other_playlist_snapshot_in_data(tracks_data, pl_ref)
                tracks_data_delete_other_playlist_snapshots!(tracks_data, playlistrefs_df)
                ! silent && println(stdout, x.name, " - replacing old version in tracks table.")
            else
                ! silent && println(stdout, x.name, " - adding first version to tracks table.")
            end
            tracks_data_append!(tracks_data, pl_ref; silent)
            @assert !isempty(tracks_data)
        else
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
    for (i, trackrefs_rw) in enumerate(eachrow(tracks_data))
        insert_audio_feature_vals!(trackrefs_rw)
        if mod(i, 10) == 1
            ! silent && print(stdout, " Audio features  ", i, " / ", nr)
        end
    end
    ! silent && print(stdout, "\n")
    tracks_data
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