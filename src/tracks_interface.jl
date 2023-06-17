# This file wraps functions from Spotify.jl.
# Also prints tracks.

"""
    track_no_details_print(ioc, rw::DataFrameRow)
    track_no_details_print(ioc, track_name, track_id::SpTrackId)
"""
track_no_details_print(ioc, rw::DataFrameRow) = track_no_details_print(ioc, rw[:trackname], rw[:trackid])
function track_no_details_print(ioc, track_name, track_id::SpTrackId)
    print(color_set(ioc, 183), track_name)
    color_set(ioc)
    if get(ioc, :print_ids, false)
        print(ioc, "  ")
        show(ioc, MIME("text/plain"), track_id)
        color_set(ioc)
    end
end


"""
    get_audio_features_dic(trackid)
    ---> Dict
"""
function get_audio_features_dic(trackid)
    jsono, waitsec = tracks_get_audio_features(trackid)
    # wanted_feature_pair is a function
    filter(wanted_feature_pair, jsono)
end


"""
    get_multiple_tracks(track_ids)
    ---> Vector{JSON3.Object}

The web API used directly has a limit of 50 tracks.
"""
function get_multiple_tracks(track_ids)
    market = ""
    results = Vector{JSON3.Object}()
    for i in 1:50:length(track_ids)
        ie = min(i + 49, length(track_ids))
        trids = track_ids[i:ie]
        o = tracks_get_multiple(trids; market)[1]
        if length(o.tracks) !== ie - i + 1
            @error "Unexpected response " length(o.tracks) ie i
        end
        for tr in o.tracks
            push!(results, tr)
        end
    end
    @assert length(results) == length(track_ids)
    results
end
