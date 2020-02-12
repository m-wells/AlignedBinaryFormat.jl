using Test
using AlignedBinaryFormat
using AlignedBinaryFormat: AbfFile, write_str, read_str, write_type, write_size, read_type,
    read_size

@testset "open/close" begin
    temp = tempname()
    try
        abf = abfopen(temp, "w+")
        @test isa(abf, AbfFile)
        close(abf)
        @test isfile(temp)

        abfopen(temp, "r") do abf
            @test isa(abf, AbfFile)
        end
        @test isfile(temp)

        abf = abfopen(temp, "r+")
        @test isa(abf, AbfFile)
        close(abf)
        @test isfile(temp)

    finally
        isfile(temp) && rm(temp)
    end
end

#@testset "internal write/read" begin
#    temp = tempname()
#    try
#        str = "μnicode"
#        x = rand(UInt32, 4,6,2)
#        y = rand(20) .< 0.5
#        abfopen(temp, "w") do abf
#            write_str(abf.io, str)
#            write_type(abf.io, x)
#            write_size(abf.io, x)
#            write_type(abf.io, y)
#            write_size(abf.io, y)
#        end
#
#        abfopen(temp, "r") do abf
#            @test str == read_str(abf.io)
#            t = read_type(abf.io)
#            s = read_size(abf.io, t)
#            @test typeof(x) == t
#            @test size(x) == s
#            t = read_type(abf.io)
#            s = read_size(abf.io, t)
#            @test typeof(y) == t
#            @test size(y) == s
#        end
#    finally
#        isfile(temp) && rm(temp)
#    end
#end

@testset "public write/read" begin
    temp = tempname()
    try
        myx = rand(UInt32, 4,6,2)
        μy1234_ = rand(20) .< 0.5
        f16 = rand(Float16,100)
        blah = rand(20,4,1)
        chars = rand(Char, 11,2)

        abfopen(temp, "w") do abf
            abf["f16"] = f16
            write(abf, "μy1234_", μy1234_)
            write(abf, "chars", chars)
            write(abf, "myx", myx)
            write(abf, "blah", blah)
        end

        abfopen(temp, "r") do abf
            @test μy1234_ == abf["μy1234_"]
            @test blah == read(abf, "blah")
            @test myx == read(abf, "myx")
            @test chars == read(abf, "chars")
            @test f16 == read(abf, "f16")
        end

        xyz = rand(10)
        abfopen(temp, "r+") do abf
            write(abf, "xyz", xyz)
        end
        abfopen(temp, "r") do abf
            @test myx == read(abf, "myx")
            @test xyz == read(abf, "xyz")
        end
            
    finally
        isfile(temp) && rm(temp)
    end
end

@testset "ondisk modification" begin
    temp = tempname()
    try
        blah = rand(20,4)
        abfopen(temp, "w+") do abf
            write(abf, "blah", blah)
        end

        abfopen(temp, "r+") do abf
            _blah = read(abf, "blah")
            @test blah == _blah
            _blah[2] = 1
        end

        abfopen(temp, "r") do abf
            blah = read(abf, "blah")
            @test blah[2] == 1
        end

    finally
        isfile(temp) && rm(temp)
    end
end

@testset "write out strings as data" begin
    temp = tempname()
    try
        blah = join(rand(Char,10))*join(rand(Char,9))
        x = rand(20,4)
        abfopen(temp, "w+") do abf
            write(abf, "blah", blah)
            abf["x"] = x
        end

        abfopen(temp, "r") do abf
            _blah = read(abf, "blah")
            @test blah == _blah
            @test x == abf["x"]
        end

    finally
        isfile(temp) && rm(temp)
    end
end





#@testset "write/read" begin
#    temp = tempname()
#    try
#        abfopen(temp, "w") do abf
#            write(abf, "f64", rand(Float16,10,3))
#            write(abf, "hello", rand(UInt128,10,3,7))
#            write(abf, "μnicode", rand(10) .< 0.5)
#        end
#
#        abfopen(temp, "r") do abf
#
#        end
#        @test isfile(temp)
#
#        abf = abfopen(temp, "r+")
#        @test isa(abf, AbfFile)
#        close(abf)
#        @test isfile(temp)
#
#    finally
#        isfile(temp) && rm(temp)
#    end
#end

