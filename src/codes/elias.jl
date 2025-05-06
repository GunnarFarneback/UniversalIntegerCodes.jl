"""
    Gamma()

Elias gamma code.

*Reference*:

Universal codeword sets and representations of the integers

Peter Elias

IEEE Transactions on Information Theory, 1975

`https://en.wikipedia.org/wiki/Elias_gamma_coding`
"""
struct Gamma <: UniversalIntegerCode
end

function encode!(target::EitherEndian, code::Gamma, value::Integer)
    value > 0 || return false
    l = _top_set_bit(value)
    encode_unary!(target, l)
    emit_bits!(target, value - (one(value) << (l - 1)), l - 1)
    return is_valid(target)
end

function decode(target::Type{<:Union{Unsigned, BigInt}},
                code::Gamma,
                source::EitherEndian,
                start_offset::Integer = 0)
    max_target_bits = target_length(target)
    h = decode_unary(source, start_offset)
    h == 0 && return zero(target), 0
    n = h - 1
    n == 0 && return one(target), h
    n >= max_target_bits && return zero(target), 0
    x, success = get_bits(target, n, source, start_offset + h)
    success || return zero(target), 0
    num_bits = h + n
    y = one(target) << n
    return x | y, num_bits
end

"""
    Delta()

Elias delta code.

*Reference*:

Universal codeword sets and representations of the integers

Peter Elias

IEEE Transactions on Information Theory, 1975

`https://en.wikipedia.org/wiki/Elias_delta_coding`
"""
struct Delta <: UniversalIntegerCode
end

function encode!(target::EitherEndian, code::Delta, value::Integer)
    value > 0 || return false
    l = _top_set_bit(value)
    encode!(target, Gamma(), l)
    emit_bits!(target, value - (one(value) << (l - 1)), l - 1)
    return is_valid(target)
end

function decode(target::Type{<:Union{Unsigned, BigInt}},
                code::Delta,
                source::EitherEndian,
                start_offset::Integer = 0)
    max_target_bits = target_length(target)
    x = zero(target)
    h, l = decode(UInt64, Gamma(), source, start_offset)
    h == 0 && return zero(target), 0
    n = h - 1
    n == 0 && return one(target), h % Int
    n >= max_target_bits && return zero(target), 0
    x, success = get_bits(target, n, source, start_offset + l)
    success || return zero(target), 0
    num_bits = (l + n) % Int
    y = one(target) << n
    return x | y, num_bits
end

"""
    Omega()

Elias omega code.

*Reference*:

Universal codeword sets and representations of the integers

Peter Elias

IEEE Transactions on Information Theory, 1975

`https://en.wikipedia.org/wiki/Elias_omega_coding`
"""
struct Omega <: UniversalIntegerCode
end

function encode!(target::EitherEndian, code::Omega, value::Integer)
    value > 0 || return false
    N = [(zero(value), 1)]
    while value > 1
        l = _top_set_bit(value)
        pushfirst!(N, (value, l))
        value = oftype(value, l) - oftype(value, 1)
    end
    for (bits, n) in N
        if n == 1
            emit_bits!(target, bits, n)
        else
            emit_bits!(target, bits >> (n - 1), 1)
            emit_bits!(target, bits ⊻ (one(bits) << (n - 1)), n - 1)
        end
    end
    return is_valid(target)
end

function decode(target::Type{<:Union{Unsigned, BigInt}},
                code::Omega,
                source::EitherEndian,
                start_offset::Integer = 0)
    max_target_bits = target_length(target)
    n = 0
    x = one(target)
    while true
        y, success = get_bits(target, 1, source, start_offset + n)
        success || return zero(target), 0
        n += 1
        y == 0 && break
        x < max_target_bits || return zero(target), 0
        y, success = get_bits(target, x, source, start_offset + n)
        success || return zero(target), 0
        n += x % Int
        x = y | (one(target) << x)
    end
    return x, n
end
