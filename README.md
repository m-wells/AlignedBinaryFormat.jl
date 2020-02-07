# AlignedBinaryFormat
[![Build Status](https://travis-ci.com/m-wells/AlignedBinaryFormat.jl.svg?branch=master)](https://travis-ci.com/m-wells/AlignedBinaryFormat.jl)
[![Coverage Status](https://coveralls.io/repos/github/m-wells/AlignedBinaryFormat.jl/badge.svg?branch=master)](https://coveralls.io/github/m-wells/AlignedBinaryFormat.jl?branch=master)
[![codecov](https://codecov.io/gh/m-wells/AlignedBinaryFormat.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/m-wells/AlignedBinaryFormat.jl)

This package provides a simple (yet powerful) interface allowing data (in the form of `Arrays/BitArrays`) to be saved in a simple binary format that can be "memory-mapped" without the use of `reinterpret`.
This is achieved by aligning the arrays on disk.

## Examples
```
julia> using AlignedBinaryFormat

julia> temp = tempname()*".abf";

julia> x = rand(Float16,5)
5-element Array{Float16,1}:
 0.8955
 0.01855
 0.293
 0.0
 0.4912

julia> y = rand(Char,3,3,3)
3×3×3 Array{Char,3}:
[:, :, 1] =
 '\U96860'  '\Ud14b6'  '\Uc6d65'
 '\Ub3835'  '\U68ab5'  '\Uaa2e6'
 '𑀿'        '\U488c1'  '\Uad6d6'

[:, :, 2] =
 '\U7d113'  '𑀨'        '\U52a26'
 '\Uee4df'  '\U6539d'  '\U6f827'
 '\U13fb5'  '\U5ad2a'  '\U2fd8b'

[:, :, 3] =
 '\U623d5'  '\U16bd4'  '\Ue7eec'
 '\U96515'  '\U9b53a'  '\U45be2'
 '\U6d337'  '\U8e767'  '\U72090'

julia> z = rand(3,5)
3×5 Array{Float64,2}:
 0.913549  0.358208  0.961378  0.5539    0.603976
 0.248744  0.58022   0.643398  0.49535   0.457585
 0.190859  0.884004  0.130671  0.456976  0.366796

julia> ba = rand(3,5) .< 0.5
3×5 BitArray{2}:
 0  0  1  1  1
 1  1  0  0  0
 1  0  1  0  1

julia> abfopen(temp, "w") do abf
       write(abf, "my x array", x)
       write(abf, "whY array", y)
       write(abf, "ζ!/b", z)
       write(abf, "bitmat", ba)
       end

julia> abf = abfopen(temp, "r")
AlignedBinaryFormat.AbfFile(IOStream(<file /tmp/jl_TfVT18.abf>), "/tmp/jl_TfVT18.abf", "r", Base.ImmutableDict{String,AlignedBinaryFormat.AbfKey}("bitmat" => AlignedBinaryFormat.AbfKey{2}(520, BitArray{2}, (3, 5)),"ζ!/b" => AlignedBinaryFormat.AbfKey{2}(344, Array{Float64,2}, (3, 5)),"whY array" => AlignedBinaryFormat.AbfKey{3}(168, Array{Char,3}, (3, 3, 3)),"my x array" => AlignedBinaryFormat.AbfKey{1}(84, Array{Float16,1}, (5,))), 14)

julia> read(abf, "bitmat")
3×5 BitArray{2}:
 0  0  1  1  1
 1  1  0  0  0
 1  0  1  0  1

julia> read(abf, "whY array")
3×3×3 Array{Char,3}:
[:, :, 1] =
 '\U96860'  '\Ud14b6'  '\Uc6d65'
 '\Ub3835'  '\U68ab5'  '\Uaa2e6'
 '𑀿'        '\U488c1'  '\Uad6d6'

[:, :, 2] =
 '\U7d113'  '𑀨'        '\U52a26'
 '\Uee4df'  '\U6539d'  '\U6f827'
 '\U13fb5'  '\U5ad2a'  '\U2fd8b'

[:, :, 3] =
 '\U623d5'  '\U16bd4'  '\Ue7eec'
 '\U96515'  '\U9b53a'  '\U45be2'
 '\U6d337'  '\U8e767'  '\U72090'

julia> read(abf, "ζ!/b")
3×5 Array{Float64,2}:
 0.913549  0.358208  0.961378  0.5539    0.603976
 0.248744  0.58022   0.643398  0.49535   0.457585
 0.190859  0.884004  0.130671  0.456976  0.366796

julia> read(abf, "my x array")
5-element Array{Float16,1}:
 0.8955
 0.01855
 0.293
 0.0
 0.4912

julia> close(abf)
```

## Modify data on disk
If you want to modify data on disk in place you must provide read and write permission `"r+/w+"`
```
julia> abf = abfopen(temp, "w+")
AlignedBinaryFormat.AbfFile(IOStream(<file /tmp/jl_9LiLfO>), "/tmp/jl_9LiLfO", "w+", Base.ImmutableDict{String,AlignedBinaryFormat.AbfKey}(), 14)

julia> write(abf, "x", rand(10,5))

julia> x = read(abf, "x")
10×5 Array{Float64,2}:
 0.54849    0.165274  0.247298  0.309551  0.932243
 0.126986   0.843627  0.713371  0.415387  0.223799
 0.781115   0.402192  0.900288  0.38551   0.739652
 0.675185   0.828027  0.820174  0.305257  0.27004
 0.854511   0.957022  0.267321  0.488723  0.267576
 0.239777   0.380612  0.348398  0.75667   0.0980679
 0.0981943  0.322747  0.311123  0.409337  0.621242
 0.595097   0.797594  0.870286  0.499376  0.579686
 0.565401   0.130292  0.691589  0.90659   0.729173
 0.813674   0.773177  0.535425  0.681151  0.0923525

julia> x[1] = -10
-10

julia> x
10×5 Array{Float64,2}:
 -10.0        0.165274  0.247298  0.309551  0.932243
   0.126986   0.843627  0.713371  0.415387  0.223799
   0.781115   0.402192  0.900288  0.38551   0.739652
   0.675185   0.828027  0.820174  0.305257  0.27004
   0.854511   0.957022  0.267321  0.488723  0.267576
   0.239777   0.380612  0.348398  0.75667   0.0980679
   0.0981943  0.322747  0.311123  0.409337  0.621242
   0.595097   0.797594  0.870286  0.499376  0.579686
   0.565401   0.130292  0.691589  0.90659   0.729173
   0.813674   0.773177  0.535425  0.681151  0.0923525

julia> close(abf)

julia> abf = abfopen(temp, "r")
AlignedBinaryFormat.AbfFile(IOStream(<file /tmp/jl_9LiLfO>), "/tmp/jl_9LiLfO", "r", Base.ImmutableDict{String,AlignedBinaryFormat.AbfKey}("x" => AlignedBinaryFormat.AbfKey{2}(88, Array{Float64,2}, (10, 5))), 14)

julia> read(abf, "x")
10×5 Array{Float64,2}:
 -10.0        0.165274  0.247298  0.309551  0.932243
   0.126986   0.843627  0.713371  0.415387  0.223799
   0.781115   0.402192  0.900288  0.38551   0.739652
   0.675185   0.828027  0.820174  0.305257  0.27004
   0.854511   0.957022  0.267321  0.488723  0.267576
   0.239777   0.380612  0.348398  0.75667   0.0980679
   0.0981943  0.322747  0.311123  0.409337  0.621242
   0.595097   0.797594  0.870286  0.499376  0.579686
   0.565401   0.130292  0.691589  0.90659   0.729173
   0.813674   0.773177  0.535425  0.681151  0.0923525

julia> close(abf)
```

## Why not use `JLD/HDF5`?
```
julia> x = rand(Float16,10,3);
       y = x .< 0.5;
       z = rand(29);
       @show typeof(x);
       @show typeof(y);
       @show typeof(z);
typeof(x) = Array{Float16,2}
typeof(y) = BitArray{2}
typeof(z) = Array{Float64,1}

julia> using JLD

julia> temp = tempname();
       jldopen(temp, "w"; mmaparrays=true) do j
       write(j,"x",x)
       write(j,"y",y)
       write(j,"z",z)
       end

julia> jldopen(temp, "r"; mmaparrays=true) do j
       @show typeof(read(j,"x"));
       @show typeof(read(j,"y"));
       @show typeof(read(j,"z"));
       end
typeof(read(j, "x")) = Array{Float16,2}
typeof(read(j, "y")) = BitArray{2}
typeof(read(j, "z")) = Base.ReinterpretArray{Float64,1,UInt8,Array{UInt8,1}}
```

As you can see `z` gets read back as `ReinterpretArray`

## Why not use `JLD2`
`JLD2` doesn't actually support memory mapping.
See my comment [here](https://github.com/JuliaIO/JLD2.jl/pull/176#issue-369260445).

---

# File Layout
As an example lets look use the following arrays.
```julia
julia> x = rand(Float16,10,3);
       y = x .< 0.5;
       z = rand(29);
       @show typeof(x);
       @show typeof(y);
       @show typeof(z);
typeof(x) = Array{Float16,2}
typeof(y) = BitArray{2}
typeof(z) = Array{Float64,1}
```
The file will have the following layout
* 6 characters (`Char`) indicating endian-ness of the numeric data contained within
    * `"LITTLE"` or `"BIG   "` (this depends on the host machine generating the file, currently conversion between little and big is not supported)
For each of the stored `Arrays`
* an `Int` indicating the length of the key `length(keyname)`
* the `String` which is the `key` of the array
* an `Int` indicating the length of `string(T<:Union{Array,BitArray})`
* the `String` representation of the array, i.e.,  `"Array"` or `"BitArray"`
    * there is no arbitrary code evaluation, types are determined via an `ImmutableDict{String,DataType}`
* for `"Array"`s an `Int` and `string(T)`
* an `Int` indication the number of dimensions `N`
* `N` `Int`s that give the shape of the array
* the buffer is then **aligned** to `T`
* the data

So for our example (with the names of the arrays "myX", "whybitarr", and "somez" respectively
```
<BOF> # beginning of file
LITTLE
3                               # length of "myX"
myX                             # label of first array
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
whybitarr                       # label of second array
8                               # length of "BitArray"
BitArray
2                               # number of dimensions
10                              # length of dimension 1
3                               # length of dimension 2
... (alignment spacing)
<the data>
5                               # length of "somez"
somez                           # label of third array
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
