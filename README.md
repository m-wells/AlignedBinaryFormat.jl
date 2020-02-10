# AlignedBinaryFormat
[![Build Status](https://travis-ci.com/m-wells/AlignedBinaryFormat.jl.svg?branch=master)](https://travis-ci.com/m-wells/AlignedBinaryFormat.jl)
[![Coverage Status](https://coveralls.io/repos/github/m-wells/AlignedBinaryFormat.jl/badge.svg?branch=master)](https://coveralls.io/github/m-wells/AlignedBinaryFormat.jl?branch=master)
[![codecov](https://codecov.io/gh/m-wells/AlignedBinaryFormat.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/m-wells/AlignedBinaryFormat.jl)

This package provides a simple (yet powerful) interface allowing data (in the form of `Arrays/BitArrays`) to be saved in a simple binary format that can be "memory-mapped" without the use of `reinterpret`.
This is achieved by aligning the arrays on disk.

## Usage Example


```julia
using AlignedBinaryFormat
temp = tempname()
abf = abfopen(temp, "w")
write(abf, "my x array", rand(Float16,4))
write(abf, "whY array", rand(Char,2,2,2))
close(abf)

# do block syntax is supported
abfopen(temp, "r+") do abf                 # can append to an already created file
    abf["ζ!/b"] = rand(2,3)                # alias of write(abf,"ζ!/b",rand(2,3))
    write(abf, "bitmat", rand(3,2) .< 0.5)
    # can also save strings (although these are not memory mapped), use Vector{Char} for memory mapping
    write(abf, "log", """
        this is what I did
        and how!
        """)
end

abf = abfopen(temp, "r")
```




    AlignedBinaryFormat.AbfFile(r <file /tmp/jl_0PtmzN>)
    ┌────────────┬────────────────────────┬────────────┐
    │   label    │          type          │   status   │
    ├────────────┼────────────────────────┼────────────┤
    │   bitmat   │   BitArray{2}(3, 2)    │ not loaded │
    │    log     │      String(28,)       │ not loaded │
    │ my x array │  Array{Float16,1}(4,)  │ not loaded │
    │ whY array  │ Array{Char,3}(2, 2, 2) │ not loaded │
    │    ζ!/b    │ Array{Float64,2}(2, 3) │ not loaded │
    └────────────┴────────────────────────┴────────────┘



Using either `read(abf, <label>)` or the `getindex` (which is an alias to `read`) syntax of `abf[<label>]` will load the item stored.
Loading a `String` copies the `String` into the dictionary while loading `Array`s or `BitArray`s memory map them and store the references in a dictionary within the `AbfFile` structure.


```julia
@show count(abf["bitmat"])
read(abf, "my x array")        # just calling read(abf, label) loads the array
println(read(abf, "log"))
show(abf)
```

    count(abf["bitmat"]) = 4
    this is what I did
    and how!
    
    AlignedBinaryFormat.AbfFile(r <file /tmp/jl_0PtmzN>)
    ┌────────────┬────────────────────────┬────────────┐
    │   label    │          type          │   status   │
    ├────────────┼────────────────────────┼────────────┤
    │   bitmat   │   BitArray{2}(3, 2)    │   loaded   │
    │    log     │      String(28,)       │   loaded   │
    │ my x array │  Array{Float16,1}(4,)  │   loaded   │
    │ whY array  │ Array{Char,3}(2, 2, 2) │ not loaded │
    │    ζ!/b    │ Array{Float64,2}(2, 3) │ not loaded │
    └────────────┴────────────────────────┴────────────┘

Multiple calls to `read` (or `getindex`) will not remap already loaded arrays but will retrieve the reference from the stored dictionary.

### Modify data on disk
If you want to modify data on disk in place you must provide read and write permission `"r+/w+"`


```julia
abfopen(temp, "w+") do abf
    write(abf, "x", rand(3,2))
    x = read(abf, "x")
    print("x = ")
    show(stdout, MIME("text/plain"), x)
    println("\n")
end
abfopen(temp, "r+") do abf
    x = read(abf, "x")
    x[1] = -10
    print("x = ")
    show(stdout, MIME("text/plain"), x)
end
```

    x = 3×2 Array{Float64,2}:
     0.729037  0.435165
     0.564481  0.159203
     0.814773  0.959416
    
    x = 3×2 Array{Float64,2}:
     -10.0       0.435165
       0.564481  0.159203
       0.814773  0.959416

### You can verify that it actually wrote this to disk


```julia
abfopen(temp, "r") do abf
    x = read(abf, "x")
    print("x = ")
    show(stdout, MIME("text/plain"), x)
end
```

    x = 3×2 Array{Float64,2}:
     -10.0       0.435165
       0.564481  0.159203
       0.814773  0.959416

## Why not use `JLD/HDF5`?
 1. They do not support memory mapping of any Julia `isbits` primitive type (see [here for supported data types](https://github.com/JuliaIO/HDF5.jl/blob/master/doc/hdf5.md#supported-data-types)).
 2. When memory mapping they can often return an array as a `ReinterpretArray` forcing the use of `AbstractArray` in `Type` and `Function` definitions.


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


As you can see `x` isn't able to be memory mapped and `z` gets read back as `ReinterpretArray`

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

    AlignedBinaryFormat.AbfFile(w+ <file /tmp/jl_0PtmzN>)
    ┌───────────┬─────────────────────────┬────────────┐
    │   label   │          type           │   status   │
    ├───────────┼─────────────────────────┼────────────┤
    │    log    │       String(36,)       │ not loaded │
    │    myX    │ Array{Float16,2}(10, 3) │ not loaded │
    │   somez   │  Array{Float64,1}(29,)  │ not loaded │
    │ whybitarr │    BitArray{2}(3, 2)    │ not loaded │
    └───────────┴─────────────────────────┴────────────┘

The file will have the following layout
* 6 characters (`Char`) indicating endian-ness of the numeric data contained within
    * `"LITTLE"` or `"BIG   "` (this depends on the host machine generating the file, currently conversion between little and big is not supported)
For each of the stored `Arrays`
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
LITTLE
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
9                               # length of "whybitarr"
whybitarr                       # label of second item
8                               # length of "BitArray"
BitArray
2                               # number of dimensions
10                              # length of dimension 1
3                               # length of dimension 2
... (alignment spacing)
<the data>
3                               # length of "log"
log                             # label of third item
6                               # length of "String"
String
36                              # length of "some log information ..."
some log information ...
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
