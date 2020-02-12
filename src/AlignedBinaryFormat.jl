module AlignedBinaryFormat
using Mmap

export abfopen

#---------------------------------------------------------------------------------------------------

struct ReadOnlyError <: Exception
    io::IOStream
end

function Base.showerror(io::IO, e::ReadOnlyError)
    print(io, "isreadable(", e.io.name, ") = ", isreadable(io))
end

check_readable(io::IOStream) = isreadable(io) || throw(ReadOnlyError(io))

struct WriteOnlyError <: Exception
    io::IOStream
end

function Base.showerror(io::IO, e::WriteOnlyError)
    print(io, "iswritable(", e.io.name, ") = ", iswritable(io))
end

check_writable(io::IOStream) = iswritable(io) || throw(WriteOnlyError(io))

#---------------------------------------------------------------------------------------------------

function ImmutableDict(x::Pair, ys::Vararg{Pair})
    d = Base.ImmutableDict(x)
    for y in ys
        d = Base.ImmutableDict(d, y)
    end
    return d
end

function ImmutableDict(x::Base.ImmutableDict{String}, ys::Vararg{Pair})
    for y in ys
        x = Base.ImmutableDict(x, y)
    end
    return x
end

# this is used to avoid evaluation of arbitrary code read from a file
#TODO maybe do this programatically?
const TYPELOOKUP = ImmutableDict(string(Float16) => Float16,
                                 string(Float32) => Float32,
                                 string(Float64) => Float64,
                                 string(Bool) => Bool,
                                 string(Char) => Char,
                                 string(Int8) => Int8,
                                 string(UInt8) => UInt8,
                                 string(Int16) => Int16,
                                 string(UInt16) => UInt16,
                                 string(Int32) => Int32,
                                 string(UInt32) => UInt32,
                                 string(Int64) => Int64,
                                 string(UInt64) => UInt64,
                                 string(Int128) => Int128,
                                 string(UInt128) => UInt128)

const ARRAYLOOKUP = ImmutableDict(Base.ImmutableDict{String,Any}(),
                                  string(Array) => Array,
                                  string(BitArray) => BitArray,
                                  string(String) => String)

#---------------------------------------------------------------------------------------------------

## from https://github.com/JuliaLang/julia/blob/master/base/bitarray.jl (2020/01/20)
# notes: bits are stored in contiguous chunks
#        unused bits must always be set to 0
#
#    BitArray{N} <: AbstractArray{Bool, N}
# Space-efficient `N`-dimensional boolean array, using just one bit for each boolean value.
# `BitArray`s pack up to 64 values into every 8 bytes, resulting in an 8x space efficiency
# over `Array{Bool, N}` and allowing some operations to work on 64 values at once.
function _sizeof(::Type{BitArray{N}}, sz::NTuple{N,Int64}) where N
    len = prod(sz)
    8*ceil(Int, len/64)
end

_sizeof(::Type{A}, sz::NTuple{N,Int64}) where {T,N,A<:AbstractArray{T,N}} = sizeof(T)*prod(sz)
_sizeof(::Type{String}, n::Int64) = sizeof(Char)*n
_sizeof(s::String) = length(s)*sizeof(Char)

#---------------------------------------------------------------------------------------------------

struct AbfKey{N}
    pos::Int64
    T::DataType
    dims::NTuple{N,Int64}

    # used when writing
    AbfKey(pos::Int64, x::A) where A<:AbstractArray = new{ndims(A)}(pos, A, size(x))
    AbfKey(io::IOStream, x::AbstractString) = new{1}(position(io), String, (1,))

    # used when reading
    AbfKey(io::IOStream, ::Type{A}, dims::NTuple{N,Int64}
          ) where {T,N,A<:AbstractArray{T,N}} = new{N}(position(io), A, dims)
    AbfKey(io::IOStream, ::Type{String}) = new{1}(position(io), String, (1,))
end

Base.show(io::IO, a::AbfKey) = print(io, a.T, a.dims)

#---------------------------------------------------------------------------------------------------

include("./endian.jl")
include("./read_write.jl")
include("./abffile.jl")
include("./showio.jl")

end
