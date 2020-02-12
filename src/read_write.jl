write_size(io::IOStream, x::AbstractArray) = write(io, Int64.(size(x))...)
write_size(io::IOStream, x::AbstractString) = write(io, Int64(length(x)))

function read_size(io::IOStream, data::Type{A}) where {T,N,A<:AbstractArray{T,N}}
    ntuple(i -> read(io, Int64), Val(N))
end
read_size(io::IOStream, ::Type{String}) = read(io, Int64)

#---------------------------------------------------------------------------------------------------

function _write_str(io::IOStream, str::String)
    for s in str
        write(io, Char(s))
    end
end

"""
    write_str(io, str)

Write out an Int64 indicating length of string then the characters of the string
"""
function write_str(io::IOStream, str::String)
    write_size(io, str)
    _write_str(io, str)
    nothing
end

"""
    read_str(io, n::Int)

Read in `n` characters and return the combined String
"""
function read_str(io::IOStream, n::Int = read_size(io::IOStream, String))
    k = Vector{Char}(undef,n)
    @inbounds for i in 1:n
        k[i] = read(io, Char)
    end
    return join(k)
end

#---------------------------------------------------------------------------------------------------

function write_type(io::IOStream, data::BitArray)
    write_str(io, string(BitArray))
    write(io, Int64(ndims(data)))
end

function write_type(io::IOStream, data::AbstractArray)
    write_str(io, string(Array))
    write_str(io, string(eltype(data)))
    write(io, Int64(ndims(data)))
end

write_type(io::IOStream, x::AbstractString) = write_str(io, string(String))

read_type(io::IOStream, ::Type{BitArray}) = BitArray{read(io, Int64)}
read_type(io::IOStream, ::Type{Array}) = Array{TYPELOOKUP[read_str(io)], read(io,Int64)}
read_type(io::IOStream, ::Type{String}) = String
read_type(io::IOStream) = read_type(io, ARRAYLOOKUP[read_str(io)])

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

function _write(io::IOStream, label::String, str::AbstractString)
    write_endian(io)
    write_str(io, label)

    write_type(io, str)
    abfkey = AbfKey(io, str)
    write_str(io, str)

    return abfkey
end

function _read(io::IOStream, ::Type{String})
    abfkey = AbfKey(io, String)
    read_str(io)
    return abfkey
end

function _read(io::IOStream, type::Type{A}) where A<:AbstractArray
    dims = read_size(io, type)
    align(io, type)
    abfkey = AbfKey(io, type, dims)
    skip(io, _sizeof(type, dims))
    return abfkey
end

function _read(io::IOStream)
    endian = read_endian(io)
    label = read_str(io)

    type = read_type(io)
    abfkey = _read(io, type)
    return (label, abfkey)
end
