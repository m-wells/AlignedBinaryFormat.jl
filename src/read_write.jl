#-------------------------------------------------------------------------------------------
_write_type(io::IOStream, x::BitArray) = write_str(io, string(BitArray))
_write_type(io::IOStream, x::AbstractArray) = write_str(io, string(Array), string(eltype(x)))

function write_type_and_size(io::IOStream, x::AbstractArray)
    _write_type(io, x)
    N = ndims(x)
    write(io, Int64(N))
    for s in size(x)
        write(io, Int64(s))
    end
    nothing
end

function read_type_and_size(io::IOStream)
    a = ARRAYLOOKUP[read_str(io)]
    if a == BitArray
        N = read(io, Int64)
        A = BitArray{N}
    elseif a == Array
        T = TYPELOOKUP[read_str(io)]
        N = read(io, Int64)
        A = Array{T,N}
    else
        error("unknown arr_type: ", a)
    end

    dims = ntuple(i -> read(io, Int64), Val(N))
    return (A, dims)
end


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
align(io::IOStream, ::A) where A<:AbstractArray = align(io,A)

# returns AbfKey
function _write(io::IOStream, k::String, x::A) where A<:Union{Array,BitArray}
    write_str(io, k)
    write_type_and_size(io, x)
    align(io, x)
    abfkey = AbfKey(io, A, size(x))
        #arr = Mmap.mmap(io, A, size(x))
        #copyto!(arr, x)
        #skip(io, sizeof(arr))
    write(io, x)
    return abfkey
end

# everything but actually mmaping
# returns AbfKey
function _read(io::IOStream)
    k = read_str(io)
    A, dims = read_type_and_size(io)
    align(io, A)
    abfkey = AbfKey(io, A, dims)
    skip(io, _sizeof(A, dims))
    return (k, abfkey)
end

#function Base.read(abf::AbfFile, k::String)
#    abfkey = AbfKey(position(abf.io), x)
#    addabfkey!(abf, k, abfkey)
#
#    write_key(abf.io, k)
#
#    write_type(abf.io, x)
#
#    align(abf.io, x)
#    arr = Mmap.mmap(abf.io, A, size(x))
#    copyto!(arr, x)
#    skip(abf.io, sizeof(arr))
#end
