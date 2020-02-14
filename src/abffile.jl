mutable struct AbfFile
    io::IOStream
    abfkeys::Base.ImmutableDict{String,AbfKey}
    loaded::Base.ImmutableDict{String,Any}
    #loaded::Base.ImmutableDict{String,Union{Array,BitArray,String}}

    function AbfFile(io::IOStream)
        abfkeys=Base.ImmutableDict{String,AbfKey}()
        loaded=Base.ImmutableDict{String,Any}()
        new(io, abfkeys, loaded)
    end

    AbfFile(filename::String, rw::String) = AbfFile(open(filename, rw))
end

Base.keys(abf::AbfFile) = keys(abf.abfkeys)

function addabfkey!(abf::AbfFile, k::String, abfkey::AbfKey)
    k ∈ keys(abf) && error("key of \"", k, "\" already exists in file!")
    abf.abfkeys = Base.ImmutableDict(abf.abfkeys, k => abfkey)
end

function abfopen(filename::String, rw::String)
    abf = AbfFile(filename, rw)
    if isreadable(abf.io)
        seekstart(abf.io)
        while !eof(abf.io)
            k, abfkey = abfread(abf.io)
            addabfkey!(abf, k, abfkey)
        end
    end
    return abf
end

function Base.close(abf::AbfFile)
    abf.abfkeys = Base.ImmutableDict{String,AbfKey}()
    abf.loaded = Base.ImmutableDict{String,Any}()
    close(abf.io)
end

function abfopen(f::Function, args...)
    abf = abfopen(args...)

    try
        f(abf)
    finally
        close(abf)
    end
end

function Base.write(abf::AbfFile, k::String, x)
    check_writable(abf.io)
    seekend(abf.io)
    abfkey = abfwrite(abf.io::IOStream, k, x)
    addabfkey!(abf, k, abfkey)
    nothing
end

function Base.read(abf::AbfFile, k::String)
    check_readable(abf.io)
    k ∈ keys(abf.loaded) && return abf.loaded[k]
    abfkey = abf.abfkeys[k]
    seek(abf.io, abfkey.pos)
    if abfkey.T == String
        x = read_str(abf.io)
    elseif abfkey.T == DataType
        x = deserialize(abf.io)
    elseif isa(abfkey.T, Deserialized)
        x = getfield(deserialize(abf.io), :x)
    else
        x = Mmap.mmap(abf.io, abfkey.T, abfkey.shape)
    end
    abf.loaded = Base.ImmutableDict(abf.loaded, k => x)
    return x
end

Base.getindex(abf::AbfFile, k::String) = read(abf, k)

function Base.setindex!(abf::AbfFile, v, k::String)
    if k ∈ keys(abf)
        error("cannot overwrite existing key. You may have wanted to do \"abf[", k,
              "] .= x\" instead (element assignment)")
    end
    write(abf, k, v)
end
