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

function Base.show(io::IO, abf::T) where T<:AbfFile
    println(io, T, "(", _rw(abf), " ", abf.io.name, ")")

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
        print(io,indent, "│ ", rpad(k, keypad), " │ ", rpad(string(t), typepad), " │ ")
        if k in keys(abf.loaded)
            println(io, cpad("loaded", loadpad), " │")
        else
            println(io, cpad("not loaded", loadpad), " │")
        end
    end
    print(io, indent, "└─", repeat('─', keypad) , "─┴─", repeat('─', typepad),  "─┴─", repeat('─', loadpad),  "─┘")
end

