using Test
push!(ENV, "SPOTIFY_NOINIT" => "true"); using ReplSpotifyPlayer
using ReplSpotifyPlayer: color_set, housekeeping_print, tracks_data_update
using ReplSpotifyPlayer: tracks_with_clones_data, nrow, prefer_adjacent_clone_over_current
using ReplSpotifyPlayer: suggest_and_make_compilation_to_album_change_print
using ReplSpotifyPlayer: get_all_search_result_track_objects, dataframe_from_search_objects
using ReplSpotifyPlayer: tracks_data_append_audio_features!


tracks_data = DataFrame()
ioc = color_set(IOContext(stdout, :print_ids => true), :green)
@test_throws ArgumentError housekeeping_print(ioc, tracks_data)

tracks_data = copy(tracks_data_update()[1:3, :])
clones_data = tracks_with_clones_data(tracks_data)
@test nrow(clones_data) == 0
tracks_data = copy(tracks_data_update()[1:800, :])
clones_data = tracks_with_clones_data(tracks_data)
@test nrow(clones_data) > 1  # The following tests won't work if no clones present
@test hasproperty(tracks_data, :available_markets)
@test hasproperty(clones_data, :available_markets)

# Now we depend on a pretty random and temporary state. If housekeeping
# has been run on all our playlists, this test will fail.
# Inspection of clones_data aid.
clones_data.available_markets
cur_row = clones_data[3, :]
adj_row = clones_data[4, :]
@test cur_row.available_markets isa String
@test adj_row.available_markets isa Missing
@test ! prefer_adjacent_clone_over_current(cur_row, adj_row)
@test prefer_adjacent_clone_over_current(adj_row, cur_row)

user_input = 'n'
track_in_compilation_data = sort(filter(:albumtype => ==("compilation"), tracks_data), :trackname)[19,:]
suggest_and_make_compilation_to_album_change_print(ioc, user_input, track_in_compilation_data, tracks_data)

# Requires user interaction
housekeeping_print(ioc, tracks_data)

# Prior to loose_market_criteria: 1420 tracks, 128 clones.
# After: 1248 tracks, 52 clones
