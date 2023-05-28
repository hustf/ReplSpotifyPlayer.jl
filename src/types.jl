# This file defines PlaylistRef and
# what's needed to persist the types
# while loading and saving .csv.

# DataFrames uses PrettyTables to show content. Which does not play well
# with our coloured Sp____Id types. We have to pretend black-and-white output.
# This could well be a PR to PrettyTables - the general case should be black and
# white, and a PR would only need to add the :color =>false keyword, not
# create an additional method.
# This extends / specializes on 'v::SpType':
function _render_text(
    ::Val{:print},
    io::IOContext,
    v::SpType;
    compact_printing::Bool = true,
    isstring::Bool = false,
    limit_printing::Bool = true,
    linebreaks::Bool = false
)
    # Create the context that will be used when rendering the cell. Notice that
    # the `IOBuffer` will be neglected.
    context = IOContext(
        io,
        :compact => compact_printing,
        :limit => limit_printing,
        :color => false
    )
    str = sprint(print, v; context = context)
    return _render_text(
        Val(:print),
        io,
        str;
        compact_printing = compact_printing,
        isstring = isstring,
        linebreaks = linebreaks
    )
end

@kwdef struct PlaylistRef
    name::String
    snapshot_id::String
    id::SpPlaylistId
end
function PlaylistRef(x::JSON3.Object)
    @assert x.type == "playlist"
    id = SpPlaylistId(x.id)
    snapshot_id = string(x.snapshot_id)
    name = string(x.name)
    PlaylistRef(;name, snapshot_id, id)
end
function PlaylistRef(x::DataFrameRow)
    id = SpPlaylistId(x.id)
    snapshot_id = string(x.snapshot_id)
    name = string(x.name)
    PlaylistRef(;name, snapshot_id, id)
end

# This is not directly parseable, as it should be,
# but easily readable.
# In the context of PrettyTables / Dataframes/ CSV,
# cell contexts are printed with another show method,
# without colors.
function show(io::IO, m::MIME"text/plain", x::PlaylistRef)
    show(io, m, x.name)
    show(io, m, x.id)
    show(io, m, x.snapshot_id)
end

# We define this because if not, DataFrames errors:
# julia> flatten(df, :playlistref)
# ERROR: MethodError: no method matching length(::PlaylistRef)
# ERROR: MethodError: no method matching iterate(::PlaylistRef)
# ERROR: MethodError: no method matching iterate(::PlaylistRef, ::Nothing)
length(::PlaylistRef) = 1
iterate(x::PlaylistRef) = (x, nothing)
iterate(::PlaylistRef, ::Any) = nothing
# We define these for the benefit of CSV.jl
tryparse(T::Type{SpTrackId}, s::String) = T(s)
tryparse(T::Type{SpAlbumId}, s::String) = T(s)
tryparse(T::Type{SpArtistId}, s::String) = T(s)

function tryparse(T::Type{PlaylistRef}, s::String)
    pref = "PlaylistRef"
    pref1 =  string(@__MODULE__ ) * "." * pref
    if ! (startswith(s,  pref1)  || startswith(s,  pref))
        throw("tryparse: Expected prefix $pref, got input: $s")
     end
     v = split(s[findfirst('(', s) + 2 : end - 1], "\", ")
     name = v[1]
     snapshot_id = v[2][2:end]
     id = SpPlaylistId(v[3])
     T(name, snapshot_id, id)
end
