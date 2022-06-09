write_dims(io::IOStream, x::AbstractArray) = write_or_err(io, Int64.(size(x))...)
write_dims(io::IOStream, x::AbstractString) = write_or_err(io, Int64(length(x)))

function read_dims(io::IOStream, data::Type{A}) where {T,N,A<:AbstractArray{T,N}}
    ntuple(i -> read(io, Int64), Val(N))
end
read_dims(io::IOStream, ::Type{String}) = read(io, Int64)

write_numbytes(io::IOStream, x) = write_or_err(io, Int64(numbytes(x)))

_sizeof(x) = sizeof(x)
_sizeof(x::Char) = sizeof(string(x))
function write_or_err(io, x)
    nx = _sizeof(x)
    n = write(io, x)
    nx == n || throw("Failed to write $nx-byte representation of $(summary(x)) to $io ($n bytes written).")
end
function write_or_err(io, xs...)
    for x in xs
        write_or_err(io, x)
    end
end

#---------------------------------------------------------------------------------------------------

function write_str(io::IOStream, str::String)
    write_numbytes(io, str)
    for char in str
        write_or_err(io, char)
    end
end

"""
    read_str(io, nbytes::Int)

Read in `nbytes` worth of characters and return the combined String
"""
function read_str(io::IOStream)
    nbytes = read(io, Int64)
    n = numchars(nbytes)
    k = Vector{Char}(undef,n)
    @inbounds for i in 1:n
        k[i] = read(io, Char)
    end
    return join(k)
end

#---------------------------------------------------------------------------------------------------

function write_type(io::IOStream, data::BitArray{N}) where N
    s = "BitArray{"*string(N)*"}"
    write_str(io, s)
end

function write_type(io::IOStream, data::Array{T,N}) where {T,N}
    s = "Array{"*TYPE2STR_LOOKUP[T]*","*string(N)*"}"
    write_str(io, s)
end

write_type(io::IOStream, x::AbstractString) = write_str(io, "String")
write_type(io::IOStream, x::DataType) = write_str(io, "DataType")
function write_type(io::IOStream, x::AbfSerializer{T}) where T
    write_str(io, "AbfSerializer{"*string(T)*'}')
end

#read_type(io::IOStream, ::Type{BitArray}) = BitArray{read(io, Int64)}
#read_type(io::IOStream, ::Type{Array}) = Array{TYPELOOKUP[read_str(io)], read(io,Int64)}
#read_type(io::IOStream, ::Type{T}) where T = T
#read_type(io::IOStream) = read_type(io, ARRAYLOOKUP[read_str(io)])
function parse_type_array(x::String)
    a,t,n = split(x, r"[{,}]"; keepempty=false)
    a == "Array" || error("expected Array got ", a)
    T = TYPELOOKUP[t]
    N = parse(Int,n)
    return Array{T,N}
end

function parse_type_bitarray(x::String)
    a,n = split(x, r"[{,}]"; keepempty=false)
    a == "BitArray" || error("expected BitArray got ", a)
    N = parse(Int,n)
    return BitArray{N}
end

function parse_type_serialized(x::String)
    # +1 for the { and } characters
    t = chop(x, head = length(string(AbfSerializer))+1, tail = 1)
    return AbfDeserializer(t)
end

function read_type(io::IOStream)
    x = read_str(io)
    occursin(r"^Array", x) && return parse_type_array(x)
    occursin(r"^BitArray", x) && return parse_type_bitarray(x)
    x == "String" && return String
    x == "DataType" && return DataType
    occursin(r"^AbfSerializer", x) && return parse_type_serialized(x)
    error("the following type is not recognized: ", x)
end

#---------------------------------------------------------------------------------------------------

function write_header(io::IOStream, label::String, x)
    write_endian(io)
    write_str(io, label)
    write_type(io, x)
    nothing
end

function read_header(io::IOStream)
    endian = read_endian(io)
    label = read_str(io)
    type = read_type(io)
    return (label, type)
end

#---------------------------------------------------------------------------------------------------

"""
    nbytes is the number of bytes to align too
"""
function align(io::IOStream, nbytes::Int)
    pos = position(io)
    aligned_pos = nbytes*ceil(Int, pos/nbytes)  # essentially rounding up to next multiple 
    seek(io, aligned_pos)
end
# from https://github.com/JuliaLang/julia/blob/master/base/bitarray.jl (2020/01/20)
# notes: bits are stored in contiguous chunks
#        unused bits must always be set to 0
#
#    BitArray{N} <: AbstractArray{Bool, N}
# Space-efficient `N`-dimensional boolean array, using just one bit for each boolean value.
# `BitArray`s pack up to 64 values into every 8 bytes, resulting in an 8x space efficiency
# over `Array{Bool, N}` and allowing some operations to work on 64 values at once.
align(io::IOStream, ::Type{A}) where A<:BitArray = align(io, 8)
align(io::IOStream, ::Type{A}) where {T,A<:Array{T}} = align(io, sizeof(T))
align(io::IOStream, ::Type{String}) = nothing
align(io::IOStream, ::A) where A<:AbstractArray = align(io,A)

#---------------------------------------------------------------------------------------------------

function _abfwrite(io::IOStream, data::Union{Array,BitArray})
    write_dims(io, data)
    align(io, data)
    abfkey = AbfKey(io, data)
    write_or_err(io, data)
    return abfkey
end

function _abfread(io::IOStream, type::Type{A}) where A<:AbstractArray
    dims = read_dims(io, type)
    align(io, type)
    abfkey = AbfKey(io, type, dims)
    skip(io, abfkey.nbytes)
    return abfkey
end

#---------------------------------------------------------------------------------------------------

function _abfwrite(io::IOStream, str::AbstractString)
    abfkey = AbfKey(io, str)
    write_str(io, str)
    return abfkey
end

function _abfread(io::IOStream, ::Type{String})
    pos = position(io)
    str = read_str(io)
    return AbfKey(pos, str)
end

#---------------------------------------------------------------------------------------------------

function _abfwrite(io::IOStream, T::Union{DataType,AbfSerializer})
    mark(io)
    write_or_err(io, -1)
    pos = position(io)
    serialize(io, T)
    abfkey = AbfKey(pos, typeof(T), position(io) - pos)
    reset(io)
    write_or_err(io, abfkey.nbytes)
    skip(io, abfkey.nbytes)
    abfkey
end

function _abfread(io::IOStream, T::Union{Type{DataType}, AbfDeserializer})
    n = read(io, Int64)
    pos = position(io)
    skip(io, n)
    AbfKey(pos, T, n)
end

#---------------------------------------------------------------------------------------------------

function abfwrite(io::IOStream, label::String, x)
    write_header(io, label, x)
    abfkey = _abfwrite(io, x)
    return abfkey
end

function abfread(io::IOStream)
    label, type = read_header(io)
    abfkey = _abfread(io, type)
    return (label, abfkey)
end

#---------------------------------------------------------------------------------------------------

#function abfserialize(io::IOStream, label::String, x::T) where T
#    pos = position(io)
#    abfkey = 
#end
#
#function abfdeserialize(io::IOStream, label::String, x)
#end
