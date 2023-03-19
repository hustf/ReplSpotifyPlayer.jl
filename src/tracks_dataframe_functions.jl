"""
    playlist_owned_refs_get(;silent = true)
    -> Vector{PlaylistRef}, prints to stdout

Storing PlaylistRefs instead of SpPlaylistId enables us to
identify when playlist contents have been updated. There's
no need to refresh our local lists when snapshot_id is
unchanged.

This function is so quick that there's no need to store output
for long (tracks are another matter, and have no snapshot_id).
"""
function playlist_owned_refs_get(;silent = true)
    batchsize = 50
    playlistrefs = Vector{PlaylistRef}()
    for batchno = 0:200
        json, waitsec = Spotify.Playlists.playlist_get_current_user(limit = batchsize, offset = batchno * batchsize)
        isempty(json) && break
        waitsec > 0 && throw("Too fast, whoa!")
        l = length(json.items)
        l == 0 && break
        for item in json.items
            if item.owner.display_name == get_user_name()
                ! silent && println(stdout, item.name)
                push!(playlistrefs, PlaylistRef(item))
            else
                ! silent && printstyled(stdout, "We're not including $(item.name), which is owned by $(item.owner.id)\n", color= :176)
            end
        end
    end
    playlistrefs
end

"""
    playlist_owned_dataframe_get(; silent = true)

# Example

```
julia> playlist_owned_dataframe_get()
87×3 DataFrame
 Row │ name          snapshot_id                        id
     │ String        String                             SpPlayli…
─────┼─────────────────────────────────────────────────────────────────────────
   1 │ Santana       MTUsZjkxNTk5ZTNjZmU5NTAwNjVmZmMw…  3NlsEQpwa0EGKoWjI6lRGG
   2 │ 123-124spm    MTQsYTRjZWY5NTMwZjQwOTM2NjYxOGFk…  5c0by8vfXvJ2MVTyExKBHA
  ⋮  │      ⋮                        ⋮                            ⋮
  87 │ Nero remix    MTIsZWY1NTIxMjlmYjRhYTU3NTIyOTcz…  6SsuaqQY0ibRJOpWVyshfb
                                                                84 rows omitted
```
"""
playlist_owned_dataframe_get(; silent = true) = DataFrame(playlist_owned_refs_get(;silent))

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


function trackrefs_dataframe_delete_other_playlist_versions!(trackrefs_df, playlistref)
    id = playlistref.id
    snid = playlistref.snapshot_id
    refdata = @view trackrefs_df[!, r"playlistref"]
    for rn in 1:nrow(trackrefs_df)
        for cn in 1:ncol(refdata)
            plc = refdata[rn, cn] # 'unpack', probably not necessary.
            if ! ismissing(plc)
                @assert plc isa PlaylistRef
                if plc.id == id
                    if plc.snapshot_id !== snid
                        refdata[rn, cn] = missing
                    end
                end
            end
        end
        # Oh so ugly
        trackrefs_df[rn, :] = sort_columns_missing_last(trackrefs_df[rn, :])
    end
end

function trackrefs_dataframe_delete_unsubscribed_playlists!(trackrefs_df, playlistrefs_df)
    ids = playlistrefs_df.id
    refdata = @view trackrefs_df[!, r"playlistref"]
    for rn in 1:nrow(trackrefs_df)
        for cn in 1:ncol(refdata)
            plc = refdata[rn, cn] # 'unpack', probably not necessary.
            if ! ismissing(plc)
                @assert plc isa PlaylistRef
                if plc.id ∉ ids
                    refdata[rn, cn] = missing
                end
            end
        end
        # Oh so ugly
        trackrefs_df[rn, :] = sort_columns_missing_last(trackrefs_df[rn, :])
    end
end
#=
function trackrefs_dataframe_append!(tdf::DataFrame, l::PlaylistRef, trackids::Vector{SpTrackId}, nms::Vector{String}; silent = true)
    for (id, name) in zip(trackids, nms)
        if isempty(tdf) || id ∉ view(tdf, :, :trackid)
            namedtuple = (trackid = id, trackname = name, playlistref = l,)
            push!(tdf, namedtuple; cols = :subset)
        else
            r = findfirst(rid -> id == rid, view(tdf, :, :trackid))
            if l ∈ filter(!ismissing, collect(view(tdf, r, :)))
                ! silent && println(stdout, "Duplicate track ", name, " in playlist ", l.name)
            else
                admixture = DataFrame(;trackid = id, trackname = name, playlistref = l)
                # Add this playlistref as a new column. In other rows, a 'missing' may be added to fill in.
                colprev = ncol(tdf)
                leftjoin!(tdf, admixture, on = [:trackid, :trackname], makeunique = true)
                @assert ncol(tdf) > colprev
                @assert ncol(tdf) - colprev == 1
                # We may have something like [...PlaylistRef, missing, PlaylistRef] now.
                # Which would cause the table to grow unnecesarily. Move 'missing' to the last column!
                r = findfirst(rid -> id == rid, view(tdf, :, :trackid))
                tdf[r, :] = sort_columns_missing_last(tdf[r, :])
                rkeep = findfirst(! ismissing, tdf[:, colprev + 1])
                if isnothing(rkeep)
                    # After moving 'missing' to the last column of the row, all the last column has only 'missing', so delete it!
                    select!(tdf, 1:colprev)
                    @assert ncol(tdf) == colprev
                else
                    ! silent && println(stdout, "    -*Track ", name, " also appears in playlist ", l.name)
                end
            end
        end
    end
    @assert !isempty(tdf)
    tdf
