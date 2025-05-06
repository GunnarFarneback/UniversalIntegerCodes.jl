"""
    UniversalIntegerCodes

Package for encoding and decoding *positive integers* as binary bit
streams, using so called Universal Codes for Integers.

* API functions: `encode!`, `encode`, `decode`.
* Data containers: `LittleEndian`, `BigEndian`, `get_data`, `get_num_bits`.
* Codes: `Gamma`, `Delta`, `Omega`, `Fibonacci`, `Zeta`, `BL`.
"""
module UniversalIntegerCodes

export encode!, encode, decode
export EitherEndian, LittleEndian, BigEndian, get_data, get_num_bits
export UniversalIntegerCode, Gamma, Delta, Omega, Fibonacci, Zeta, BL

"""
    UniversalIntegerCode

Abstract supertype for the Universal Integer Codes:
* `Gamma`
* `Delta`
* `Omega`
* `Fibonacci`
* `Zeta`
* `BL`
"""
abstract type UniversalIntegerCode end

include("endians.jl")
include("encode.jl")
include("decode.jl")
include("codes/elias.jl")
include("codes/fibonacci.jl")
include("codes/zeta.jl")
include("codes/bl.jl")

end
