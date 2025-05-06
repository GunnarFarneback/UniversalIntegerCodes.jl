abstract type EitherEndian{T} end

get_data(x::EitherEndian) = x.data
get_num_bits(x::EitherEndian) = x.num_bits
get_num_bits(x::EitherEndian{<:Vector}) = x.num_bits + 8 * sizeof(eltype(x.data)) * (length(x.data) - 1)

"""
    BigEndian{T} where T <: Union{Unsigned, BigInt, Vector{<:Unsigned}}

Data type representing streams of bits in little endian order,
i.e. the least significant bits are considered to be the first
ones. The storage type `T` can be one of an unsigned integer type, a
`BigInt`, and a `Vector` of an unsigned integer type.

*Constructors*:

* `BigEndian{T}()` - Empty bit stream with storage type `T`
* `BigEndian()` - Empty bit stream with storage type `UInt64`.
* `BigEndian(x::T, n::Integer)` - Bit stream containing `n` bits
  stored in `x`. `n` must be a number of bits available in `x`. When
  `x` is a `Vector`, all but the last element must be fully used.
* `BigEndian((x, n))` - Same as `BigEndian(x, n)`, for convenience.
* `BigEndian(x::Vector)` - Bit stream containing all bits available
  in `x`. This constructor is primarily useful when `x` is empty.

*Accessors*:

* `get_data(x::BigEndian)` - Retrieve the storage for the bits in `x`.
* `get_num_bits(x::BigEndian)` - Retrieve the number of bits in `x`.

*Public API*:

The type itself, the constructors and the accessors are public. The
struct fields are an implementation detail.
"""
mutable struct BigEndian{T} <: EitherEndian{T}
    data::T
    # If T is a Vector, this counts the number of used bits in the
    # last element. For an empty vector the convention is that all
    # bits of the non-existent element are used. For scalar T, all
    # used bits are counted.
    num_bits::Int
    function BigEndian(x::BigInt, n::Integer)
        0 <= n || error("Number of bits outside the range of the data.")
        return new{BigInt}(x, n)
    end
    function BigEndian(x::T, n::Integer) where {T <: Unsigned}
        0 <= n <= 8 * sizeof(T) || error("Number of bits outside the range of the data.")
        return new{T}(x, n)
    end
    function BigEndian(x::Vector{T}, n::Integer) where {T <: Unsigned}
        m = n - 8 * sizeof(T) * (length(x) - 1)
        0 <= m <= 8 * sizeof(T) || error("Number of bits outside the range of the data.")
        return new{Vector{T}}(x, m)
    end
    BigEndian{T}(x::T, n) where {T} = BigEndian(x, n)
end

BigEndian{T}() where {T} = BigEndian(zero(T), 0)
BigEndian{T}() where {T <: Vector} = BigEndian(T(), 0)
BigEndian() = BigEndian{UInt64}()
BigEndian(t::Tuple) = BigEndian(t...)
BigEndian{T}(t::Tuple) where {T} = BigEndian{T}(t...)
BigEndian(x::Vector{T}) where {T <: Unsigned} = BigEndian{Vector{T}}(x, 8 * sizeof(T) * length(x))

function Base.show(io::IO, bits::BigEndian{T}) where T <: Unsigned
    print(io, "BigEndian: $(bits.num_bits) bits 0x",
          string(bits.data, base = 16, pad = 2 * sizeof(T)),
          " (",
          string(bits.data, base = 2, pad = bits.num_bits), ")")
end

function Base.show(io::IO, bits::BigEndian{BigInt})
    print(io, "BigEndian: $(bits.num_bits) bits $(bits.data) (",
          string(bits.data, base = 2, pad = bits.num_bits), ")")
end

function Base.show(io::IO, bits::BigEndian{T}) where T <: Vector
    print(io, "BigEndian $T: ",
          bits.num_bits + 8 * sizeof(eltype(bits.data)) * (length(bits.data) - 1),
          " bits")
