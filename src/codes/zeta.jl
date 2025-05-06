"""
    Zeta(k)

Zeta code with parameter `k`. The parameter can be any positive
integer but is probably most useful for smallish values. Zeta(1)
coincides with Gamma.

The Zeta codes were originally designed for graph compression.

*Reference*:

Codes for the World Wide Web

Paolo Boldi and Sebastiano Vigna

https://vigna.di.unimi.it/ftp/papers/Codes.pdf
"""
struct Zeta <: UniversalIntegerCode
    k::Int
end

function encode!(target::EitherEndian, code::Zeta, value::Integer)
    value > 0 || return false
    k = code.k
    l = _top_set_bit(value)
    h = cld(l, k)
    n = h * k
    m = n - (k - 1)
    y = widen(one(value)) << m
    encode_unary!(target, h)
    if value < y
        emit_bits!(target, value - (y >> 1), n - 1)
    else
        # TODO?: Specialize the BigEndian case to emit all bits of
        # the value at once.
        emit_bits!(target, value >> 1, n - 1)
        emit_bits!(target, value & one(value), 1)
    end
    return is_valid(target)
end

function decode(target::Type{<:Union{Unsigned, BigInt}},
                code::Zeta,
                source::EitherEndian,
                start_offset::Integer = 0)
    max_target_bits = target_length(target)
    k = code.k
    h = decode_unary(source, start_offset)
    h == 0 && return zero(target), 0
    n = h * k - 1
    n == 0 && return one(target), h
    (h - 1) * k >= max_target_bits && return zero(target), 0
    x, success = get_bits(target, n, source, start_offset + h)
    success || return zero(target), 0
    num_bits = h + n
    y = one(target) << ((h - 1) * k)
    if x < y
        x |= y
    else
        target <: Unsigned && leading_zeros(x) == 0 && return zero(target), 0
        x <<= 1
        y, success = get_bits(target, 1, source, start_offset + h + n)
        success || return zero(target), 0
        x |= y
        num_bits += 1
    end
    return x, num_bits
end
