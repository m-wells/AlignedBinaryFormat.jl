struct AbfFile <: AbstractDict{String, Any}
    io::IOStream
    abfkeys::OrderedDict{String, AbfKey}
    loaded::Dict{String, Any}

    function AbfFile(io::IOStream)
        abfkeys = OrderedDict{String, AbfKey}()
        loaded = Dict{String, Any}()
        new(io, abfkeys, loaded)
    end
end

AbfFile(filename::String, rw::String) = AbfFile(open(filename, rw))

function Base.in(k::String, v::Base.KeySet{String, AbfFile})
    abf = v.dict
    in(k, keys(getfield(abf, :abfkeys)))
end

function addabfkey!(abf::AbfFile, k::String, abfkey::AbfKey)
    k ∈ keys(abf) && error("key of \"", k, "\" already exists in file!")
    abf.abfkeys[k] = abfkey
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
    empty!(abf.abfkeys)
    empty!(abf.loaded)
    close(abf.io)
end

function abfopen(f::Function, args...)
    abf = abfopen(args...)
    try f(abf)
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
    elseif isa(abfkey.T, AbfDeserializer)
        x = getfield(deserialize(abf.io), :x)
    else
        x = Mmap.mmap(abf.io, abfkey.T, abfkey.shape)
    end
    abf.loaded[k] = x
    return x
end

Base.getindex(abf::AbfFile, k::String) = read(abf, k)
Base.length(abf::AbfFile) = length(abf.abfkeys)

function Base.iterate(abf::AbfFile, state = 1)
    next = iterate(abf.abfkeys, state)
    isnothing(next) && return nothing
    (key, _), next_state = next
    return key => abf[key], next_state
end

function Base.setindex!(abf::AbfFile, v, k::String)
    k ∈ keys(abf) && error(
        "cannot overwrite existing key. You may have wanted to do \"abf[",
        k,
        "] .= x\" instead (element assignment)",
    )
    write(abf, k, v)
end
