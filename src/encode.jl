# This file contains infrastructure for encoding positive integers as
# streams of bits. Encoding of actual codes is implemented in the
# codes/*.jl files.

"""
    encode!(target, code, value)

Encode the positive integer `value` using `code` into `target`. The
`code` must be an instance of a subtype of `UniversalIntegerCode`. The
`target` can be either `BigEndian{T}` or `LittleEndian{T}`, where `T`
is either an unsigned type, `BigInt`, or a `Vector` of an unsigned
type.

The return value is `true` if the encoding was successful and `false`
otherwise. Encoding can fail for two reasons:
* `value` is not positive, i.e. zero or negative.
* `target` is too small to hold all encoded bits. This can only occur
  when `T` is an unsigned type, not for `BigInt` or `Vector`.

*Example:*
```
encoded_data = UInt8[]
bitstream = BigEndian(encoded_data)
encode!(bitstream, Zeta(3), 17)
encode!(bitstream, Zeta(3), 4711)
```
---
    encode!(target, code, value, Unsigned)
    encode!(target, code, value, Signed)

Like above but encode a non-negative integer or a signed integer
respectively. In the former case `value` is increased by one before
encoding and in the latter case it is zigzag-transformed into a
positive integer. For `Unsigned`, encoding fails if `value` is
negative or equals `typemax(value)`. For `Signed`, `value` must be of
a signed type and encoding fails if `value` equals `typemin(value)`.
If these limitations are problematic, convert to a wider type before
calling `encode!`.
"""
function encode!(target::EitherEndian, code::UniversalIntegerCode,
                 value::Signed, ::Type{Signed})
    encode!(target, code, signed_encoding(value))
end

function encode!(target::EitherEndian, code::UniversalIntegerCode,
                 value::Integer, ::Type{Unsigned})
    encode!(target, code, unsigned_encoding(value))
end

"""
    encode(target_type, code, value)
    encode(target_type, code, value, Unsigned)
    encode(target_type, code, value, Signed)

Convenience wrapper for `encode!`, see that docstring for more
information.

The wrapper makes an empty instance of `target_type`, passes it to
`encode!`, unpacks the instance, and returns the bit data and the
number of bits used by the encoding of `value`. If the encoding fails,
the returned number of bits is zero.

If `target_type` is an unparametrized `BigEndian` or `LittleEndian`,
it is parametrized by the type of `value`, or the unsigned counterpart
if `value` is of a signed type. If `target_type` is omitted, it is set
to `LittleEndian`.
"""
function encode(code::UniversalIntegerCode, value::Integer, args...)
    return encode(LittleEndian{_unsigned(typeof(value))},
                  code, value, args...)
end

function encode(T::Union{Type{LittleEndian}, Type{BigEndian}},
                code::UniversalIntegerCode,
                value::S, args...) where {S <: Integer}
    return encode(T{_unsigned(S)}, code, value, args...)
end

function encode(T::Type{<:EitherEndian}, code::UniversalIntegerCode,
                value::Integer, args...)
    target = T()
    encode!(target, code, value, args...)
    is_valid(target) || return zero(target.data), 0
    return target.data, bit_length(target)
end

function bit_length(target::EitherEndian{<:Vector})
    return 8 * sizeof(eltype(target.data)) * (length(target.data) - 1) + target.num_bits
end

bit_length(target) = target.num_bits

function encode_unary!(target::EitherEndian, n)
    n > 0 || return false
    emit_zeros!(target, n - 1)
    emit_ones!(target, 1)
    return is_valid(target)
end

# Add `n` zeros to target.
function emit_zeros!(target::BigEndian{T}, n) where T <: Union{Unsigned, BigInt}
    target.data <<= n
    target.num_bits += n
end

function emit_zeros!(target::LittleEndian{T}, n) where T <: Union{Unsigned, BigInt}
    target.num_bits += n
end

function emit_zeros!(target::EitherEndian{Vector{T}}, n) where T <: Unsigned
    bits_per_element = 8 * sizeof(T)
    n′ = target.num_bits + n
    if n′ > bits_per_element
        append!(target.data, zeros(T, fld1(n′, bits_per_element) - 1))
    end
    target.num_bits = mod1(n′, bits_per_element)
