# This file contains infrastructure for decoding positive integers
# from streams of bits. Decoding of actual codes is implemented in the
# codes/*.jl files.

"""
    decode(target_type, code, source, start_offset)

Decode a positive integer from a bit stream `source`, using `code`,
into a value of `target_type`. The `code` must be an instance of a
subtype of `UniversalIntegerCode`. The `source` can be of either
`BigEndian{T}` or `LittleEndian{T}` type, where `T` is either an
unsigned type, `BigInt`, or a `Vector` of an unsigned type.
`start_offset` is an integer offset into the bit stream, which can be
omitted and defaults to zero. The `target_type` must be either an
unsigned type or `BigInt`.

The output is a value of `target_type` and the number of bits used by
the code. Decoding never mutates `source`, so to continue reading,
`start_offset` should be advanced by the number of used bits. In case
of a decoding failure, the number of used bits is returned as
zero. Decoding can fail either if no valid code word is found in
`source` or if the decoded value does not fit in `target_type`.

*Warning:*

The decoding assumes that the bitstream is consistent, i.e. that the
stated number of bits fits in the stream data and that there are no
non-zero bits beyond the stated number of bits. Additionally decoding
may ignore the stated number of bits and implicitly pad with zeros if
that provides a valid code word. The results of `encode!` and `encode`
are always consistent.

*Example:*
```
bitstream = BigEndian(0x27, 8)
decode(UInt16, Delta(), bitstream)
```
---
    decode(target_type, code, source, start_offset, Unsigned)
    decode(target_type, code, source, start_offset, Signed)

Like above but decode a non-negative integer or a signed integer
respectively. In the former case the decoded value is decreased by one
before it is returned and in the latter case it is zigzag-transformed
into a signed integer. In the `Signed` case, `target_type` must be
either `BigInt` or a signed type. If it is a signed type, decoding is
done into the corresponding unsigned type before transforming it.
"""
function decode(target::Type{<:Union{Unsigned, BigInt}},
                code::UniversalIntegerCode,
                source::EitherEndian)
    return decode(target, code, source, 0)
end

function decode(target::Type{<:Union{Unsigned, BigInt}},
                code::UniversalIntegerCode,
                source::EitherEndian,
                mapping::Type{Unsigned})
    return decode(target, code, source, 0, mapping)
end

function decode(target::Type{<:Union{Signed, BigInt}},
                code::UniversalIntegerCode,
                source::EitherEndian,
                mapping::Type{Signed})
    return decode(target, code, source, 0, mapping)
end

function decode(target::Type{<:Union{Unsigned, BigInt}},
                code::UniversalIntegerCode,
                source::EitherEndian,
                start_offset::Integer,
                ::Type{Unsigned})
    value, num_bits = decode(target, code, source, start_offset)
    return unsigned_decoding(value), num_bits
end

function decode(target::Type{<:Union{Signed, BigInt}},
                code::UniversalIntegerCode,
                source::EitherEndian,
                start_offset::Integer,
                ::Type{Signed})
    value, num_bits = decode(_unsigned(target), code, source, start_offset)
    return signed_decoding(value), num_bits
end

# `signed` and `unsigned` are (reasonably) not defined for `BigInt`,
# but we need them to just pass through in that case.
_unsigned(x) = unsigned(x)
_unsigned(::Type{BigInt}) = BigInt
_unsigned(x::BigInt) = x
_signed(x) = signed(x)
_signed(::Type{BigInt}) = BigInt
_signed(x::BigInt) = x

target_length(x::Type{<:Unsigned}) = 8 * sizeof(x)
target_length(x::Type{BigInt}) = typemax(Int)

function decode_unary(source::EitherEndian, start_offset::Integer)
    n = count_leading_zeros(source, start_offset)
    return n + 1
end

function count_leading_zeros(source::LittleEndian{<:Union{Unsigned, BigInt}},
                             start_offset::Integer)
    x = source.data >> start_offset
    x == 0 && return -1
    return trailing_zeros(x)
end

function count_leading_zeros(source::LittleEndian{Vector{T}},
                             start_offset::Integer) where {T <: Unsigned}
    max_source_bits = target_length(T)
    element_offset = start_offset ÷ (max_source_bits)
    bit_offset = start_offset % (max_source_bits)
    n = 0
    while element_offset < length(source.data)
        x = source.data[1 + element_offset] >> bit_offset
        if x == 0
            n += max_source_bits - bit_offset
            element_offset += 1
            bit_offset = 0
        else
            n += trailing_zeros(x)
            return n
        end
    end
    return -1
end

# TODO: This can be implemented more efficiently for Unsigned.
function count_leading_zeros(source::BigEndian{<:Union{Unsigned, BigInt}},
                             start_offset::Integer)
    x = source.data
    mask = one(x) << (source.num_bits - 1 - start_offset)
    n = 0
    while (x & mask) == 0
        n += 1
        mask >>= 1
        mask == 0 && return -1
    end
    return n
end

