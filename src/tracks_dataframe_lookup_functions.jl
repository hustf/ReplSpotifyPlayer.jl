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


function is_playlist_in_data(tracks_data::DataFrame, pl_ref::PlaylistRef)
    isempty(tracks_data) && return false
    id = pl_ref.id
    for c in eachcol(tracks_data[!, r"playlistref"])
        ! isnothing(findfirst(x -> x.id == id, filter(! ismissing, c))) && return true
    end
    false
end
function is_playlist_in_data(trackrefs_rw::DataFrameRow, pl_ref::PlaylistRef)
    isempty(trackrefs_rw) && return false
    id = pl_ref.id
    for c in trackrefs_rw[r"playlistref"]
        ! ismissing(c) && c.id == id && return true
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

