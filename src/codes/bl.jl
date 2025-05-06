"""
    BL(S)

BL code with parameter `S`. The parameter can be any positive
integer but is probably most useful for smallish values.

The BL codes were originally designed for compression of ultrasound
signals.

*Reference*:

Real-Time Lossless Compression Algorithm for Ultrasound Data Using BL Universal Code

Jung Hoon Kim, et al

https://www.mdpi.com/1424-8220/18/10/3314
"""
struct BL <: UniversalIntegerCode
    S::Int
end

function encode!(target::EitherEndian, code::BL, value::Integer)
    value > 0 || return false
    S = code.S
    n = one(value) << S
    if value isa BigInt || value <= typemax(value) - n
        M = _top_set_bit((value + (n - one(value))) >> S)
    else
        M = _top_set_bit((widen(value) + (n - one(value))) >> S)
    end
    # This can be expressed in integer arithmetic as (1 + isqrt(8 * M)) ÷ 2
    # but it is slower and since M is approximately the number of bits
    # in the value, there are no range or precision limitations of
    # Float64 to be concerned about in practice.
    K = ceil(Int, (1 + sqrt(1 + 8 * M)) / 2) - 1
    X = M - K * (K - 1) ÷ 2
    suffix = value - n * ((one(value) << (M - 1)) - one(value)) - one(value)
    emit_ones!(target, X - 1)
    emit_zeros!(target, K - X + 1)
    emit_ones!(target, 1)
    emit_bits!(target, suffix, M + S - 1)
    return is_valid(target)    
end

function decode(target::Type{<:Union{Unsigned, BigInt}},
                code::BL,
                source::EitherEndian,
                start_offset::Integer = 0)
    max_target_bits = target_length(target)
    S = code.S
    T = count_leading_ones(source, start_offset)
    K = count_leading_zeros(source, start_offset + T)
    K == -1 && return zero(target), 0
    K += T
    M = ((K * (K - 1)) >> 1) + T + 1
    M + S - 1 <= max_target_bits || return zero(target), 0
    suffix, success = get_bits(target, M + S - 1, source, start_offset + K + 1)
    success || return zero(target), 0
    offset = (((one(target) << (M - 1)) - one(target)) << S) + one(target)
    value = suffix + offset
    value < suffix && return zero(target), 0
    num_bits = K + M + S
    return value, num_bits
end
