"""
    Fibonacci()

Fibonacci code. This represents a positive integer as a sum of
Fibonacci numbers, with minimal number of terms. The code is
terminated by two consecutive ones.

*Reference*:

`https://en.wikipedia.org/wiki/Fibonacci_coding`
"""
struct Fibonacci <: UniversalIntegerCode
end

function encode!(target::EitherEndian, code::Fibonacci, value::Integer)
    value > 0 || return false
    a = one(value)
    b = one(value)
    while value - b >= a
        a, b = b, a + b
    end
    bits = Bool[]
    while a > 0
        if b <= value
            pushfirst!(bits, true)
            value -= b
        else
            pushfirst!(bits, false)
        end
        a, b = b - a, a
    end
    for bit in bits
        if bit
            emit_ones!(target, 1)
        else
            emit_zeros!(target, 1)
        end
    end
    emit_ones!(target, 1)
    return is_valid(target)
end

function decode(target::Type{<:Union{Unsigned, BigInt}},
                code::Fibonacci,
                source::EitherEndian,
                start_offset::Integer = 0)
    x = zero(target)
    a = zero(target)
    b = one(target)
    n = 0
    last_bit = zero(target)
    while true
        y, success = get_bits(target, 1, source, start_offset + n)
        success || return zero(target), 0
        n += 1
        last_bit == 1 && y == 1 && return x, n
        last_bit = y
        a, b = b, a + b
        b >= a || return zero(target), 0
        if y == 1
            x′ = x + b
            x′ > x || return zero(target), 0
            x = x′
        end
    end
end
