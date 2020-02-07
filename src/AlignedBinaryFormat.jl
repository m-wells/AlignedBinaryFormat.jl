module AlignedBinaryFormat
using Mmap

export abfopen

function ImmutableDict(x::Pair, ys::Vararg{Pair})
    d = Base.ImmutableDict(x)
    for y in ys
        d = Base.ImmutableDict(d, y)
    end
    return d
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

const ARRAYLOOKUP = ImmutableDict(string(Array) => Array,
                                  string(BitArray) => BitArray)

function write_str(io::IOStream, str::Vararg{String})
    for s in str
        write(io, Int64(length(s)))
        write(io, s)
    end
    nothing
end

function read_str(io::IOStream)
    n = read(io, Int64)
    k = Vector{Char}(undef,n)
    @inbounds for i in 1:n
        k[i] = read(io, Char)
    end
    return join(k)
end

const LIT_ENDIAN = 0x04030201
const BIG_ENDIAN = 0x01020304
const LIT_ENDIAN_STR = "LITTLE"
const BIG_ENDIAN_STR = "BIG   "

function machine_endian()
    Base.ENDIAN_BOM == LIT_ENDIAN && return LIT_ENDIAN_STR
    Base.ENDIAN_BOM == BIG_ENDIAN && return BIG_ENDIAN_STR
    error("ENDIAN_BOM of ", Base.ENDIAN_BOM, " not recognized")
end

function endian_bom(endian_str::String)
    endian_str == LIT_ENDIAN_STR && return LIT_ENDIAN
    endian_str == BIG_ENDIAN_STR && return BIG_ENDIAN
    error("ENDIAN_STR of ", endian_str, " not recognized")
end

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

#_sizeof(x::AbstractArray) = _sizeof(typeof(x), size(x))

struct AbfKey{N}
    pos::Int64
    T::DataType
    dims::NTuple{N,Int64}

    function AbfKey(io::IOStream, ::Type{A}, dims::NTuple{N,Int64}) where {T,N,A<:AbstractArray{T,N}}
        new{N}(position(io), A, dims)
    end

    function AbfKey(pos::Int64, x::A) where A<:AbstractArray
        new{ndims(A)}(pos, A, size(x))
    end
end

include("read_write.jl")

mutable struct AbfFile
    io::IOStream
    filename::String
    rw::String
    objs::Base.ImmutableDict{String,AbfKey}
    npos::Int64                                 # position of nobjects Int64

    function AbfFile(filename::String, rw::String)
        allowed_rw = ("r", "r+", "w", "w+")
        rw ∈ allowed_rw || error("Unrecognized option '", rw, "'\nAllowed options are [",
                                 join(allowed_rw, ", "), "] as (read permissions are needed to memory map)")
        objs=Base.ImmutableDict{String,AbfKey}()

        io = open(filename, rw)

        if rw ∈ ("w", "w+")
            endian = machine_endian()
            write_str(io, endian)
        else
            endian = read_str(io)
            if endian != machine_endian()
                error("file is encoded with different endianness than this machine\n",
                      "expected ", machine_endian(), " got ", endian)
            end
        end

        new(io, filename, rw, objs, position(io))
    end
end

function addabfkey!(abf::AbfFile, k::String, abfkey::AbfKey)
    abf.objs = Base.ImmutableDict(abf.objs, k => abfkey)
end

function abfopen(filename::String, rw::String)
    abf = AbfFile(filename, rw)
    if rw ∈ ("w", "w+")
        write(abf.io, Int64(0))     # zero objects in file
    else
        n = read(abf.io, Int64)
        for _ in 1:n
            k, abfkey = _read(abf.io)
            addabfkey!(abf, k, abfkey)
        end
    end
    return abf
end

Base.close(abf::AbfFile) = close(abf.io)

function abfopen(f::Function, args...)
    abf = abfopen(args...)

    try
        f(abf)
    finally
        close(abf)
    end
end

function Base.write(abf::AbfFile, k::String, x::AbstractArray)
    seekend(abf.io)
    abfkey = _write(abf.io::IOStream, k, x)
    addabfkey!(abf, k, abfkey)

    mark(abf.io)
    seek(abf.io, abf.npos)
    write(abf.io, length(abf.objs))
    reset(abf.io)
    nothing
end

function Base.read(abf::AbfFile, k::String)
    abfkey = abf.objs[k]
    seek(abf.io, abfkey.pos)
    Mmap.mmap(abf.io, abfkey.T, abfkey.dims)
end

end
