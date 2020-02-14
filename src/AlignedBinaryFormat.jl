module AlignedBinaryFormat

using Printf
using Mmap
using Serialization

export abfopen, Serialized

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

include("./abfkey.jl")
include("./endian.jl")
include("./read_write.jl")
include("./abffile.jl")
include("./showio.jl")

end
