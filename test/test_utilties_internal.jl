using Test
push!(ENV, "SPOTIFY_NOINIT" => "true"); using ReplSpotifyPlayer
using ReplSpotifyPlayer: semantic_equals, semantic_string
using ReplSpotifyPlayer: tracks_data_update, Cols,  ByRow, select, Not, select!, transform!, flatten, append!
using ReplSpotifyPlayer: rename!, semantic_contains, semantic_equals, summary_short_search_results_print
using ReplSpotifyPlayer: enumerated_track_album_artist_context_print, color_set, nrow
using ReplSpotifyPlayer: get_player_state, rhythmic_progress_print, tracks_get_audio_analysis, duration_sec

#################################
# semantic string equal, contains
#################################
dic  = Dict(
    "40 Alternative/Indie Pop-Rock Classics" => "The Tune Robbers Play Sweet Ballads Vol. 2",
    "The Tune Robbers Play Sweet Ballads Vol. 2" => "40 Alternative/Indie Pop-Rock Classics",
    "Mexican Sessions - Our Simple Sensational Sound" => "Mexican Sessions Our Simple Sensational Sound",
    "Mexican Sessions Our Simple Sensational Sound" => "Mexican Sessions - Our Simple Sensational Sound",
    "Cult" => "Amplified - A Decade Of Reinventing The Cello",
    "Amplified - A Decade Of Reinventing The Cello" => "Cult",
    "Cult" => "Amplified - A Decade Of Reinventing The Cello",
    "Reflections" => "Amplified - A Decade Of Reinventing The Cello",
    "Amplified - A Decade Of Reinventing The Cello" => "Reflections",
    "Rock'n'Raï" => "Tekitoi?",
    "Tekitoi?" => "Rock'n'Raï",
    "Carte Blanche" => "The Definitive Collection",
    "The Definitive Collection" => "Carte Blanche",
    "Ole Ole" => "The Definitive Collection",
    "The Definitive Collection" => "Ole Ole",
    "Rock'n'Raï" => "1,2,3, Soleils",
    "1,2,3, Soleils" => "Rock'n'Raï",
    "Extreme Ways (From The \"Bourne\" Film Series)" => "Extreme Ways (Jason Bourne)",
    "Extreme Ways (Jason Bourne)" => "Extreme Ways (From The \"Bourne\" Film Series)",
    "High Times: Singles 1992-2006" => "High Times - The Singles 1992 - 2006",
    "High Times - The Singles 1992 - 2006" => "High Times: Singles 1992-2006",
    "Come Find Yourself" => "A-sides, B-sides and Rarities",
    "A-sides, B-sides and Rarities" => "Come Find Yourself",
    "Last Train to Lhasa (Special Edition)" => "Last Train to Lhasa",
    "Last Train to Lhasa" => "Last Train to Lhasa (Special Edition)",
    "LemonJelly.ky" => "Lemon Jelly.ky",
    "Lemon Jelly.ky" => "LemonJelly.ky",
    "Mustt Mustt (Real World Gold)" => "Mustt Mustt",
    "Mustt Mustt" => "Mustt Mustt (Real World Gold)",
    "Forgetting to Remember" => "Forgetting To Remember",
    "Forgetting To Remember" => "Forgetting to Remember",
    "You All Look The Same To Me" => "You All Look the Same to Me",
    "You All Look the Same to Me" => "You All Look The Same To Me",
    "Greatest Movie Themes" => "Absolutely Movie Soundtracks",
    "Absolutely Movie Soundtracks" => "Greatest Movie Themes",
    "ジェントリー・ウィープス" => "Gently Weeps",
    "Gently Weeps" => "ジェントリー・ウィープス",
    "Lysrædd" => "Inn og bombe frøken ur",
    "Inn og bombe frøken ur" => "Lysrædd",
    "Run the Jewels 2" => "Run The Jewels 2",
    "Run The Jewels 2" => "Run the Jewels 2",
    "The Golden Hour" => "the Golden Hour",
    "the Golden Hour" => "The Golden Hour",
    "A Tribute to Glee Box Set: Season 1,Vol. 1" => "Jewelry Jams",
    "Jewelry Jams" => "A Tribute to Glee Box Set: Season 1,Vol. 1",
    "1000 Forms Of Fear (Deluxe Version)" => "1000 Forms Of Fear",
    "1000 Forms Of Fear" => "1000 Forms Of Fear (Deluxe Version)",
    "The Art of the Groove" => "\"ART OF THE GROOVE\" Music by Chick Corea, Leonard Bernstein, Michael Brecker and more",
    "\"ART OF THE GROOVE\" Music by Chick Corea, Leonard Bernstein, Michael Brecker and more" => "The Art of the Groove",
    "\$O\$" => "\$O\$ (International Deluxe Version)",
    "\$O\$ (International Deluxe Version)" => "\$O\$")

