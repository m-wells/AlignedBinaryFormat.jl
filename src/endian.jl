const LIT_ENDIAN = 0x04030201
const BIG_ENDIAN = 0x01020304

const LIT_ENDFLAG = UInt8(0)
const BIG_ENDFLAG = UInt8(255)

function write_endian(io::IOStream)
    if Base.ENDIAN_BOM == LIT_ENDIAN
        write(io, LIT_ENDFLAG)
    elseif Base.ENDIAN_BOM == BIG_ENDIAN
        write(io, BIG_ENDFLAG)
    else
        error("ENDIAN_BOM of ", Base.ENDIAN_BOM, " not recognized")
    end
end

function read_endian(io::IOStream)
    endflag = read(io, UInt8)
    if endflag == LIT_ENDFLAG
        endian = LIT_ENDIAN
    elseif endflag == BIG_ENDFLAG
        endian = BIG_ENDIAN
    else
        error("ENDIAN FLAG of ", UInt8(endflag), " not recognized")
    end
    endian == Base.ENDIAN_BOM || error("endian does not match machine endian")
    return endian
end
