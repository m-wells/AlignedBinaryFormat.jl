module AlignedBinaryFormat

using Printf
using Mmap
using Serialization

export abfopen, AbfSerializer

#---------------------------------------------------------------------------------------------------

const AbstractPrimitive = Union{AbstractFloat, Integer, AbstractChar}

struct AbfReadError <: Exception
    io::IOStream
end

function Base.showerror(io::IO, e::AbfReadError)
    print(io, "AbfReadError: isreadable(", e.io.name, ") = ", isreadable(e.io))
end

check_readable(io::IOStream) = isreadable(io) ? nothing : throw(AbfReadError(io))

struct AbfWriteError <: Exception
    io::IOStream
end

function Base.showerror(io::IO, e::AbfWriteError)
    print(io, "AbfWriteError: iswritable(", e.io.name, ") = ", iswritable(e.io))
end

#function Base.showerror(io::IO, e::AbfWriteError)
#    print(io, "iswritable(", e.io.name, ") = ", iswritable(e.io))
#end

check_writable(io::IOStream) = iswritable(io) ? nothing : throw(AbfWriteError(io))

#---------------------------------------------------------------------------------------------------

include("./abfkey.jl")
include("./endian.jl")
include("./read_write.jl")
include("./abffile.jl")
include("./showio.jl")

end