equaldic = Dict(
    "Lemon Jelly.ky" => "LemonJelly.ky",
    "The Golden Hour" => "the Golden Hour",
    "Run the Jewels 2" => "Run The Jewels 2",
    "LemonJelly.ky" => "Lemon Jelly.ky",
    "You All Look The Same To Me" => "You All Look the Same to Me",
    "Mexican Sessions - Our Simple Sensational Sound" => "Mexican Sessions Our Simple Sensational Sound",
    "Forgetting to Remember" => "Forgetting To Remember",
    "Mexican Sessions Our Simple Sensational Sound" => "Mexican Sessions - Our Simple Sensational Sound",
    "the Golden Hour" => "The Golden Hour",
    "You All Look the Same to Me" => "You All Look The Same To Me",
    "Run The Jewels 2" => "Run the Jewels 2",
    "Forgetting To Remember" => "Forgetting to Remember",
    )

eqdic = filter(p -> semantic_equals(p[1], p[2]), dic)
@test eqdic == equaldic

containdic = Dict("Lemon Jelly.ky" => "LemonJelly.ky",
    "The Golden Hour" => "the Golden Hour",
     "\$O\$ (International Deluxe Version)" => "\$O\$",
     "Mustt Mustt (Real World Gold)" => "Mustt Mustt",
     "the Golden Hour" => "The Golden Hour",
     "You All Look the Same to Me" => "You All Look The Same To Me",
     "Run the Jewels 2" => "Run The Jewels 2",
     "LemonJelly.ky" => "Lemon Jelly.ky",
     "Last Train to Lhasa (Special Edition)" => "Last Train to Lhasa",
     "You All Look The Same To Me" => "You All Look the Same to Me",
     "Run The Jewels 2" => "Run the Jewels 2",
     "Forgetting To Remember" => "Forgetting to Remember",
     "Mexican Sessions - Our Simple Sensational Sound" => "Mexican Sessions Our Simple Sensational Sound",
     "Forgetting to Remember" => "Forgetting To Remember",
     "Mexican Sessions Our Simple Sensational Sound" => "Mexican Sessions - Our Simple Sensational Sound",
     "1000 Forms Of Fear (Deluxe Version)" => "1000 Forms Of Fear")
codic = filter(p -> semantic_contains(p[1], p[2]), dic)
@test codic == containdic

#########################
# rhythmic_progress_print
#########################
    # Low-level. Beware, don't run until close to end of track. 
    # Stop disabled (keyword argument not included)!
ioc = color_set(IOContext(stdout, :print_ids => true), :green)
begin
    st = get_player_state(ioc)
    t_0 = time()
    progress_0 = st.progress_ms / 1000
    track_id = SpTrackId(st.item.uri)
    json, waitsec = tracks_get_audio_analysis(track_id);
    # Line width to use, all of it at full time
    nx = displaysize(ioc)[2] - 3 - 4 - 1
    # Map from time to column
    dur_s = json.beats[end].start + json.beats[end].duration
    column_no(t_passed) = t_passed < dur_s ? Int(floor(nx * t_passed / dur_s + 1)) : nothing
    current_column_no() = column_no(time() - t_0 + progress_0)
    # Map from time to beat no.
    beat_starts = [beat.start for beat in json.beats]
    beat_no(time_progress) = findlast(<=(time_progress), beat_starts)
    # Map from time to bar no.
    bar_starts = [bar.start for bar in json.bars]
    bar_no(time_progress) = findlast(<=(time_progress), bar_starts)
    beat_duration(time_progress) = time_progress < dur_s ? json.beats[beat_no(time_progress)][:duration] : nothing
    current_pausetime() = beat_duration(time() - t_0 + progress_0)
    current_beat_no() = beat_no(time() - t_0 + progress_0)
    current_bar_no() = bar_no(time() - t_0 + progress_0)
    rhythmic_progress_print(ioc, json, t_0, progress_0)
