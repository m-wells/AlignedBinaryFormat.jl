function print_bytes(io, x::Int)
    _first = true
    for (v,p) in PREFIXES
        if x ≥ v
            if _first
                @printf(io, "<%.1f", x/v)
            else
                @printf(io, "<%.1f", x/v)
            end
            return print(io, p, "B>")
        end
        _first = false
    end

    return @printf(io, "<%.0fB>", x)
end

function Base.show(io::IO, a::AbfKey)
    print(io, a.T)
    print(io, " ")
    if isa(a.T, DataType) && (a.T <: AbstractArray)
        print(io, "(")
        for i in a.shape
            print(io, i, ",")
        end
        print(io, ")")
    end
    print(io, " ")
    print_bytes(io, a.nbytes)
end

Base.show(io::IO, d::AbfDeserializer) = print(io, d.str)

function cpad(str, n::Int)
    nspace = (n - length(str))/2
    repeat(" ", floor(Int, nspace))*str*repeat(" ", ceil(Int, nspace))
end

function _rw(abf::AbfFile)
    isopen(abf.io) || return "[closed]"
    if isreadable(abf.io) && iswritable(abf.io)
        return "[read/write]"
    elseif isreadable(abf.io)
        return "[read]"
    elseif iswritable(abf.io)
        return "[write]"
    else
        return ""
    end
end

function tabline(io, items, padding::Vector{Int}, align=fill('r', length(items));
                 indent = "", left = "│ ", center = " │ ", right = " │")
    length(items) == length(padding) || error("!!!")
    n = length(items)
    print(io, indent, left)
    for i in 1:n
        if isa(items[i], Char)
            print(io, repeat(items[i], padding[i]))
        else
            if align[i] == 'l'
                print(io, lpad(items[i], padding[i]))
            elseif align[i] == 'c'
                print(io, cpad(items[i], padding[i]))
            elseif align[i] == 'r'
                print(io, rpad(items[i], padding[i]))
            else
                error("do not recognize alignment parameter ", align[i])
            end
        end

        i == n ? println(io, right) : print(io, center)
    end
end

function Base.show(io::IO, abf::T) where T<:AbfFile
    println(io, T, "(", _rw(abf), " ", abf.io.name, ")")

    colnames = ("label", "type", "shape", "bytes", "status")
    padding = [length.(colnames)...]
    
    for (k,abfkey) in abf.abfkeys
        padding[1] = max(padding[1], length(string(k)))
        padding[2] = max(padding[2], length(string(abfkey.T)))
        padding[3] = max(padding[3], length(string(abfkey.shape)))
        padding[4] = max(padding[4], length(sprint(print_bytes, abfkey.nbytes)))
        if k in keys(abf.loaded)
            padding[5] = max(padding[5], length("loaded"))
        else
            padding[5] = max(padding[5], length("not loaded"))
        end
    end

    indent = ""

    dashes = ('─','─','─','─','─')
    tabline(io, dashes, padding; indent = indent, left="┌─", center="─┬─", right="─┐")
    tabline(io, colnames, padding, fill('c', length(colnames)); indent = indent)
    tabline(io, dashes, padding; indent = indent, left="├─", center="─┼─", right="─┤")

    for (k,abfkey) in sort(collect(abf.abfkeys), by=first)
        if k in keys(abf.loaded)
            cols = (k, abfkey.T, abfkey.shape, sprint(print_bytes, abfkey.nbytes), "loaded")
        else
            cols = (k, abfkey.T, abfkey.shape, sprint(print_bytes, abfkey.nbytes), "unloaded")
        end
        tabline(io, cols, padding)
    end
    tabline(io, dashes, padding; indent = indent, left="└─", center="─┴─", right="─┘")
end

Base.show(io::IO, ::MIME"text/plain", abf::AbfFile) = show(io, abf)
