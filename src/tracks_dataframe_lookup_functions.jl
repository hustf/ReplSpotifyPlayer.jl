function is_playlist_snapshot_in_data(trackrefs_df::DataFrame, l::PlaylistRef)
    isempty(trackrefs_df) && return false
    for c in eachcol(trackrefs_df[!, r"playlistref"])
        l ∈ filter(! ismissing, c) && return true
    end
    false
end
function is_playlist_snapshot_in_data(trackrefs_rw::DataFrameRow, l::PlaylistRef)
    isempty(trackrefs_rw) && return false
    for c in trackrefs_rw[r"playlistref"]
        ! ismissing(c) && c == l && return true
    end
    false
end
is_playlist_snapshot_in_data(playlistref) = is_playlist_snapshot_in_data(TDF[], playlistref)


function is_playlist_in_data(trackrefs_df::DataFrame, l::PlaylistRef)
    isempty(trackrefs_df) && return false
    id = l.id
    for c in eachcol(trackrefs_df[!, r"playlistref"])
        ! isnothing(findfirst(x -> x.id == id, filter(! ismissing, c))) && return true
    end
    false
end
function is_playlist_in_data(trackrefs_rw::DataFrameRow, l::PlaylistRef)
    isempty(trackrefs_rw) && return false
    id = l.id
    for c in trackrefs_rw[r"playlistref"]
        ! ismissing(c) && c.id == id && return true
    end
    false
end

is_playlist_in_data(playlistref) = is_playlist_in_data(TDF[], playlistref)

function is_other_playlist_snapshot_in_data(trackrefs_df, l)
    is_playlist_in_data(trackrefs_df, l) && ! is_playlist_snapshot_in_data(trackrefs_df, l)
end
is_other_playlist_snapshot_in_data(playlistref) = is_other_playlist_snapshot_in_data(TDF[], playlistref)


is_track_in_data(trackrefs_rw::DataFrameRow, t::SpTrackId) = ! isempty(trackrefs_rw) && t == trackrefs_rw.trackid
is_track_in_data(trackrefs_df::DataFrame, t::SpTrackId) = ! isempty(trackrefs_df) && t ∈ trackrefs_df.trackid
is_track_in_data(track::TrackRef) = is_track_in_data(track.id)
is_track_in_data(trackid) = is_track_in_data(TDF[], trackid)

