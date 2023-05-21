using Test
using ReplSpotifyPlayer
using ReplSpotifyPlayer: flatten, select, artist_details_print, artist_tracks_in_data_print

# We're creating a table for checking vs. the interactive 'm'
#@time extended_tracks_data = extend_data_with_artist_etc!(copy(TDF[]))  # 8.6s
tracks_data = copy(TDF[])
tracks_album_artist_playlists_data = select(tracks_data, :artists, :artist_ids,:trackid, :trackname, :albumtype, :album_name, :isrc, r"playlistref")
per_artist_data = flatten(tracks_album_artist_playlists_data, [:artists, :artist_ids])
tracks_by_artist_data = filter(:artist_ids => ==(artist_id), per_artist_data)
length(unique(tracks_by_artist_data.isrc))


```
julia> filter(:artists => ==("Jake Shimabukuro"), artist_data)
5×8 DataFrame
 Row │ artists           trackid                 trackname                         albumtype  album_name          playlistref                        playlistref_1                      playlistref_2
     │ Any               SpTrackId               String                            String15   String?             PlaylistRef?                       PlaylistRef?                       PlaylistRef?
─────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
   1 │ Jake Shimabukuro  1EVCfgfWwBeGBZhe0XHOr2  While My Guitar Gently Weeps      album      Gently Weeps        PlaylistRef("BONGO BONG And Je N…  PlaylistRef("Gitar", "MzksYmM5OD…  PlaylistRef("65-66spm", "MTQsYTI…
   2 │ Jake Shimabukuro  2kKIEaIu7Tod5CgR3cJlf4  Kawika                            album      Live In Japan       PlaylistRef("83-84spm", "MzksMDB…  PlaylistRef("Gitar", "MzksYmM5OD…  missing
   3 │ Jake Shimabukuro  6ON53mDxYs9q89tjLex8GR  Bohemian Rhapsody - Live Version  album      Peace Love Ukulele  PlaylistRef("Gitar", "MzksYmM5OD…  missing                            missing
   4 │ Jake Shimabukuro  15u1Z8cfzRxvog9ol0PDAY  Lazy Jane                         album      Gently Weeps        PlaylistRef("Gitar", "MzksYmM5OD…  missing                            missing
   5 │ Jake Shimabukuro  5dOWg8hJmHIefgPFXSROJX  Winnie the Pooh                   album      Ukulele Disney      PlaylistRef("Gitar", "MzksYmM5OD…  missing                            missing
```
# We did not find 'While My Guitar Gently Weeps' and two others. Why?
track_id = SpTrackId("1EVCfgfWwBeGBZhe0XHOr2") #While My Guitar Gently Weeps
artist_id = SpArtistId("69NjH5MsRLr0CX0zSlGmN3")

# Even the widest album search does not return the album. We tried with different countries, too.
ana, aid = artist_get_all_albums(artist_id; include_groups = "");
"Gently Weeps" ∈ ana

# We won't find it in Spotify's app, either, by starting with the artist. But by playing
# a track from it, we can go to the album and check the context:
```
julia>
e : exit.     f(→) : forward.     b(←) : back.     p: pause, play.     0-9:  seek.
del(fn + ⌫  ) : delete track from playlist. c : context. m : musician. g : genres.
i : toggle ids. r : rhythm test. a : audio features. h : housekeeping. ? : syntax.
Sort then select  t : by typicality.  o : other features.  ↑ : previous selection.
  Wish On My Star \ Gently Weeps \ Jake Shimabukuro  spotify:track:1TOy77zOYk2FlHTWPUiYH3
 ◍ >c  Gently Weeps  release date: 2006  label: HITCHHIKE RECORDS  tracks: 17  spotify:album:0TDr4j9Q3cQY7GtJNFyC2h
```
album_id = SpAlbumId("spotify:album:0TDr4j9Q3cQY7GtJNFyC2h")
```
julia> album_get_single(album_id)[1]
JSON3.Object{Base.CodeUnits{UInt8, String}, Vector{UInt64}} with 20 entries:
  :album_group            => "album"
  :album_type             => "album"
  :artists                => Object[{…
  :available_markets      => Union{}[]
  :copyrights             => Union{}[]
```



###
# An artist from our playlists
artist_id = SpArtistId("3YxkGgMvqCQA75aFpy6524")
ioc = color_set(IOContext(stdout, :print_ids => true), :green)
@time artist_details_print(ioc, artist_id) # 0.11s
color_set(ioc)

artist_tracks_in_data_print(ioc, artist_id)