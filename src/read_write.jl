function write_type(io::IOStream, data::BitArray)
    write_str(io, string(BitArray))
    write(io, Int64(ndims(data)))
end

function write_type(io::IOStream, data::AbstractArray)
    write_str(io, string(Array), string(eltype(data)))
    write(io, Int64(ndims(data)))
end

write_type(io::IOStream, x::AbstractString) = write_str(io, string(String))

read_type(io::IOStream, ::Type{BitArray}) = BitArray{read(io, Int64)}
read_type(io::IOStream, ::Type{Array}) = Array{TYPELOOKUP[read_str(io)], read(io,Int64)}
read_type(io::IOStream, ::Type{String}) = String
read_type(io::IOStream) = read_type(io, ARRAYLOOKUP[read_str(io)])

#---------------------------------------------------------------------------------------------------

write_size(io::IOStream, x::AbstractArray) = write(io, Int64.(size(x))...)

function read_size(io::IOStream, data::Type{A}) where {T,N,A<:AbstractArray{T,N}}
    ntuple(i -> read(io, Int64), Val(N))
end
read_size(io::IOStream, str::Type{String}) = (read(io, Int64),)

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

function _write(io::IOStream, label::String, data::A) where A<:Union{Array,BitArray}
    write_endian(io)
    write_str(io, label)

    write_type(io, data)
    write_size(io, data)

    align(io, data)
    abfkey = AbfKey(io, A, size(data))
    write(io, data)
    return abfkey
end

# everything but actually mmaping
# returns AbfKey
function _read(io::IOStream)
    endian = read_endian(io)
    label = read_str(io)

    type = read_type(io)
    dims = read_size(io, type)

    align(io, type)
    abfkey = AbfKey(io, type, dims)
    skip(io, _sizeof(type, dims))
    return (label, abfkey)
end

function _write(io::IOStream, label::String, str::AbstractString)
    write_endian(io)
    write_str(io, label)

    write_type(io, str)

    abfkey = AbfKey(io, str)
    write_str(io, str)
    return abfkey
end