end

function emit_ones!(target::EitherEndian{T}, n) where T <: Union{Unsigned, BigInt}
    emit_bits!(target, (one(T) << n) - one(T), n)
end

function emit_ones!(target::BigEndian{Vector{T}}, n) where T <: Unsigned
    bits_per_element = 8 * sizeof(T)
    if target.num_bits < bits_per_element
        target.data[end] |= (one(T) << (bits_per_element - target.num_bits)) - one(T)
    end
    n′ = target.num_bits + n
    if n′ > bits_per_element
        append!(target.data, fill(typemax(T), fld1(n′, bits_per_element) - 1))
    end
    target.num_bits = mod1(n′, bits_per_element)
    m = bits_per_element - target.num_bits
    if m > 0
        target.data[end] = (target.data[end] >> m) << m
    end
end

function emit_ones!(target::LittleEndian{Vector{T}}, n) where T <: Unsigned
    bits_per_element = 8 * sizeof(T)
    if target.num_bits < bits_per_element
        target.data[end] |= typemax(T) << target.num_bits
    end
    n′ = target.num_bits + n
    if n′ > bits_per_element
        append!(target.data, fill(typemax(T), fld1(n′, bits_per_element) - 1))
    end
    target.num_bits = mod1(n′, bits_per_element)
    m = bits_per_element - target.num_bits
    if m > 0
        target.data[end] = (target.data[end] << m) >> m
    end
end

function emit_bits!(target::BigEndian{T}, bits, n) where T <: Union{Unsigned, BigInt}
    target.data <<= n
    target.data |= bits % T
    target.num_bits += n
end

function emit_bits!(target::LittleEndian{T}, bits, n) where T <: Union{Unsigned, BigInt}
    target.data |= (bits % T) << target.num_bits
    target.num_bits += n
end

function emit_bits!(target::BigEndian{Vector{T}}, bits, n) where T <: Unsigned
    bits_per_element = 8 * sizeof(T)
    while n > 0
        if target.num_bits == bits_per_element
            push!(target.data, zero(T))
            target.num_bits = 0
        end
        if n + target.num_bits >= bits_per_element
            to_emit = bits >> (n - (bits_per_element - target.num_bits))
            target.data[end] |= to_emit % T
            bits ⊻= to_emit << (n - (bits_per_element - target.num_bits))
            n -= bits_per_element - target.num_bits
            target.num_bits = bits_per_element
        else
            target.data[end] |= (bits % T) << (bits_per_element - target.num_bits - n)
            target.num_bits += n
            n = 0
        end
    end
end

function emit_bits!(target::LittleEndian{Vector{T}}, bits, n) where T <: Unsigned
    bits_per_element = 8 * sizeof(T)
    while n > 0
        if target.num_bits == bits_per_element
            push!(target.data, zero(T))
            target.num_bits = 0
        end
        if n + target.num_bits >= bits_per_element
            to_emit = bits << target.num_bits
            target.data[end] |= to_emit % T
            bits >>= bits_per_element - target.num_bits
            n -= bits_per_element - target.num_bits
            target.num_bits = bits_per_element
        else
            target.data[end] |= (bits % T) << target.num_bits
            target.num_bits += n
            n = 0
        end
    end
end

signed_encoding(x::Signed) = (x >= 0) ? ((_unsigned(x) << 1) + one(x)) : _unsigned(-x) << 1
unsigned_encoding(x::Integer) = x + one(x)

# Base.top_set_bit is not public and only exists in Julia >= 1.10. But
# if it's available it's faster than ndigits. Note that top_set_bit
# and ndigits diverge for x < 1, but we only need this for positive
# integers.
@static if isdefined(Base, :top_set_bit)
    _top_set_bit(x) = Base.top_set_bit(x)
else
    _top_set_bit(x::BigInt) = ndigits(x, base = 2)
    # Copied from Julia Base.
    _top_set_bit(x) = 8 * sizeof(x) - leading_zeros(x)
end
