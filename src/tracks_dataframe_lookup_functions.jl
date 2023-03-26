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
is_playlist_snapshot_in_data(playlistref) = is_playlist_snapshot_in_data(TDF[], playlistref)


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

is_playlist_in_data(playlistref) = is_playlist_in_data(TDF[], playlistref)

function is_other_playlist_snapshot_in_data(tracks_data, pl_ref)
    is_playlist_in_data(tracks_data, pl_ref) && ! is_playlist_snapshot_in_data(tracks_data, pl_ref)
end
is_other_playlist_snapshot_in_data(playlistref) = is_other_playlist_snapshot_in_data(TDF[], playlistref)


is_track_in_data(trackrefs_rw::DataFrameRow, t::SpTrackId) = ! isempty(trackrefs_rw) && t == trackrefs_rw.trackid
is_track_in_data(tracks_data::DataFrame, t::SpTrackId) = ! isempty(tracks_data) && t ∈ tracks_data.trackid
is_track_in_data(track::TrackRef) = is_track_in_data(track.id)
is_track_in_data(trackid) = is_track_in_data(TDF[], trackid)

################################################
# Functions specific to using, not building data
################################################
"""
    is_track_in_track_data(t::SpTrackId, playlist_id::SpPlaylistId)
        -> Bool
    
"""
function is_track_in_track_data(t::SpTrackId, playlist_id::SpPlaylistId)
    if isempty(TDF[])
        TDF[] = tracks_data_get(;silent = false)
    end
    tracks_data = TDF[]
    td = subset(tracks_data, :trackid => ByRow(x -> x == t))
    is_playlist_in_data(td, playlist_id)
end