end

######################################
# enumerated_track_album_artist_context_print
######################################
tracks_data = tracks_data_update()
rw = tracks_data[1, :]
ioc = color_set(IOContext(stdout, :print_ids => true), :green)
enumerated_track_album_artist_context_print(ioc, rw);
begin
    enumerated_track_album_artist_context_print(ioc, rw; enumerated = "10");
    println(ioc)
    enumerated_track_album_artist_context_print(ioc, rw; enumerated = "11");
end;
rws = tracks_data[6:8, :]
# enumeration increases for each new track id
rng = enumerated_track_album_artist_context_print(ioc, rws; enumerator  = 10);
@test rng == 10:12
# We want to enumerate each context the track appears in.
# Collect all playlistref columns to a joined one.
transform!(rws, r"playlistref"  => ByRow((cells...) -> filter(! ismissing, cells)) => :pl_refs)
# Drop collected cols
select!(rws, Not(r"playlistref"))
# One playlist ref per row
rws1 = flatten(rws, [:pl_refs])
rename!(rws1, :pl_refs => :pl_ref)
rng1 = enumerated_track_album_artist_context_print(ioc, rws1; enumerator  = 10);
@test length(rng1) == nrow(rws1)
@test rng1 == 10:16




###############################
# search_then_select_print data
###############################
search_data = select(tracks_data, Cols(:trackname, :album_name, :artists, :release_date, :trackid, :album_id, :artist_ids, r"playlistref"))
transform!(search_data, r"playlistref"  => ByRow((cells...) -> filter(! ismissing, cells)) => :pl_refs)
select!(search_data, Not(r"playlistref"))
search_data1 = flatten(search_data, [:pl_refs])
rename!(search_data1, :pl_refs => :pl_ref)
df = flatten(search_data1, [:artists, :artist_ids])
rename!(df, :artists => :artist, :artist_ids => :artist_id)

q = "extreme"
trackname_hits = filter(:trackname => s -> semantic_contains(s, q), df)
@test nrow(trackname_hits) == 11
q = "Velvet gr"
albumname_hits = filter(:album_name => s -> semantic_contains(s, q), df)
@test nrow(albumname_hits) == 1
q = "Velvet"
artist_hits = filter(:artist =>  s -> semantic_contains(s, q), df)
@test nrow(artist_hits) == 1
q = "1965"
date_hits = filter(:release_date =>  s -> semantic_contains(s, q), df)
@test nrow(date_hits) == 1
q = "81"
playlist_hits_vector = unique(filter(:pl_ref =>  ref -> semantic_contains(ref.name, q), df)[!, :pl_ref])
@test length(playlist_hits_vector) == 1
hits = DataFrame()
append!(hits, trackname_hits)
append!(hits, albumname_hits)
append!(hits, artist_hits)
append!(hits, date_hits)
@test nrow(hits) == 14
summary_short_search_results_print(ioc, q, trackname_hits, albumname_hits, artist_hits, date_hits, hits, playlist_hits_vector)


# Furthermore, another search
q = "bond"
trackname_hits = filter(:trackname => s -> semantic_contains(s, q), df)
albumname_hits = filter(:album_name => s -> semantic_contains(s, q), df)
artist_hits = filter(:artist =>  s -> semantic_contains(s, q), df)
date_hits = filter(:release_date =>  s -> semantic_contains(s, q), df)
playlist_hits_vector = unique(filter(:pl_ref =>  ref -> semantic_contains(ref.name, q), df)[!, :pl_ref])
hits = DataFrame()
append!(hits, trackname_hits)
append!(hits, albumname_hits)
append!(hits, artist_hits)
append!(hits, date_hits)
summary_short_search_results_print(ioc, q, trackname_hits, albumname_hits, artist_hits, date_hits, hits, playlist_hits_vector)
enumerated_track_album_artist_context_print(ioc, hits)