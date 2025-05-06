using Test
using UniversalIntegerCodes: encode!, encode, decode,
                             LittleEndian, BigEndian,
                             get_data, get_num_bits,
                             Gamma, Delta, Omega, Fibonacci, Zeta, BL

codes = vcat(("Gamma", Gamma()),
             ("Delta", Delta()),
             ("Omega", Omega()),
             ("Fibonacci", Fibonacci()),
             (("Zeta_$k", Zeta(k)) for k in 1:7)...,
             (("BL_$k", BL(k)) for k in 1:7)...)

@testset "$code_name" for (code_name, code) in codes
    for endian in (LittleEndian, BigEndian)
        for T in (BigInt, UInt128, UInt64, UInt32, UInt16, UInt8,
                  Vector{UInt128}, Vector{UInt64}, Vector{UInt32},
                  Vector{UInt16}, Vector{UInt8})
            for x in vcat(1:1000, Int64(10).^(4:18), Int64(2).^(10:62), Int64(2).^(10:63) .- 1)
                target = endian{T}()
                success = encode!(target, code, x)
                if T === BigInt || T <: Vector
                    @test success
                end

                # Test the encode function.
                data, num_encoded_bits = encode(endian{T}, code, x)
                if success
                    @test get_data(target) == data
                    @test get_num_bits(target) == num_encoded_bits
                else
                    @test num_encoded_bits == 0
                end

                if success
                    y, num_bits = decode(BigInt, code, target)
                    @test y == x
                    @test num_bits == get_num_bits(target)
                    for T′ in (UInt128, UInt64, UInt32, UInt16, UInt8)
                        y′, num_bits′ = decode(T′, code, target)
                        if x <= typemax(T′)
                            @test y′ == y
                            @test num_bits′ == num_bits
                        else
                            @test num_bits′ == 0
                        end
                    end
                    target = endian{T}()
                    # Test encoding of `x` when it's sandwiched
                    # between two other values.
                    success1 = encode!(target, code, 1)
                    offset = get_num_bits(target)
                    success2 = encode!(target, code, x)
                    success3 = encode!(target, code, 2)
                    # The number of bits in the target might not have
                    # been enough for all three values, so exclude
                    # cases where we have run out.
                    if T === BigInt || T <: Vector
                        @test success1 && success2 && success3
                    end
                    if success1 && success2 && success3
                        for T′ in (UInt128, UInt64, UInt32, UInt16, UInt8)
                            y′, num_bits′ = decode(T′, code, target, offset)
                            if x <= typemax(T′)
                                @test y′ == y
                                @test num_bits′ == num_bits
                            else
                                @test num_bits′ == 0
                            end
                        end
                    end
                end
            end
        end
    end

    # Stress test the upper type bound for the input value, which
    # could run into overflow problems.
    for endian in (LittleEndian, BigEndian)
        for T in [UInt128, UInt64, UInt32, UInt16, UInt8,
                  Int128, Int64, Int32, Int16, Int8]
            x = typemax(T)
            target = endian{BigInt}()
            @test encode!(target, code, x)
            @test decode(BigInt, code, target) == (x, get_num_bits(target))
        end
    end
end

@testset "$mapping" for mapping in (Unsigned, Signed)
    if mapping === Unsigned
        types = [UInt8, UInt16, UInt32, UInt64, UInt128, BigInt]
        small_range = 0x00:0xfe
    else
        types = [Int8, Int16, Int32, Int64, Int128, BigInt]
        small_range = Int8(-127):Int8(127)
    end
    
    # No need to test with more than one code, so let's pick a simple
    # one. The mapping mechanisms are the same for all codes.
    code = Gamma()
    # The same reasoning goes for targets.
    target_type = LittleEndian{Vector{UInt64}}

    for value in small_range
        target = target_type()
        success = encode!(target, code, value, mapping)
        data, num_bits = encode(target_type, code, value, mapping)
        @test success && num_bits > 0
        @test data == get_data(target)
        @test num_bits == get_num_bits(target)
        decoded, decoded_num_bits = decode(typeof(value), code,
                                           target, 0, mapping)
        @test decoded == value
        @test num_bits == decoded_num_bits
    end

    for type in types
        if type === BigInt
            if mapping === Unsigned
                values = BigInt[0, 1]
            else
                values = BigInt[-1, 0, 1]
            end
        else
            values = [typemin(type), typemin(type) + one(type),
                      typemax(type) - one(type), typemax(type)]
        end
        for value in values
            target = target_type()
            success = encode!(target, code, value, mapping)
            if success
                decoded, decoded_num_bits = decode(type, code, target,
                                                   mapping)
                @test decoded == value
                @test decoded_num_bits == get_num_bits(target)
            else
                if mapping == Unsigned
                    @test value == typemax(type)
                else
                    @test value == typemin(type)
                end
            end
        end
    end
end

@testset "encode additional methods" begin
    @test encode(Gamma(), 3) == (6, 3)
    @test encode(LittleEndian, Gamma(), 3) == (6, 3)
    @test encode(BigEndian, Gamma(), 3) == (3, 3)
end

# This is mostly run to improve coverage.
@testset "invalid codes" begin
    for endian in (BigEndian, LittleEndian)
        for data in (0x00, BigInt(0x00), [0x00])
            # Try to decode a single 0 bit.
            value, num_bits = decode(UInt8, Gamma(), endian(data, 1))
            @test num_bits == 0
        end
    end

    # Try to decode big-endian 00000001 (incomplete code).
    value, num_bits = decode(UInt8, Gamma(), BigEndian([0x01], 8))
    @test num_bits == 0

    # Try to decode little-endian 10000000 (incomplete code).
    value, num_bits = decode(UInt8, Gamma(), LittleEndian([0x80], 8))
    @test num_bits == 0
end

function endians_equal(a, b)
    typeof(a) == typeof(b) || return false
    get_data(a) == get_data(b) || return false
    return get_num_bits(a) == get_num_bits(b)
end

@testset "endians coverage" begin
    for endian in (BigEndian, LittleEndian)
        @test endians_equal(endian{UInt8}(0x00, 0), endian(0x00, 0))
        @test endians_equal(endian(), endian(UInt64(0), 0))
        @test endians_equal(endian(0x06, 4), endian((0x06, 4)))
        @test endians_equal(endian{UInt8}(0x06, 4),
                            endian{UInt8}((0x06, 4)))
        @test endians_equal(endian(UInt8[]), endian(UInt8[], 0))
        @test endians_equal(endian(UInt8[0xff]), endian(UInt8[0xff], 8))
        @test string(endian(0x1d, 7)) == "$(endian): 7 bits 0x1d (0011101)"
        @test string(endian(BigInt(13), 5)) == "$(endian): 5 bits 13 (01101)"
        if VERSION < v"1.6"
            @test string(endian([0x01, 0x02], 11)) == "$(endian) Array{UInt8,1}: 11 bits"
        else
            @test string(endian([0x01, 0x02], 11)) == "$(endian) Vector{UInt8}: 11 bits"
        end
    end
end
