mutable struct AbfFile
    io::IOStream
    rw::String
    abfkeys::Base.ImmutableDict{String,AbfKey}
    loaded::Base.ImmutableDict{String,Union{Array,BitArray,String}}

    function AbfFile(filename::String, rw::String)
        io = open(filename, rw)
        abfkeys=Base.ImmutableDict{String,AbfKey}()
        loaded=Base.ImmutableDict{String,Union{Array,BitArray,String}}()
        new(io, rw, abfkeys, loaded)
    end
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
            k, abfkey = _read(abf.io)
            addabfkey!(abf, k, abfkey)
        end
    end
    return abf
end

function Base.close(abf::AbfFile)
    abf.rw = "closed"
    abf.abfkeys = Base.ImmutableDict{String,AbfKey}()
    abf.loaded = Base.ImmutableDict{String,Union{Array,BitArray,String}}()
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
    seekend(abf.io)
    abfkey = _write(abf.io::IOStream, k, x)
    addabfkey!(abf, k, abfkey)
    nothing
end

function Base.read(abf::AbfFile, k::String)
    isreadable(abf.io) || error("file is not readable, opened with: ", abf.rw)
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

Base.getindex(abf::AbfFile, k::String) = read(abf, k)

function Base.setindex!(abf::AbfFile, v, k::String)
    if k ∈ keys(abf)
        error("cannot overwrite exists key. You may have wanted to do \"abf[", k,
              "] .= x\" instead (element assignment)")
    end
    write(abf, k, v)
end

#---------------------------------------------------------------------------------------------------

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

