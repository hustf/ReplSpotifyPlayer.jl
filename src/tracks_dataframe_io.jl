# This file concerns loading and saving tracks data between memory and file.

fullpath_trackrefs() = joinpath(homedir(), ".repl_player_tracks.csv")
save_tracks_data(tracks_data; fpth = fullpath_trackrefs()) = CSV.write(fpth, tracks_data)
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
