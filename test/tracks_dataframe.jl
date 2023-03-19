using Test
using ReplSpotifyPlayer
using ReplSpotifyPlayer: TDF, SpTrackId, SpPlaylistId

@test !isempty(TDF[])

tr = TDF[].trackid[10]
tr_na = SpTrackId("1234567890123456789012")
l = TDF[].playlistref[10]
l_old = PlaylistRef(name = l.name, snapshot_id = "x", id = l.id)
plid_na = SpPlaylistId("1234567890123456789012")
l_na = PlaylistRef(name = "playlistname", snapshot_id = "x", id = plid_na)

@test is_track_in_data(tr)
@test ! is_track_in_data(tr_na)

@test is_playlist_snapshot_in_data(l)
@test ! is_playlist_snapshot_in_data(l_na)
@test ! is_playlist_snapshot_in_data(l_old)

@test is_playlist_in_data(l)
@test ! is_playlist_in_data(l_na)
@test is_playlist_in_data(l_old)


@test ! is_other_playlist_snapshot_in_data(l)
@test ! is_other_playlist_snapshot_in_data(l_na)
@test is_other_playlist_snapshot_in_data(l_old)



tdfe = DataFrame()

@test ! is_track_in_data(tdfe, tr)
@test ! is_track_in_data(tdfe, tr_na)

@test ! is_playlist_snapshot_in_data(tdfe, l)
@test ! is_playlist_snapshot_in_data(tdfe, l_na)
@test ! is_playlist_snapshot_in_data(tdfe, l_old)

@test ! is_playlist_in_data(tdfe, l)
@test ! is_playlist_in_data(tdfe, l_na)
@test ! is_playlist_in_data(tdfe, l_old)


@test ! is_other_playlist_snapshot_in_data(tdfe, l)
@test ! is_other_playlist_snapshot_in_data(tdfe, l_na)
@test ! is_other_playlist_snapshot_in_data(tdfe, l_old)


tdfr = view(TDF[], 10, :)

@test is_track_in_data(tdfr, tr)
@test ! is_track_in_data(tdfr, tr_na)

@test is_playlist_snapshot_in_data(tdfr, l)
@test ! is_playlist_snapshot_in_data(tdfr, l_na)
@test ! is_playlist_snapshot_in_data(tdfr, l_old)

@test is_playlist_in_data(tdfr, l)
@test ! is_playlist_in_data(tdfr, l_na)
@test is_playlist_in_data(tdfr, l_old)


@test ! is_other_playlist_snapshot_in_data(tdfr, l)
@test ! is_other_playlist_snapshot_in_data(tdfr, l_na)
@test is_other_playlist_snapshot_in_data(tdfr, l_old)

# Test writing and reading csv. Currently not OK after reading......

tdfc = DataFrame(trackid = [tr_na], playlistref = [l_na])
@test tdfc.trackid[1] == tr_na
@test tdfc.playlistref[1] == l_na

pth = mktempdir()
fpth = joinpath(pth, "dataframe_test.csv")
ReplSpotifyPlayer.save_tracks_data(tdfc; fpth ) # todo function name change
tdfl = ReplSpotifyPlayer.load_tracks_data(;fpth)
@test tdfl.trackid[1] == tr_na
@test tdfl.playlistref[1] == l_na