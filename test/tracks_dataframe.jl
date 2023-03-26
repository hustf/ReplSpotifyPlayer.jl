using Test
using ReplSpotifyPlayer
using ReplSpotifyPlayer: TDF, SpTrackId, SpPlaylistId

@test !isempty(TDF[])

tr = TDF[].trackid[10]
tr_na = SpTrackId("1234567890123456789012")
pl_ref = TDF[].playlistref[10]
pl_ref_old = PlaylistRef(name = pl_ref.name, snapshot_id = "x", id = pl_ref.id)
plid_na = SpPlaylistId("1234567890123456789012")
pl_ref_na = PlaylistRef(name = "playlistname", snapshot_id = "x", id = plid_na)

@test is_track_in_data(tr)
@test ! is_track_in_data(tr_na)

@test is_playlist_snapshot_in_data(pl_ref)
@test ! is_playlist_snapshot_in_data(pl_ref_na)
@test ! is_playlist_snapshot_in_data(pl_ref_old)

@test is_playlist_in_data(pl_ref)
@test ! is_playlist_in_data(pl_ref_na)
@test is_playlist_in_data(pl_ref_old)


@test ! is_other_playlist_snapshot_in_data(pl_ref)
@test ! is_other_playlist_snapshot_in_data(pl_ref_na)
@test is_other_playlist_snapshot_in_data(pl_ref_old)



tdfe = DataFrame()

@test ! is_track_in_data(tdfe, tr)
@test ! is_track_in_data(tdfe, tr_na)

@test ! is_playlist_snapshot_in_data(tdfe, pl_ref)
@test ! is_playlist_snapshot_in_data(tdfe, pl_ref_na)
@test ! is_playlist_snapshot_in_data(tdfe, pl_ref_old)

@test ! is_playlist_in_data(tdfe, pl_ref)
@test ! is_playlist_in_data(tdfe, pl_ref_na)
@test ! is_playlist_in_data(tdfe, pl_ref_old)


@test ! is_other_playlist_snapshot_in_data(tdfe, pl_ref)
@test ! is_other_playlist_snapshot_in_data(tdfe, pl_ref_na)
@test ! is_other_playlist_snapshot_in_data(tdfe, pl_ref_old)


tdfr = view(TDF[], 10, :)

@test is_track_in_data(tdfr, tr)
@test ! is_track_in_data(tdfr, tr_na)

@test is_playlist_snapshot_in_data(tdfr, pl_ref)
@test ! is_playlist_snapshot_in_data(tdfr, pl_ref_na)
@test ! is_playlist_snapshot_in_data(tdfr, pl_ref_old)

@test is_playlist_in_data(tdfr, pl_ref)
@test ! is_playlist_in_data(tdfr, pl_ref_na)
@test is_playlist_in_data(tdfr, pl_ref_old)


@test ! is_other_playlist_snapshot_in_data(tdfr, pl_ref)
@test ! is_other_playlist_snapshot_in_data(tdfr, pl_ref_na)
@test is_other_playlist_snapshot_in_data(tdfr, pl_ref_old)

# Test writing and reading csv.

tdfc = DataFrame(trackid = [tr_na], playlistref = [pl_ref_na])
@test tdfc.trackid[1] == tr_na
@test tdfc.playlistref[1] == pl_ref_na

pth = mktempdir()
fpth = joinpath(pth, "dataframe_test.csv")
ReplSpotifyPlayer.save_tracks_data(tdfc; fpth )
tdfl = ReplSpotifyPlayer.load_tracks_data(;fpth)
@test tdfl.trackid[1] == tr_na
@test tdfl.playlistref[1] == pl_ref_na
