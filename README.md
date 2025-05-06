# UniversalIntegerCodes

This package implements [Universal Codes for
Integers](https://en.wikipedia.org/wiki/Universal_code_(data_compression)),
i.e. variable-length binary encodings of positive integers, with some
special properties.

The main reason for using these encodings is that if, loosely
speaking, smaller numbers are much more common than larger numbers,
less space is required than by using a fixed-width encoding. I.e.,
this can provide compression in a binary file format for certain types
of data.

A secondary use case is that arbitrarily large integers can be
encoded, which of course can be achieved in many other ways as well.

## Installation

```
using Pkg
Pkg.add("UniversalIntegerCodes")
```

This package has no dependencies and is compatible with all Julia 1.x
versions.

## Example of a Universal Integer Code

One of the oldest and simplest Universal Codes for Integers is the
gamma code by Peter Elias (1975). This encodes a positive integer `n`,
which has `d` binary digits, as `d - 1` zero bits, 1 one bit, followed
by the binary representation of `n` without the most significant one
bit. E.g., if `n = 29`, it has the binary representation `11101` so `d
= 5` and the encoding is `0000` followed by `1` and `1101`,
i.e. `000011101`. Traditionally these codes are written in big-endian
form, i.e. with the most significant bit first. Since most common
computer architectures internally uses little-endian, it can be
advantageous to instead use little-endian encoding, in which case we
need to reverse the order of the pieces, i.e. `1101 1 0000`. (We could
also have just reversed all bits, but that would make the encoding and
decoding less efficient.)

| `n`  | big-endian gamma    | little-endian gamma |
|------|---------------------|---------------------|
| 1    | 1                   | 1                   |
| 2    | 010                 | 010                 |
| 3    | 011                 | 110                 |
| 4    | 00100               | 00100               |
| 5    | 00101               | 01100               |
| 6    | 00110               | 10100               |
| 7    | 00111               | 11100               |
| 8    | 0001000             | 0001000             |
| 9    | 0001001             | 0011000             |
| 10   | 0001010             | 0101000             |
| 11   | 0001011             | 0111000             |
| 12   | 0001100             | 1001000             |
| 13   | 0001101             | 1011000             |
| 14   | 0001110             | 1101000             |
| 15   | 0001111             | 1111000             |
| 16   | 000010000           | 000010000           |
| 1000 | 0000000001111101000 | 1111010001000000000 |

Notice that this, like all Universal Codes, is a prefix code. Once we
have counted the number of leading zeros (or tailing in the
little-endian case) we know how many more bits the code consists of
and don't need any additional information about the code length.

## Exploring the Package

First we import the package and all its exported symbols with

```
using UniversalIntegerCodes
```

Now we can find the big-endian gamma encoding of 29 by doing

```
julia> encode(BigEndian, Gamma(), 29)
(0x000000000000001d, 9)
```

This tells us that the code has 9 binary digits and can be represented
by the 9 least significant bits of the integer 29 (yes, the big-endian
gamma encoding is very predictable in this respect), which is 1d in
hexadecimal form. We can see the bit pattern by wrapping this back in
the `BigEndian` type.

```
julia> BigEndian(encode(BigEndian, Gamma(), 29))
BigEndian: 9 bits 0x000000000000001d (000011101)
```

Similarly we can find the little-endian encoding of 1000 with

```
julia> LittleEndian(encode(LittleEndian, Gamma(), 1000))
LittleEndian: 19 bits 0x000000000007a200 (1111010001000000000)
```

### Target Types

So far we have encoded the numbers into an `UInt64` word. We can
change this to `UInt32` with

```
julia> encode(LittleEndian{UInt32}, Gamma(), 1000)
(0x0007a200, 19)
```

and likewise to all unsigned integer types: `UInt128`, `UInt64`,
`UInt32`, `UInt16`, `UInt8`.

But what happens if we try to encode 1000 into a `UInt16`?

```
julia> encode(BigEndian{UInt16}, Gamma(), 1000)
(0x0000, 0)
```

When the code is claimed to have 0 bits it should be interpreted as an
error; it needed 19 bits but only 16 bits were available. Trying to
encode a zero or a negative number also results in an error.

If we want to encode sufficiently large numbers, not even the 128 bits
of a `UInt128` will be enough. One option is encode into a `BigInt`.

```
julia> BigEndian(encode(BigEndian{BigInt}, Gamma(), UInt128(2)^80))
BigEndian: 161 bits 1208925819614629174706176 (00000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000)
```

Another option is to encode into a `Vector` of some unsigned type.

```
julia> BigEndian(encode(BigEndian{Vector{UInt8}}, Gamma(), UInt128(2)^80))
BigEndian Vector{UInt8}: 161 bits
```

Let's look back at an earlier example.

```
julia> encode(BigEndian{Vector{UInt64}}, Gamma(), 29)
(UInt64[0x0e80000000000000], 9)
```

Why does this look different from before, when it was encoded into
`0x1d`? Thís time the bits are left-justified, which makes most sense
when building a `Vector` of big-endian bits. However,
left-justification is not possible (and doesn't make sense) for
`BigInt`, so there is no way to be fully consistent. The little-endian
case is easier because there right justification of the bits is the
only sensible option.

### Encoding Multiple Values

If we want to encode multiple values into the same target we can do so
with the `encode!` function. Now the target must be created separately.

```
julia> target = BigEndian{UInt32}()
BigEndian: 0 bits 0x00000000 ()

julia> encode!(target, Gamma(), 29)
true

julia> target
BigEndian: 9 bits 0x0000001d (000011101)
```

This looks familiar. Let's continue to add an another value.
```
julia> encode!(target, Gamma(), 1000)
true

julia> target
BigEndian: 28 bits 0x00e803e8 (0000111010000000001111101000)
```

We can recognize the codes for 29 and 1000 being concatenated. We can
access the data and the number of bits with

```
julia> get_data(target)
0x00e803e8

julia> get_num_bits(target)
28
```

However, if we try to encode above the capacity of the target, this
happens.

```
julia> encode!(target, Gamma(), 15)
false

julia> target
BigEndian: 35 bits 0x7401f40f (00001110100000000011111010000001111)
```

`encode!` uses the return value to signal success or failure. In the
case of failure, the state of `target` is undefined and it cannot be
used. When you want to encode many values it's a better idea to use a
`Vector` target, which can grow indefinitely, or at least until you
run out of memory.

### Decoding

Fun as it is to encode integers, we probably want to get the integers
back at some point. This is done with the `decode` function and now
`target` switches role and becomes a `source`. Let's reconstruct the
bitstream encoding 29 followed by 1000 and decode the first value.

```
julia> source = BigEndian(0x00e803e8, 28)
BigEndian: 28 bits 0x00e803e8 (0000111010000000001111101000)

julia> decode(UInt16, Gamma(), source)
(0x001d, 9)
```

The first 9 bits were decoded into 0x1d, i.e. 29.

The source is not modified by `decode`, so to decode the next value we
need to provide a starting offset into the bit stream. Since the first
code consumed 9 bits, we use that as offset.

```
julia> decode(UInt16, Gamma(), source, 9)
(0x03e8, 19)
```

This finds a 19 bit code with the value 1000, or 0x3e8 in hexadecimal.

Decoding can be done into any unsigned type as well as `BigInt`.
`source` can be of any type that can be used a `target` while
encoding.

If we try to decode into a too small type, an error is signaled in the
same way as from `encode`.

```
julia> decode(UInt8, Gamma(), source, 9)
(0x00, 0)
```

The value 1000 doesn't fit in a `UInt8`. Errors can also occur if the
bit stream is truncated or corrupted. However, for a corrupted stream,
valid codes may be found by chance.

### Encoding Natural and Signed Numbers

The Universal Codes for Integers are defined for *positive*
integers. However, it is not uncommon to need to encode natural
numbers, i.e. including zero, or signed integers. The former case is
easily handled by just shifting all values by one. For signed integers
the usual assumption is that small magnitudes are more common than
large magnitudes and that the values can be transformed by a zigzag
mapping, i.e. `0, -1, 1, -2, 2, -3, 3, ...` are mapped to `1, 2, 3, 4,
5, 6, 7, ...`.

These two mappings are built into `encode`, `encode!`, `decode` by
adding a final argument `Unsigned` or `Signed` respectively.

```
julia> encode(BigEndian{UInt16}, Gamma(), 28, Unsigned)
(0x001d, 9)

julia> decode(UInt32, Gamma(), BigEndian(0x001d, 9), Unsigned)
(0x0000001c, 9)

julia> encode(BigEndian{UInt16}, Gamma(), -7, Signed)
(0x000e, 7)

julia> decode(Int32, Gamma(), BigEndian(0x000e, 7), 0, Signed)
(-7, 7)
```

In the `Signed` case, the type to decode into must be a signed type,
and internally the decoding is done to the unsigned type with the same
number of bits. (In these contexts, `BigInt` counts as both signed and
unsigned.)

If you need to do any other transformation of your data onto the
positive integers, you can do so outside of the encoding and decoding
functions.

### Codes

Six types of codes are implemented.

* Peter Elias
  [gamma](https://en.wikipedia.org/wiki/Elias_gamma_coding),
  [delta](https://en.wikipedia.org/wiki/Elias_omega_coding), and
  [omega](https://en.wikipedia.org/wiki/Elias_omega_coding) codes.
* [Fibonacci](https://en.wikipedia.org/wiki/Fibonacci_coding) code.
* [Zeta](https://vigna.di.unimi.it/ftp/papers/Codes.pdf) codes by by Boldi and Vigna.
* [BL](https://www.mdpi.com/1424-8220/18/10/3314) codes by Jung Hoon Kim, et al.

The latter two types of codes are parametric families, where the
parameter can be any positive integer, although small numbers are
likely to be most useful. The Zeta(1) code coincides with Elias gamma
code.

```
julia> BigEndian(encode(BigEndian, Zeta(1), 29))
BigEndian: 9 bits 0x000000000000001d (000011101)

julia> BigEndian(encode(BigEndian, Zeta(3), 29))
BigEndian: 8 bits 0x000000000000005d (01011101)
```

### Public API

The public API is given by the exported symbols. Struct fields are
considered as implementation details and are not part of the public
API, even if the struct itself is.