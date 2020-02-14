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
                                  string(String) => String,
                                  string(DataType) => DataType)

const PREFIXES = ((1024.0^8, "Yi"),
                  (1024.0^7, "Zi"),
                  (1024.0^6, "Ei"),
                  (1024.0^5, "Pi"),
                  (1024.0^4, "Ti"),
                  (1024.0^3, "Gi"),
                  (1024.0^2, "Mi"),
                  (1024.0^1, "Ki"))

#---------------------------------------------------------------------------------------------------

## from https://github.com/JuliaLang/julia/blob/master/base/bitarray.jl (2020/01/20)
# notes: bits are stored in contiguous chunks
#        unused bits must always be set to 0
#
#    BitArray{N} <: AbstractArray{Bool, N}
# Space-efficient `N`-dimensional boolean array, using just one bit for each boolean value.
# `BitArray`s pack up to 64 values into every 8 bytes, resulting in an 8x space efficiency
# over `Array{Bool, N}` and allowing some operations to work on 64 values at once.
numbytes(x::BitArray) = 8*ceil(Int, length(x)/64)
numbytes(x::AbstractArray) = sizeof(eltype(x))*length(x)
numbytes(x::AbstractString) = length(x)*sizeof(Char)
numbytes(x) = sizeof(x)

numbytes(::Type{Array{T,N}}, dims::NTuple{N,Int64}) where {T,N} = prod(dims)*sizeof(T)
numbytes(::Type{BitArray{N}}, dims::NTuple{N,Int64}) where N = 8*ceil(Int, prod(dims)/64)

numchars(x::Int) = Int64(x/sizeof(Char))

#---------------------------------------------------------------------------------------------------

struct AbfSerializer{T}
    x::T
end

struct AbfDeserializer
    str::String
end

struct AbfKey
    pos::Int64
    T::Union{DataType, AbfDeserializer}
    shape::Tuple{Vararg{Int64}}
    nbytes::Int64

    function AbfKey(io::IOStream, T::DataType, shape::Tuple{Vararg{Int64}}, n::Int64)
        new(position(io), T, shape, n)
    end

    #-----------------------------------------------------------------------------------------------

    AbfKey(io::IOStream, x::T) where T<:BitArray = AbfKey(io, T, size(x), numbytes(x))
    AbfKey(io::IOStream, x::T) where T<:Array = AbfKey(io, T, size(x), numbytes(x))

    function AbfKey(io::IOStream, ::Type{A}, shape::Tuple{Vararg{Int64}}) where A<:AbstractArray
        AbfKey(io, A, shape, numbytes(A, shape))
    end

    #-----------------------------------------------------------------------------------------------

    AbfKey(io::IOStream, x::String) = AbfKey(io, String, (length(x),), numbytes(x))
    AbfKey(pos::Int64, x::String) = new(pos, String, (length(x),), numbytes(x))

    #-----------------------------------------------------------------------------------------------
    
    AbfKey(pos::Int64, T::Union{DataType,AbfSerializer}, nbytes::Int) = new(pos, T, (-1,), nbytes)
    AbfKey(pos::Int64, T::AbfDeserializer, nbytes::Int) = new(pos, T, (-1,), nbytes)
end