end

"""
    LittleEndian{T} where T <: Union{Unsigned, BigInt, Vector{<:Unsigned}}

Data type representing streams of bits in little endian order,
i.e. the least significant bits are considered to be the first
ones. The storage type `T` can be one of an unsigned integer type, a
`BigInt`, and a `Vector` of an unsigned integer type.

*Constructors*:

* `LittleEndian{T}()` - Empty bit stream with storage type `T`
* `LittleEndian()` - Empty bit stream with storage type `UInt64`.
* `LittleEndian(x::T, n::Integer)` - Bit stream containing `n` bits
  stored in `x`. `n` must be a number of bits available in `x`. When
  `x` is a `Vector`, all but the last element must be fully used.
* `LittleEndian((x, n))` - Same as `LittleEndian(x, n)`, for convenience.
* `LittleEndian(x::Vector)` - Bit stream containing all bits available
  in `x`. This constructor is primarily useful when `x` is empty.

*Accessors*:

* `get_data(x::LittleEndian)` - Retrieve the storage for the bits in `x`.
* `get_num_bits(x::LittleEndian)` - Retrieve the number of bits in `x`.

*Public API*:

The type itself, the constructors and the accessors are public. The
struct fields are an implementation detail.
"""
mutable struct LittleEndian{T} <: EitherEndian{T}
    data::T
    # If T is a Vector, this counts the number of used bits in the
    # last element. For an empty vector the convention is that all
    # bits of the non-existent element are used. For scalar T, all
    # used bits are counted.
    num_bits::Int
    function LittleEndian(x::BigInt, n::Integer)
        0 <= n || error("Number of bits outside the range of the data.")
        return new{BigInt}(x, n)
    end
    function LittleEndian(x::T, n::Integer) where {T <: Unsigned}
        0 <= n <= 8 * sizeof(T) || error("Number of bits outside the range of the data.")
        return new{T}(x, n)
    end
    function LittleEndian(x::Vector{T}, n::Integer) where {T <: Unsigned}
        m = n - 8 * sizeof(T) * (length(x) - 1)
        0 <= m <= 8 * sizeof(T) || error("Number of bits outside the range of the data.")
        return new{Vector{T}}(x, m)
    end
    LittleEndian{T}(x::T, n) where {T} = LittleEndian(x, n)
end

LittleEndian{T}() where {T} = LittleEndian(zero(T), 0)
LittleEndian{T}() where {T <: Vector} = LittleEndian(T(), 0)
LittleEndian() = LittleEndian{UInt64}()
LittleEndian(t::Tuple) = LittleEndian(t...)
LittleEndian{T}(t::Tuple) where {T} = LittleEndian{T}(t...)
LittleEndian(x::Vector{T}) where {T <: Unsigned} = LittleEndian{Vector{T}}(x, 8 * sizeof(T) * length(x))

function Base.show(io::IO, bits::LittleEndian{T}) where T <: Unsigned
    print(io, "LittleEndian: $(bits.num_bits) bits 0x",
          string(bits.data, base = 16, pad = 2 * sizeof(T)),
          " (",
          string(bits.data, base = 2, pad = bits.num_bits), ")")
end

function Base.show(io::IO, bits::LittleEndian{BigInt})
    print(io, "LittleEndian: $(bits.num_bits) bits $(bits.data) (",
          string(bits.data, base = 2, pad = bits.num_bits), ")")
end

function Base.show(io::IO, bits::LittleEndian{T}) where T <: Vector
    print(io, "LittleEndian $T: ",
          bits.num_bits + 8 * sizeof(eltype(bits.data)) * (length(bits.data) - 1),
          " bits")
end

is_valid(target::EitherEndian{BigInt}) = true
is_valid(target::EitherEndian{<:Vector}) = true
function is_valid(target::EitherEndian{<:Unsigned})
    return target.num_bits <= 8 * sizeof(target.data)
end
