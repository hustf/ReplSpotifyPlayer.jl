using Test
using ReplSpotifyPlayer
using ReplSpotifyPlayer: semantic_equals, semantic_string

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

testdic = filter(p -> semantic_equals(p[1], p[2]), dic)
@test testdic == equaldic

using ReplSpotifyPlayer: color_set, get_player_state, rhythmic_progress_print, tracks_get_audio_analysis, duration_sec

ioc = color_set(IOContext(stdout, :print_ids => true), :green)
st = get_player_state(ioc)
t_0 = time()
progress_0 = st.progress_ms / 1000
track_id = SpTrackId(st.item.uri)
json, waitsec = tracks_get_audio_analysis(track_id);
# Low-level. Beware, don't run until close to end of track. Stop disabled!
begin
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
    rhythmic_progress_print(ioc, current_column_no, current_pausetime, current_beat_no, current_bar_no)
end

# With stopping option...
rhythmic_progress_print(ioc, json, t_0, progress_0)


