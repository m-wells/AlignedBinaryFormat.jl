using Test
using AlignedBinaryFormat
using AlignedBinaryFormat: AbfFile, write_str, read_str, write_type, read_type, AbfReadError,
                           AbfWriteError

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

tryrm(path) = try
    rm(path)
catch e
    @info "Failed to remove $path" exception=(e,catch_backtrace())
end

@testset "public write/read" begin
    temp = tempname()
    try
        myx = rand(UInt32, 4,6,2)
        μy1234_ = rand(20) .< 0.5
        f16s = rand(Float16,100)
        blah = rand(20,4,1)
        chars = rand(Char, 11,2)
        f32 = 1f0
        i64 = 42

        abfopen(temp, "w") do abf
            abf["f16s"] = f16s
            write(abf, "μy1234_", μy1234_)
            write(abf, "chars", chars)
            write(abf, "myx", myx)
            write(abf, "blah", blah)
            write(abf, "f32", f32)
            write(abf, "i64", i64)
        end

        abfopen(temp, "r") do abf
            @test μy1234_ == abf["μy1234_"]
            @test blah == read(abf, "blah")
            @test myx == read(abf, "myx")
            @test chars == read(abf, "chars")
            @test f16s == read(abf, "f16s")
            @test f32 == read(abf, "f32")
            @test i64 == read(abf, "i64")

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
        isfile(temp) && tryrm(temp)
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
        isfile(temp) && tryrm(temp)
    end
end

@testset "read/write strings as data" begin
    temp = tempname()
    try
        blah = join(rand(Char,10))*join(rand(Char,9))
        blah = "a∘α"
        x = rand(20,4)
        key = "blahαש"
        abfopen(temp, "w+") do abf
            write(abf, key, blah)
            abf["x"] = x
        end

        abfopen(temp, "r") do abf
            _blah = read(abf, key)
            @test blah == _blah
            @test x == abf["x"]
        end

    finally
        isfile(temp) && tryrm(temp)
    end
end

struct Foo
    x::Vector{Float64}
    y::Int64
end

@testset "read/write datatypes/serialized" begin
    temp = tempname()
    try
        x = rand(20,4)
        y = Foo(rand(3), 2)
        abfopen(temp, "w+") do abf
            write(abf, "bar", Foo)
            abf["x"] = x
            write(abf, "foo", AbfSerializer(y))
        end

        abfopen(temp, "r") do abf
            @test x == abf["x"]
            foo = read(abf, "foo")
            @test typeof(foo) == typeof(y)
            for f in fieldnames(Foo)
                @test getfield(foo, f) == getfield(y, f)
            end
        end

    finally
        isfile(temp) && tryrm(temp)
    end
end

@testset "exception handling" begin
    temp = tempname()
    try
        x = rand(20,4)
        abfopen(temp, "w") do abf
            abf["x"] = x
            @test_throws AbfReadError abf["x"]
        end
        abfopen(temp, "r") do abf
            @test_throws AbfWriteError begin
                abf["y"] = x
            end
        end

    finally
        isfile(temp) && tryrm(temp)
    end

    if Sys.islinux()
        @testset "full device" begin
            @test_throws Exception abfopen("/dev/full", "w") do abf
                abf["x"] = rand(10)
            end
            # try a larger vector too, where `write` returns 0 rather than throw
            @test_throws Exception abfopen("/dev/full", "w") do abf
                abf["x"] = rand(10_000)
            end
        end
    end
end



# not much of a test set but it will atleast catch method errors
@testset "show" begin
    temp = tempname()
    try
        x = rand(20,4)
        abfopen(temp, "w+") do abf
            abf["x"] = x
        end

        abfopen(temp, "r") do abf
            x = sprint(show,abf)
            @test x == sprint(show,abf)
            x = sprint(show, abf.abfkeys["x"])
            @test x == sprint(show,abf.abfkeys["x"])

            x = sprint(showerror, AbfReadError(abf.io))
            @test x == sprint(showerror, AbfReadError(abf.io))

            x = sprint(showerror, AbfWriteError(abf.io))
            @test x == sprint(showerror, AbfWriteError(abf.io))
        end

    finally
        isfile(temp) && tryrm(temp)
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