end
=#
function trackrefs_dataframe_append!(tdf::DataFrame, l::PlaylistRef, trackids::Vector{SpTrackId}, nms::Vector{String}; silent = true)
    for (id, name) in zip(trackids, nms)
        if ! is_track_in_data(tdf, id)
            namedtuple = (trackid = id, trackname = name, playlistref = l,)
            push!(tdf, namedtuple; cols = :subset)
        else
            r = findfirst(rid -> id == rid, view(tdf, :, :trackid))
            if is_playlist_snapshot_in_data(view(tdf, r, :), l)
                ! silent && println(stdout, "Duplicate track ", name, " in playlist ", l.name)
            else
                admixture = DataFrame(;trackid = id, trackname = name, playlistref = l)
                # Add this playlistref as a new column. In other rows, a 'missing' may be added to fill in.
                colprev = ncol(tdf)
                leftjoin!(tdf, admixture, on = [:trackid, :trackname], makeunique = true)
                @assert ncol(tdf) > colprev
                @assert ncol(tdf) - colprev == 1
                # We may have something like [...PlaylistRef, missing, PlaylistRef] now.
                # Which would cause the table to grow unnecesarily. Move 'missing' to the last column!
                r = findfirst(rid -> id == rid, view(tdf, :, :trackid))
                tdf[r, :] = sort_columns_missing_last(tdf[r, :])
                rkeep = findfirst(! ismissing, tdf[:, colprev + 1])
                if isnothing(rkeep)
                    # After moving 'missing' to the last column of the row, all the last column has only 'missing', so delete it!
                    select!(tdf, 1:colprev)
                    @assert ncol(tdf) == colprev
                else
                    ! silent && println(stdout, "    -*Track ", name, " also appears in playlist ", l.name)
                end
            end
        end
    end
    @assert !isempty(tdf)
    tdf
end


function trackrefs_dataframe_append!(tdf::DataFrame, l::PlaylistRef; silent = true)
    trackids, nms = track_ids_and_names_in_playlist(l.id)
    trackrefs_dataframe_append!(tdf::DataFrame, l::PlaylistRef, trackids, nms; silent)
    @assert !isempty(tdf)
    tdf
end

function trackrefs_dataframe_append!(trackrefs_df, playlistrefs_df; silent = true)
    for x in eachrow(playlistrefs_df)
        l = PlaylistRef(x)
        if ! is_playlist_snapshot_in_data(trackrefs_df, l)
            if is_other_playlist_snapshot_in_data(trackrefs_df, l)
                trackrefs_dataframe_delete_other_playlist_versions!(trackrefs_df, playlistrefs_df)
                ! silent && println(stdout, x.name, " - replacing old version in tracks table.")
            else
                ! silent && println(stdout, x.name, " - adding first version to tracks table.")
            end
            trackrefs_dataframe_append!(trackrefs_df, l; silent)
            @assert !isempty(trackrefs_df)
        else
            ! silent && println(stdout, l.name,  " - it is known...")
        end
        #x.name ==  "107-108spm" && break # TEMP DEBUG
    end
    trackrefs_df
end


wanted_feature_keys() = [:danceability, :key, :valence, :speechiness, :duration_ms, :instrumentalness, :liveness, :mode, :acousticness, :time_signature, :energy, :tempo, :loudness]
wanted_feature_pair(p) = p[1] ∈ wanted_feature_keys()

function get_audio_features_dic(trackid)
    jsono, waitsec = tracks_get_audio_features(trackid)
    if waitsec > 0
        @info waitsec
        sleep(waitsec)
    end
    filter(wanted_feature_pair, jsono)
end

function append_missing_audio_features!(tdf)
    prna = propertynames(tdf)
    notpresent = setdiff(wanted_feature_keys(), prna)
    if ! isempty(notpresent)
        v = Vector{Any}(fill(missing, nrow(tdf)))
        nt = map(k-> k => copy(v), notpresent)
        insertcols!(tdf, 3, nt...)
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

function trackrefs_append_audio_features!(trackrefs_df; silent = true)
    append_missing_audio_features!(trackrefs_df)
    nr = nrow(trackrefs_df)
    for (i, trackrefs_rw) in enumerate(eachrow(trackrefs_df))
        insert_audio_feature_vals!(trackrefs_rw)
        #trackrefs_rw[:trackname] ==  "Brian Song" && break # TEMP DEBUG
        if mod(i, 10) == 1
            ! silent && print(stdout, " Audio features  ", i, " / ", nr)
        end
    end
    ! silent && print(stdout, "\n")
    trackrefs_df
end



fullpath_trackrefs() = joinpath(homedir(), ".repl_player_tracks.csv")
save_tracks_data(trackrefs_df; fpth = fullpath_trackrefs()) = CSV.write(fpth, trackrefs_df)
save_tracks_data(; fpth = fullpath_trackrefs()) = save_tracks_data(TDF[]; fpth )
function _loadtypes(i, name)
    name == :trackid ? SpTrackId : nothing
    if name == :trackid
        SpTrackId
    elseif startswith(string(name), "playlistref")
        PlaylistRef
    else
        nothing
    end
end
function load_tracks_data(;fpth = fullpath_trackrefs())
    if isfile(fpth)
        DataFrame(CSV.File(fpth; types = _loadtypes))
    else
        DataFrame()
    end
end

function trackrefs_dataframe_get(;silent = true)
    trackrefs_df = load_tracks_data()
    playlistrefs_df = playlist_owned_dataframe_get(;silent)
    trackrefs_dataframe_delete_unsubscribed_playlists!(trackrefs_df, playlistrefs_df)
    sort!(playlistrefs_df)
    trackrefs_dataframe_append!(trackrefs_df, playlistrefs_df; silent)
    trackrefs_append_audio_features!(trackrefs_df; silent)
    trackrefs_df
end
