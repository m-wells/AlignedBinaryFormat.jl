module AlignedBinaryFormat

using Mmap
using OrderedCollections: OrderedDict
using Printf
using Serialization

export abfopen, AbfSerializer

#===========================================================================================
AbfReadError
===========================================================================================#
struct AbfReadError <: Exception
    io::IOStream
end

function Base.showerror(io::IO, e::AbfReadError)
    print(io, "AbfReadError: isreadable(", e.io.name, ") = ", isreadable(e.io))
end

check_readable(io::IOStream) = isreadable(io) ? nothing : throw(AbfReadError(io))

#===========================================================================================
AbfWriteError
===========================================================================================#
struct AbfWriteError <: Exception
    io::IOStream
end

function Base.showerror(io::IO, e::AbfWriteError)
    print(io, "AbfWriteError: iswritable(", e.io.name, ") = ", iswritable(e.io))
end

check_writable(io::IOStream) = iswritable(io) ? nothing : throw(AbfWriteError(io))

#===========================================================================================
include
===========================================================================================#
include("./abfkey.jl")
include("./endian.jl")
include("./read_write.jl")
include("./abffile.jl")
include("./showio.jl")

end
