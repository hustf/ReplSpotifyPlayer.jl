function is_playlist_snapshot_in_data(tracks_data::DataFrame, pl_ref::PlaylistRef)
    isempty(tracks_data) && return false
    for c in eachcol(tracks_data[!, r"playlistref"])
        pl_ref ∈ filter(! ismissing, c) && return true
    end
    false
end
function is_playlist_snapshot_in_data(trackrefs_rw::DataFrameRow, pl_ref::PlaylistRef)
    isempty(trackrefs_rw) && return false
    for c in trackrefs_rw[r"playlistref"]
        ! ismissing(c) && c == pl_ref && return true
    end
    false
end
is_playlist_snapshot_in_data(playlistref) = is_playlist_snapshot_in_data(tracks_data_update(), playlistref)


is_playlist_in_data(tracks_data::DataFrame, pl_ref::PlaylistRef) = is_playlist_in_data(tracks_data, pl_ref.id)

is_playlist_in_data(trackrefs_rw::DataFrameRow, pl_ref::PlaylistRef) = is_playlist_in_data(trackrefs_rw, pl_ref.id)

function is_playlist_in_data(tracks_data::DataFrame, pl_id::SpPlaylistId)
    isempty(tracks_data) && return false
    for c in eachcol(tracks_data[!, r"playlistref"])
        ! isnothing(findfirst(x -> x.id == pl_id, filter(! ismissing, c))) && return true
    end
    false
end
function is_playlist_in_data(trackrefs_rw::DataFrameRow, pl_id::SpPlaylistId)
    isempty(trackrefs_rw) && return false
    for c in trackrefs_rw[r"playlistref"]
        ! ismissing(c) && c.id == pl_id && return true
    end
    false
end

is_playlist_in_data(playlistref) = is_playlist_in_data(tracks_data_update(), playlistref)

function is_other_playlist_snapshot_in_data(tracks_data, pl_ref)
    is_playlist_in_data(tracks_data, pl_ref) && ! is_playlist_snapshot_in_data(tracks_data, pl_ref)
end
is_other_playlist_snapshot_in_data(playlistref) = is_other_playlist_snapshot_in_data(tracks_data_update(), playlistref)


is_track_in_data(trackrefs_rw::DataFrameRow, t::SpTrackId) = ! isempty(trackrefs_rw) && t == trackrefs_rw.trackid
is_track_in_data(tracks_data::DataFrame, t::SpTrackId) = ! isempty(tracks_data) && t ∈ tracks_data.trackid
is_track_in_data(track::TrackRef) = is_track_in_data(track.id)
is_track_in_data(trackid) = is_track_in_data(tracks_data_update(), trackid)

################################################
# Functions specific to using, not building data
################################################
"""
    is_track_in_track_data(t::SpTrackId, playlist_id::SpPlaylistId)-> Bool
    is_track_in_track_data(t::SpTrackId, playlist_id::SpPlaylistId, tracks_data)-> Bool
"""
function is_track_in_track_data(t::SpTrackId, playlist_id::SpPlaylistId)
    # TODO: fix either function name or the number of arguments.
    is_track_in_track_data(t, playlist_id, tracks_data_update())
end
function is_track_in_track_data(t::SpTrackId, playlist_id::SpPlaylistId, tracks_data)
    # TODO: Not a good name or argument list!
    td = subset(tracks_data, :trackid => ByRow(x -> x == t))
    is_playlist_in_data(td, playlist_id)
end

"""
    playlistrefs_containing_track(t::SpTrackId) ---> Vector{PlaylistRef}
    playlistrefs_containing_track(t::SpTrackId, tracks_data) ---> Vector{PlaylistRef}
"""
function playlistrefs_containing_track(t::SpTrackId)
    playlistrefs_containing_track(t, tracks_data_update())
end
function playlistrefs_containing_track(t::SpTrackId, tracks_data)
    td = subset(tracks_data, :trackid => ByRow(==(t)))
    refdata = td[!, r"playlistref"]
    dropmissing(stack(refdata, r"playlistref"))[!, 2]
end


function tracks_get_stored_or_api_audio_features(track_id)
    tracks_get_stored_or_api_audio_features(track_id, tracks_data_update())
end    
function tracks_get_stored_or_api_audio_features(track_id, tracks_data)
    rw = subset(tracks_data, :trackid => ByRow(==(track_id)))
    if nrow(rw) == 1
        features = first(rw)[wanted_feature_keys()]
        Dict{Symbol, Real}(propertynames(features) .=> values(features))
    else
        af = tracks_get_audio_features(track_id)[1]
        wf = filter(p-> typeof(p[2]) <: Real, af)
        wff = filter(p-> p[1] ∈ wanted_feature_keys(), wf)
        Dict{Symbol, Real}(wff)
    end
end

"""
    playlist_get_latest_ref_and_data(context::JSON3.Object)
    ---> (::PlaylistRef, ::DataFrame)
"""
function playlist_get_latest_ref_and_data(context::JSON3.Object)
    playlist_id = SpPlaylistId(context.uri)
    # Make sure we're looking at the latest version.
    json = playlist_get(playlist_id;fields="snapshot_id, name")[1]
    playlist_ref = PlaylistRef(json.name, json.snapshot_id, playlist_id)
    playlist_data = playlist_get_stored_audio_data(playlist_ref)
    if isempty(playlist_data)
        tracks_data_update(;forceupdate = true)
        playlist_data = playlist_get_stored_audio_data(playlist_ref)
        @assert ! isempty(playlist_data)
    end
    playlist_ref, playlist_data
end

"""
    playlist_get_audio_data(playlist_ref)
    ---> ::DataFrame
"""
function playlist_get_stored_audio_data(playlist_ref)
    tracks_data = tracks_data_update()
    playlist_get_stored_audio_data(playlist_ref, tracks_data)
end
function playlist_get_stored_audio_data(playlist_ref, tracks_data)
    crit(cell) = ismissing(cell) ? false : cell == playlist_ref
    columns = vcat([:trackid, :trackname], wanted_feature_keys())
    filter(row -> any(crit, row[r"playlistref"]), tracks_data)[!, columns]
end
