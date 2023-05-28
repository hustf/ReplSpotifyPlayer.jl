using Test
using ReplSpotifyPlayer
using ReplSpotifyPlayer: flatten, select, artist_details_print, artist_tracks_in_playlists_print, color_set
using ReplSpotifyPlayer: ncol, nrow, delete_the_last_and_missing_playlistref_columns!
using ReplSpotifyPlayer: flatten_horizontally_vector, unflatten_horizontally_vector, ByRow
using ReplSpotifyPlayer: transform!, transform, Not, select!, flatten
# We're creating a table for checking vs. the interactive 'm'
#@time extended_tracks_data = extend_data_with_artist_etc!(copy(TDF[]))  # 8.6s
tracks_data = copy(TDF[])
tracks_album_artist_playlists_data = select(tracks_data, :artists, :artist_ids,:trackid, :trackname, :albumtype, :album_name, :isrc, r"playlistref")
per_artist_data = flatten(tracks_album_artist_playlists_data, [:artists, :artist_ids])
artist_id = per_artist_data[1, :artist_ids]
# Drop other artists.
df = sort(filter(:artist_ids => ==(artist_id), per_artist_data), :trackname)
tracks_by_artist_data = filter(:artist_ids => ==(artist_id), per_artist_data)
nc = ncol(df)
nrow(df)
nrow(per_artist_data)
ncol(per_artist_data)
delete_the_last_and_missing_playlistref_columns!(df)
@test ncol(df) < nc
@test ncol(per_artist_data) == nc
nc = ncol(df)
transform!(df, r"playlistref"  => ByRow((cells...) -> filter(! ismissing, cells)) => :pl_refs)
@test ncol(df) > nc
nc = ncol(df)
select!(df, Not(r"playlistref"))
@test ncol(df) < nc
nr = nrow(df)
df = flatten(df, [:pl_refs])
@test nrow(df) > nr


df1 = transform(df, r"playlistref"  => ByRow((cells...) -> begin;println(typeof(cells));collect(cells);end) => :C)
df2 = transform(df, r"playlistref"  => ByRow((cells...) -> begin;println(typeof(cells));collect(filter(! ismissing, cells));end) => :playlistrefs)
df3 = transform(df, r"playlistref"  => ByRow((cells...) -> collect(filter(! ismissing, cells))) => :playlistrefs)
df4 = transform(df, r"playlistref"  => ByRow((cells...) -> filter(! ismissing, cells)) => :pl_refs)
df5 = select(df4, Not(r"playlistref"))
df6 = flatten(df5, [:pl_refs])
transform!(df, r"playlistref"  => ByRow((cells...) -> begin;println(typeof(cells));collect(cells);end) => :C)
transform!(df, [:A, :B]  => ByRow((A, B) -> string(A, ":", B)) => :C)

```
julia> filter(:artists => ==("Jake Shimabukuro"), per_artist_data)
3×11 DataFrame
 Row │ artists           artist_ids              trackid                 trackname                     albumtype  album_name      isrc          playlistref     ⋯
     │ String            SpArtistId              SpTrackId               String                        String15   String          String15      PlaylistRef?    ⋯
─────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
   1 │ Jake Shimabukuro  69NjH5MsRLr0CX0zSlGmN3  2kKIEaIu7Tod5CgR3cJlf4  Kawika                        album      Live In Japan   USKO11580391  PlaylistRef("83 ⋯
   2 │ Jake Shimabukuro  69NjH5MsRLr0CX0zSlGmN3  1EVCfgfWwBeGBZhe0XHOr2  While My Guitar Gently Weeps  album      Gently Weeps    JPN200600143  PlaylistRef("65  
   3 │ Jake Shimabukuro  69NjH5MsRLr0CX0zSlGmN3  5dOWg8hJmHIefgPFXSROJX  Winnie the Pooh               album      Ukulele Disney  USWD11263195  PlaylistRef("Gi  
```

###
# An artist from our playlists
artist_id = SpArtistId("3YxkGgMvqCQA75aFpy6524")
ioc = color_set(IOContext(stdout, :print_ids => true), :green)
@time artist_details_print(ioc, artist_id) # 0.11s -> 0.3s
color_set(ioc)

artist_tracks_in_playlists_print(ioc, artist_id);