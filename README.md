# AlignedBinaryFormat
[![Build Status](https://travis-ci.com/m-wells/AlignedBinaryFormat.jl.svg?branch=master)](https://travis-ci.com/m-wells/AlignedBinaryFormat.jl)
[![Coverage Status](https://coveralls.io/repos/github/m-wells/AlignedBinaryFormat.jl/badge.svg?branch=master)](https://coveralls.io/github/m-wells/AlignedBinaryFormat.jl?branch=master)
[![codecov](https://codecov.io/gh/m-wells/AlignedBinaryFormat.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/m-wells/AlignedBinaryFormat.jl)

This package provides a simple (yet powerful) interface to handle [memory mapped](https://docs.julialang.org/en/v1/stdlib/Mmap/#Memory-mapped-I/O-1) data.
The "data" must be in the form of `Array`s and `BitArray`s) (although I may later support a `Table` interface).
The `eltype` of the `Array` must be a [Julia primitive type](https://docs.julialang.org/en/v1/manual/types/#Primitive-Types-1).
When accessing the data we avoid the use of `reinterpret` by **aligning** the arrays on disk.
Writing `String`s to labels is also supported but these are not memory mapped (use `Vector{Char}` if you need this functionality.

## Usage Example


```julia
using AlignedBinaryFormat
temp = tempname();
```


```julia
# writing data out
abfopen(temp, "w") do abf   # "w" is used to write only, memory mapping requires w+
    write(abf, "my x array", rand(Float16,4))
    write(abf, "whY array", rand(Char,2,2,2))
    #close(abf)
end

# do block syntax is supported
abfopen(temp, "r+") do abf    # "r+" permits writing to an existing file
    abf["ζ!/b"] = rand(2,3)   # alias of write(abf,"ζ!/b",rand(2,3))
    write(abf, "bitmat", rand(3,2) .< 0.5)
    # can also save strings (although these are not memory mapped)
    #     use Vector{Char} for memory mapping
    write(abf, "log", """
        this is what I did
        and how!
        """)
end

abf = abfopen(temp, "r")
```




    AlignedBinaryFormat.AbfFile(r <file /tmp/jl_ZRUDdP>)
    ┌────────────┬────────────────────────┬────────────┐
    │   label    │          type          │   status   │
    ├────────────┼────────────────────────┼────────────┤
    │   bitmat   │   BitArray{2}(3, 2)    │ not loaded │
    │    log     │      String(28,)       │ not loaded │
    │ my x array │  Array{Float16,1}(4,)  │ not loaded │
    │ whY array  │ Array{Char,3}(2, 2, 2) │ not loaded │
    │    ζ!/b    │ Array{Float64,2}(2, 3) │ not loaded │
    └────────────┴────────────────────────┴────────────┘



The two methods for accessing the data are `read` and `getindex`, which is simply an alias of `read` and allows for the dictionary-like syntax.
When data is first accessed a reference to the item is cached in a dictionary contained within the `AbfFile` instance.
This permits the same reference to be returned without remapping the same data multiple times due to repeated `read` calls.
Strings are not memory mapped and are copied directly into the cache dictionary.


```julia
@show count(abf["bitmat"])
read(abf, "my x array")        # just calling read(abf, label) loads the array
println(read(abf, "log"))
show(abf)
```

    count(abf["bitmat"]) = 5
    this is what I did
    and how!
    
    AlignedBinaryFormat.AbfFile(r <file /tmp/jl_ZRUDdP>)
    ┌────────────┬────────────────────────┬────────────┐
    │   label    │          type          │   status   │
    ├────────────┼────────────────────────┼────────────┤
    │   bitmat   │   BitArray{2}(3, 2)    │   loaded   │
    │    log     │      String(28,)       │   loaded   │
    │ my x array │  Array{Float16,1}(4,)  │   loaded   │
    │ whY array  │ Array{Char,3}(2, 2, 2) │ not loaded │
    │    ζ!/b    │ Array{Float64,2}(2, 3) │ not loaded │
    └────────────┴────────────────────────┴────────────┘

In the example above, `bitmat` and `my x array` are memory mapped and `log` is cached.
Doing `abf["bitmat"]` or `read(abf, "bitmat")` will return the same reference to `bitmat`.


```julia
bitmat1 = abf["bitmat"]
bitmat2 = read(abf, "bitmat")
@show bitmat1 === bitmat2;
```

    bitmat1 === bitmat2 = true


## Close does not unlink references you may have made
Memory mapping persists after the file has been closed and is only unlinked once the reference is garbage collected.
It is recommended to use the **do-block** syntax to avoid unintended access.


```julia
abf = abfopen(temp, "w+")
write(abf, "x", rand(10))
x = read(abf, "x")
print("x = ")
show(stdout, MIME("text/plain"), x)
println("\n")
show(abf)
println("\n")
close(abf)
show(abf)
print("\nx = ")
show(stdout, MIME("text/plain"), x)
println("\n")
```

    x = 10-element Array{Float64,1}:
     0.8766317610545198  
     0.6018622110847007  
     0.11262697157468327 
     0.5516201293467733  
     0.25634887547005913 
     0.049131542030021125
     0.27887342636826573 
     0.537853459201793   
     0.600647015064192   
     0.18098735180440917 
    
    AlignedBinaryFormat.AbfFile(w+ <file /tmp/jl_ZRUDdP>)
    ┌───────┬───────────────────────┬────────┐
    │ label │         type          │ status │
    ├───────┼───────────────────────┼────────┤
    │   x   │ Array{Float64,1}(10,) │ loaded │
    └───────┴───────────────────────┴────────┘
    
    AlignedBinaryFormat.AbfFile(closed <file /tmp/jl_ZRUDdP>)
    ┌───────┬──────┬────────┐
    │ label │ type │ status │
    ├───────┼──────┼────────┤
    └───────┴──────┴────────┘
    x = 10-element Array{Float64,1}:
     0.8766317610545198  
     0.6018622110847007  
     0.11262697157468327 
     0.5516201293467733  
     0.25634887547005913 
     0.049131542030021125
     0.27887342636826573 
     0.537853459201793   
     0.600647015064192   
     0.18098735180440917 
    


# File permissions and modifying data on-disk

| mode | read data | modify data | add data | description                          |
|------|:---------:|:-----------:|:--------:|--------------------------------------|
| `r`  | yes       | no          | no       | read only mode                       |
| `r+` | yes       | yes         | yes      | read/write existing file             |
| `w`  | no        | no          | yes      | overwrites existing file, write only |
| `w+` | yes       | yes         | yes      | overwrites existing file, read/write |
| `a`  | no        | no          | yes      | modify existing file, create if it doesn't exist, write only |
| `a+` | yes       | yes         | yes      | modify existing file, create if it doesn't exist, read/write |

Read permission is required to memory map so `w` can only write data to the file but can not read it back in to memory-map.
Memory-mapped arrays opened using `r` can only be read.
If the file is opened with `r+/w+` arrays can be modified in place.


```julia
println("file opened with \"w\"")
abfopen(temp, "w") do abf
    write(abf, "x", rand(3,2))
    try
        x = read(abf, "x")
    catch e
        println(e.msg)
    end
end
println("\nfile opened with \"w+\"")
abfopen(temp, "w+") do abf
    write(abf, "x", rand(3,2))
    x = read(abf, "x")
    @show x[1]
    x[1] = -1
    @show x[1]
end
println("\nfile opened with \"r+\"")
abfopen(temp, "r+") do abf
    abf["x"][1] = 3
    @show abf["x"][1]
    write(abf, "y", rand(2))
    @show abf["y"]
end
println("\nfile opened with \"r\"")
abfopen(temp, "r") do abf
    x = read(abf, "x")
    @show x[1]
    @show abf["y"]
    try
        x[1] = 3
    catch e
        println(e)
    end
end;
println("\nfile opened with \"a\"")
abfopen(temp, "a") do abf
    try
        x = read(abf, "x")
    catch e
        println(e.msg)
    end
    write(abf, "z", rand(3))
end;
println("\nfile opened with \"a+\"")
abfopen(temp, "a+") do abf
    @show read(abf, "x")[1]
    @show read(abf, "z")[1]
end;
```

    file opened with "w"
    file is not readable, opened with: w
    
    file opened with "w+"
    x[1] = 0.3921332512881919
    x[1] = -1.0
    
    file opened with "r+"
    (abf["x"])[1] = 3.0
    abf["y"] = [0.3103104232481271, 0.8723026640351457]
    
    file opened with "r"
    x[1] = 3.0
    abf["y"] = [0.3103104232481271, 0.8723026640351457]
    ReadOnlyMemoryError()
    
    file opened with "a"
    file is not readable, opened with: a
    
    file opened with "a+"
    (read(abf, "x"))[1] = 3.0
    (read(abf, "z"))[1] = 0.11647360741323487


## Why not use `JLD/HDF5`?
 1. They do not support memory mapping of **any** Julia `isbits` primitive type (see [here for supported data types](https://github.com/JuliaIO/HDF5.jl/blob/master/doc/hdf5.md#supported-data-types)).
 2. When memory mapping they often return an array as a `ReinterpretArray` forcing the use of `AbstractArray` in `Type` and `Function` definitions.


```julia
x = rand(Float16,3,2);
y = x .< 0.5;
z = rand(29);
@show typeof(x);
@show typeof(y);
@show typeof(z);
```

    typeof(x) = Array{Float16,2}
    typeof(y) = BitArray{2}
    typeof(z) = Array{Float64,1}



```julia
using JLD, HDF5
jldopen(temp, "w"; mmaparrays=true) do j
    write(j,"x",x)
    write(j,"y",y)
    write(j,"z",z)
end
jldopen(temp, "r"; mmaparrays=true) do j
    @show ismmappable(j["x"])
    @show typeof(read(j,"x"))
    @show typeof(read(j,"y"))
    @show typeof(read(j,"z"))
end
rm(temp)
```

    ismmappable(j["x"]) = false
    typeof(read(j, "x")) = Array{Float16,2}
    typeof(read(j, "y")) = BitArray{2}
    typeof(read(j, "z")) = Base.ReinterpretArray{Float64,1,UInt8,Array{UInt8,1}}


As you can see `x::Matrix{Float16}` isn't able to be memory mapped and `z::Vector{Float64}` gets read back as `ReinterpretArray`

## Why not use `JLD2`
`JLD2` doesn't actually support memory mapping.
See my comment [here](https://github.com/JuliaIO/JLD2.jl/pull/176#issue-369260445).

---

# File Layout
As an example lets examine what the structure of the following file would look like.


```julia
abfopen(temp, "w+") do abf
    abf["myX"] = rand(Float16,10,3)
    abf["whybitarr"] = x .< 0.5
    abf["log"] = "some log information about this file"
    abf["somez"] = rand(29)
    show(abf)
end;
```

    AlignedBinaryFormat.AbfFile(w+ <file /tmp/jl_ZRUDdP>)
    ┌───────────┬─────────────────────────┬────────────┐
    │   label   │          type           │   status   │
    ├───────────┼─────────────────────────┼────────────┤
    │    log    │       String(36,)       │ not loaded │
    │    myX    │ Array{Float16,2}(10, 3) │ not loaded │
    │   somez   │  Array{Float64,1}(29,)  │ not loaded │
    │ whybitarr │    BitArray{2}(3, 2)    │ not loaded │
    └───────────┴─────────────────────────┴────────────┘

The file will have the following layout for each of the stored `Arrays`
* a `UInt8` indicating endian-ness of the numeric data contained within
    * `UInt8(0)` indicates that the following data is little-endian
    * `UInt8(255)` indicates that the following data is big-endian
    * this depends on the host machine generating the file
    * currently conversion between little- and big-endian is not supported
* an `Int` indicating the length of the key `length(keyname)`
* the `String` which is the `key` of the array
* an `Int` indicating the length of `string(T<:Union{Array,BitArray})`
* the `String` representation of the "container", i.e.,  `"Array"`, `"BitArray"` or `"String"`
    * there is no arbitrary code evaluation, types are determined via an `ImmutableDict{String,DataType}`
* for `"Array"`s an `Int` and `string(T)`
* an `Int` indication the number of dimensions `N`
* `N` `Int`s that give the shape of the array
* the buffer is then **aligned** to `T`
* the data

Note: the labels are displayed sorted by label but are written to the file sequentially.

```
<BOF> # beginning of file
0x00                            # UInt8(0) - Little Endian
3                               # length of "myX"
myX                             # label of first item
5                               # length of "Array"
Array
7                               # length of "Float16"
Float16
2                               # number of dimensions
10                              # length of dimension 1
3                               # length of dimension 2
... (alignment spacing)
<the data>
0x00                            # UInt8(0) - Little Endian
9                               # length of "whybitarr"
whybitarr                       # label of second item
8                               # length of "BitArray"
BitArray
2                               # number of dimensions
10                              # length of dimension 1
3                               # length of dimension 2
... (alignment spacing)
<the data>
0x00                            # UInt8(0) - Little Endian
3                               # length of "log"
log                             # label of third item
6                               # length of "String"
String
36                              # length of "some log information ..."
some log information ...
0x00                            # UInt8(0) - Little Endian
5                               # length of "somez"
somez                           # label of fourth item
5                               # length of "Array"
Array
7                               # length of "Float64"
Float64
1                               # number of dimensions
29                              # length of dimension 1
... (alignment spacing)
<the data>
<EOF> # end of file
```

# Acknowledgements
Early inspiration was drawn from [this gist](https://gist.github.com/dataPulverizer/3dc0af456a427aeb704a437e31299242).


```julia

```
