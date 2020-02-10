mutable struct AbfFile
    io::IOStream
    rw::String
    abfkeys::Base.ImmutableDict{String,AbfKey}
    loaded::Base.ImmutableDict{String,Union{Array,BitArray,String}}
    npos::Int64                                 # position of nobjects Int64

    function AbfFile(filename::String, rw::String)
        allowed_rw = ("r", "r+", "w", "w+")
        rw ∈ allowed_rw || error("Unrecognized option '", rw, "'\nAllowed options are [",
                                 join(allowed_rw, ", "), "] as (read permissions are needed to memory map)")
        abfkeys=Base.ImmutableDict{String,AbfKey}()
        loaded=Base.ImmutableDict{String,Union{Array,BitArray,String}}()

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

        new(io, rw, abfkeys, loaded, position(io))
    end
end

Base.keys(abf::AbfFile) = keys(abf.abfkeys)

function addabfkey!(abf::AbfFile, k::String, abfkey::AbfKey)
    k ∈ keys(abf) && error("key of \"", k, "\" already exists in file!")
    abf.abfkeys = Base.ImmutableDict(abf.abfkeys, k => abfkey)
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

function Base.write(abf::AbfFile, k::String, x)
    seekend(abf.io)
    abfkey = _write(abf.io::IOStream, k, x)
    addabfkey!(abf, k, abfkey)

    mark(abf.io)
    seek(abf.io, abf.npos)
    write(abf.io, length(abf.abfkeys))
    reset(abf.io)
    nothing
end

function Base.read(abf::AbfFile, k::String)
    k ∈ keys(abf.loaded) && return abf.loaded[k]
    abfkey = abf.abfkeys[k]
    seek(abf.io, abfkey.pos)
    if abfkey.T == String
        x = read_str(abf.io, first(abfkey.dims))
    else
        x = Mmap.mmap(abf.io, abfkey.T, abfkey.dims)
    end
    abf.loaded = Base.ImmutableDict(abf.loaded, k => x)
    return x
end

function cpad(str, n::Int)
    nspace = (n - length(str))/2
    repeat(" ", floor(Int, nspace))*str*repeat(" ", ceil(Int, nspace))
end

function Base.show(io::IO, abf::T) where T<:AbfFile
    println(io, T, "(", abf.rw, " ", abf.io.name, ")")

    ktitle = "label"
    ttitle = "type"
    ltitle = "status"
    keypad = length(ktitle)
    typepad = length(ttitle)
    loadpad = length(ltitle)
    
    for (k,t) in abf.abfkeys
        keypad = max(keypad, length(string(k)))
        typepad = max(typepad, length(string(t)))
        if k in keys(abf.loaded)
            loadpad = max(loadpad, length("loaded"))
        else
            loadpad = max(loadpad, length("not loaded"))
        end
    end

    indent = ""

    println(io, indent, "┌─", repeat('─', keypad) , "─┬─", repeat('─', typepad),  "─┬─", repeat('─', loadpad),  "─┐")
    println(io, indent, "│ ", cpad(ktitle, keypad), " │ ", cpad(ttitle, typepad), " │ ", cpad(ltitle, loadpad), " │")
    println(io, indent, "├─", repeat('─', keypad) , "─┼─", repeat('─', typepad),  "─┼─", repeat('─', loadpad),  "─┤")

    for (k,t) in sort(collect(abf.abfkeys), by=first)
        print(io,indent, "│ ", cpad(k, keypad), " │ ", cpad(string(t), typepad), " │ ")
        if k in keys(abf.loaded)
            println(io, cpad("loaded", loadpad), " │")
        else
            println(io, cpad("not loaded", loadpad), " │")
        end
    end
    print(io, indent, "└─", repeat('─', keypad) , "─┴─", repeat('─', typepad),  "─┴─", repeat('─', loadpad),  "─┘")
end

Base.getindex(abf::AbfFile, k::String) = read(abf, k)

function Base.setindex!(abf::AbfFile, v, k::String)
    if k ∈ keys(abf)
        error("cannot overwrite exists key. You may have wanted to do \"abf[", k,
              "] .= x\" instead (element assignment)")
    end
    write(abf, k, v)
end
