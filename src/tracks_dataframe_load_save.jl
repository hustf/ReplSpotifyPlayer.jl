# This file concerns loading and saving tracks data between memory and file.

fullpath_trackrefs() = joinpath(homedir(), ".repl_player_tracks.csv")
function flatten_horizontally_vector(tracks_data, propnam::Symbol)
    df = copy(tracks_data)
    nr = nrow(df)
    for i = 1:nr
        v = df[i, propnam]
        @assert v isa Vector
        nc = length(v)
        for j = 1:nc
            colnam = Symbol("$(propnam)_$j")
            if ! hasproperty(df, colnam)
                ve = repeat([missing], nr)
                df[!, colnam] = Vector{Union{Missing, eltype(v)}}(ve)
            end
            df[i, colnam] = v[j]
        end
    end
    select!(df, Not(propnam))
end
function unflatten_horizontally_vector(loaded_data, propnam::Symbol)
    df = copy(loaded_data)
    nr = nrow(df)
    colns = names(df)
    T = String
    v = Vector{Union{Missing, T}}()
    for i = 1:nr
        for (nam, col) in zip(colns, eachcol(df))
            if startswith(nam, string(propnam))
                if isempty(v)
                    T = typeof(first(col))
                    v = Vector{T}()
                end
                x = df[i, nam]
                ! ismissing(x) && push!(v, x)
            end
        end # col
        if ! isempty(v)
            if ! hasproperty(df, propnam)
                ve = repeat([empty(v)], nr)
                df[!, propnam] = ve
            end
            df[i, propnam] = v
        end
        v = empty(v)
    end
    removenames = [sy for (sy, st) in zip(propertynames(df), colns) if startswith(st, string(propnam) * "_")]
    select!(df, Not(removenames))
    df
end
function save_tracks_data(tracks_data; fpth = fullpath_trackrefs())
    df1 = hasproperty(tracks_data, :artists) ? flatten_horizontally_vector(tracks_data, :artists) : tracks_data
    df2 = hasproperty(tracks_data, :artist_ids) ? flatten_horizontally_vector(df1, :artist_ids) : df1
    CSV.write(fpth, df2)
    println(stdout, "\nSaving.")
end
save_tracks_data(; fpth = fullpath_trackrefs()) = save_tracks_data(TDF[]; fpth )


function _loadtypes(i, propsymb)
    if propsymb == :trackid
        SpTrackId
    elseif propsymb == :album_id
        SpAlbumId
    elseif startswith(string(propsymb), "playlistref")
        Union{PlaylistRef, Missing}
    elseif propsymb == :isrc
        InlineStrings.String15
    elseif startswith(string(propsymb), "artist_ids_")
        Union{SpArtistId, Missing}
    else
        nothing
    end
end
function load_tracks_data(;fpth = fullpath_trackrefs())
    if isfile(fpth)
        df0 = DataFrame(CSV.File(fpth; types = _loadtypes))
        df1 = hasproperty(df0, :artists_1) ? unflatten_horizontally_vector(df0, :artists) : df0
        hasproperty(df0, :artist_ids_1) ? unflatten_horizontally_vector(df1, :artist_ids) : df1
    else
        DataFrame()
    end
end
