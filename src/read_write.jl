#-------------------------------------------------------------------------------------------
function write_type(io::IOStream, x::BitArray)
    write_str(io, string(BitArray))
    write(io, Int64(ndims(x)))
end

function write_type(io::IOStream, x::AbstractArray)
    write_str(io, string(Array), string(eltype(x)))
    write(io, Int64(ndims(x)))
end

write_type(io::IOStream, x::AbstractString) = write_str(io, string(String))

write_size(io::IOStream, x::AbstractArray) = write(io, Int64.(size(x))...)


read_type(io::IOStream, ::Type{BitArray}) = BitArray{read(io, Int64)}
read_type(io::IOStream, ::Type{Array}) = Array{TYPELOOKUP[read_str(io)], read(io,Int64)}
read_type(io::IOStream, ::Type{String}) = String
read_type(io::IOStream) = read_type(io, ARRAYLOOKUP[read_str(io)])

read_size(io::IOStream, x::Type{A}) where {T,N,A<:AbstractArray{T,N}} = ntuple(i -> read(io, Int64), Val(N))
read_size(io::IOStream, x::Type{String}) = (read(io, Int64),)

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

function _write(io::IOStream, k::String, x::A) where A<:Union{Array,BitArray}
    # label
    write_str(io, k)

    # data header
    write_type(io, x)
    write_size(io, x)

    # data
    align(io, x)
    abfkey = AbfKey(io, A, size(x))
    write(io, x)
    return abfkey
end

# everything but actually mmaping
# returns AbfKey
function _read(io::IOStream)
    k = read_str(io)
    A = read_type(io)
    dims = read_size(io, A)
    align(io, A)
    abfkey = AbfKey(io, A, dims)
    skip(io, _sizeof(A, dims))
    return (k, abfkey)
end

function _write(io::IOStream, k::String, x::AbstractString)
    write_str(io, k)
    write_type(io, x)
    abfkey = AbfKey(io, x)
    write_str(io, x)
    return abfkey
end