function count_leading_zeros(source::BigEndian{Vector{T}},
                             start_offset::Integer) where {T <: Unsigned}
    max_source_bits = target_length(T)
    element_offset = start_offset ÷ (max_source_bits)
    bit_offset = start_offset % (max_source_bits)
    n = 0
    while element_offset < length(source.data)
        x = source.data[1 + element_offset] << bit_offset
        if x == 0
            n += max_source_bits - bit_offset
            element_offset += 1
            bit_offset = 0
        else
            n += leading_zeros(x)
            return n
        end
    end
    return -1
end

function count_leading_ones(source::LittleEndian{<:Union{Unsigned, BigInt}},
                            start_offset::Integer)
    x = source.data >> start_offset
    return trailing_ones(x)
end

function count_leading_ones(source::LittleEndian{Vector{T}},
                            start_offset::Integer) where {T <: Unsigned}
    max_source_bits = target_length(T)
    element_offset = start_offset ÷ (max_source_bits)
    bit_offset = start_offset % (max_source_bits)
    n = 0
    while element_offset < length(source.data)
        x = source.data[1 + element_offset] >> bit_offset
        m = trailing_ones(x)
        n += m
        if m == max_source_bits - bit_offset
            element_offset += 1
            bit_offset = 0
        else
            break
        end
    end
    return n
end

# TODO: This can be implemented more efficiently for Unsigned.
function count_leading_ones(source::BigEndian{<:Union{Unsigned, BigInt}},
                            start_offset::Integer)
    x = source.data
    mask = one(x) << (source.num_bits - 1 - start_offset)
    n = 0
    while (x & mask) != 0
        n += 1
        mask >>= 1
        mask == 0 && break
    end
    return n
end

function count_leading_ones(source::BigEndian{Vector{T}},
                             start_offset::Integer) where {T <: Unsigned}
    max_source_bits = target_length(T)
    element_offset = start_offset ÷ (max_source_bits)
    bit_offset = start_offset % (max_source_bits)
    n = 0
    while element_offset < length(source.data)
        x = source.data[1 + element_offset] << bit_offset
        m = leading_ones(x)
        n += m
        if m == max_source_bits - bit_offset
            element_offset += 1
            bit_offset = 0
        else
            break
        end
    end
    return n
end

function get_bits(target::Type{<:Union{Unsigned, BigInt}}, n::Integer,
                  source::LittleEndian{<:Union{Unsigned, BigInt}},
                  start_offset::Integer)
    x = source.data >> start_offset
    mask = (one(x) << n) - 1
    x &= mask
    y = x % target
    return y, x == y
end

function get_bits(target::Type{<:Union{Unsigned, BigInt}}, n::Integer,
                  source::LittleEndian{Vector{T}},
                  start_offset::Integer) where {T <: Unsigned}
    max_source_bits = target_length(T)
    element_offset = start_offset ÷ (max_source_bits)
    bit_offset = start_offset % (max_source_bits)
    acquired_bits = 0
    x = zero(target)
    while element_offset < length(source.data) && acquired_bits < n
        d = source.data[1 + element_offset] >> bit_offset
        m = min(max_source_bits - bit_offset, n - acquired_bits)
        if m + bit_offset < max_source_bits
            mask = (one(T) << m) - one(T)
            d &= mask
        end
        e = d % target
        e == d || return zero(target), false
        x isa Unsigned && e != 0 && leading_zeros(e) < acquired_bits && return zero(target), false
        x |= e << acquired_bits
        acquired_bits += m
        element_offset += 1
        bit_offset = 0
    end
    acquired_bits < n && return zero(target), false
    return x, true
end

function get_bits(target::Type{<:Union{Unsigned, BigInt}}, n::Integer,
                  source::BigEndian{<:Union{Unsigned, BigInt}},
                  start_offset::Integer)
    x = source.data >> (source.num_bits - start_offset - n)
    mask = (one(x) << n) - 1
    x &= mask
    y = x % target
    return y, x == y
end

function get_bits(target::Type{<:Union{Unsigned, BigInt}}, n::Integer,
                  source::BigEndian{Vector{T}},
                  start_offset::Integer) where {T <: Unsigned}
    max_source_bits = target_length(T)
    element_offset = start_offset ÷ (max_source_bits)
    bit_offset = start_offset % (max_source_bits)
    acquired_bits = 0
    x = zero(target)
    while element_offset < length(source.data) && acquired_bits < n
        m = min(n - acquired_bits, max_source_bits - bit_offset)
        x isa Unsigned && x != 0 && leading_zeros(x) < m && return zero(target), false
        x <<= m
        d = (source.data[1 + element_offset] << bit_offset) >> (max_source_bits - m)
        e = d % target
        e == d || return zero(target), false
        x |= e
        acquired_bits += m
        element_offset += 1
        bit_offset = 0
    end
    acquired_bits < n && return zero(target), false
    return x, true
end

signed_decoding(x::Integer) = isodd(x) ? _signed((x - one(x)) >> 1) : -_signed(x >> 1)
unsigned_decoding(x::Integer) = x - one(x)
