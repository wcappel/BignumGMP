//
//  BigInt.swift
//  BignumGMP
//
#if os(Linux)
	import Glibc
#else
	import Darwin
#endif
import CGMP

/// Big Integer type backed by `mpz_t`
public class BigInt: ExpressibleByIntegerLiteral, Codable {
	/// Literal type to make this expressible by integer literal
	public typealias IntegerLiteralType = Int64

	/// Underlying `mpz_t` big integer instance
	var mpz: mpz_t

	/// Default initialiser, sets value to zero
	public init() { mpz = mpz_t() ; __gmpz_init(&mpz) }

	/// Initialise a `BigInt` from an `Int`
	public init(_ i: Int) {
		mpz = mpz_t() ; __gmpz_init_set_si(&mpz, CLong(i))
	}

	/// Initialise a `BigInt` from a `UInt`
	public init(_ i: UInt) {
		mpz = mpz_t() ; __gmpz_init_set_ui(&mpz, CUnsignedLong(i))
	}

	/// Initialise from an integer literal
	public required init(integerLiteral value: Int64) {
		mpz = mpz_t();
		if value <= Int64(Int.max) && value >= Int64(Int.min) {
			__gmpz_init_set_si(&mpz, CLong(value))
		} else {
			__gmpz_init_set_str(&mpz, "\(value)", 10);
		}
	}

	/// Free the underlying `mpz_t` big integer
	deinit { __gmpz_clear(&mpz) }

    /// Initialise from decoding the hex representation to conform to Decodable
    public required convenience init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        self.init(hex: try container.decode(String.self))
    }

    /// Encode the hex representation to conform to Encodable
    public func encode(to encoder: Encoder) throws {
        guard self.sign != -1 else {
            throw EncodingError.invalidValue(self, .init(codingPath: encoder.codingPath,
                                                         debugDescription: "Cannot encode negative values"))
        }
        var container = encoder.unkeyedContainer()
        try container.encode(self.hex)
    }

	/// Compare two `BigInt`'s
	///
	/// - Parameter other: value to compare the receiver with
	/// - Returns: `0` iff `self == other`, negative value iff `self < other`, posibive value iff `self > other`
	public func compare(_ other: BigInt) -> Int {
		return Int(__gmpz_cmp(&mpz, &other.mpz))
	}
}

// MARK: - Comparable
// For perfomance reasons, this implements all five comparison operators
extension BigInt: Comparable {
	/// Return true if `lhs` == `rhs`
	public static func ==(lhs: BigInt, rhs: BigInt) -> Bool {
		return lhs.compare(rhs) == 0
	}

	/// Return true if `lhs` < `rhs`
	public static func <(lhs: BigInt, rhs: BigInt) -> Bool {
		return lhs.compare(rhs) < 0
	}

	/// Return true if `lhs` > `rhs`
	public static func >(lhs: BigInt, rhs: BigInt) -> Bool {
		return lhs.compare(rhs) > 0
	}

	/// Return true if `lhs` <= `rhs`
	public static func <=(lhs: BigInt, rhs: BigInt) -> Bool {
		return lhs.compare(rhs) <= 0
	}

	/// Return true if `lhs` >= `rhs`
	public static func >=(lhs: BigInt, rhs: BigInt) -> Bool {
		return lhs.compare(rhs) >= 0
	}
}



// MARK: - CustomStringConvertible
extension BigInt: CustomStringConvertible {
	/// Decimal string representation
	public var description: String { return dec }
}


// MARK: - Convenience properties
public extension BigInt {
	/// String representation with the given base
	func string(base: CInt = 10) -> String {
		let sp = __gmpz_get_str(nil, base, &mpz)!
		let s = String(validatingUTF8: sp)!
		free(sp)
		return s
	}

	/// Decimal string representation
	public var dec: String { return string() }

	/// Hexadecimal string representation
	public var hex: String { return string(base: 16) }

	/// Initialise from a decimal string
	public convenience init(_ dec: String) {
		self.init()
		__gmpz_init_set_str(&mpz, dec, 10);
	}

	/// Initialise from a hexadecimal string
	public convenience init(hex: String) {
		self.init()
		__gmpz_init_set_str(&mpz, hex, 16);
	}

	/// Check if the given number is positive (> 0)
	public func isPositive() -> Bool {
		return mpz._mp_size > 0
	}

	/// Check if the given number is negative (< 0)
	public func isNegative() -> Bool {
		return mpz._mp_size < 0
	}

	/// Check if the given number is zero
	public func isZero() -> Bool {
		return mpz._mp_size == 0
	}

	/// Check if the given number is zero
	public func isNonNegative() -> Bool {
		return isPositive() || isZero()
	}

	/// Sign of the receiver:
	/// `0` if zero,
	/// `-1` if negative,
	/// `+1` if positive
	public var sign: Int {
		return isZero() ? 0 : (isPositive() ? 1 : -1)
	}

	/// Return whether the receiver is odd
	///
	/// - Returns: true iff `self % 2 == 1`
	public func isOdd() -> Bool {
		guard !isZero() else { return false }
		return mpz._mp_d[0] % 2 != 0
	}

	/// Return whether the receiver is even
	///
	/// - Returns: true iff `self % 2 == 0`
	public func isEven() -> Bool {
		return !isOdd()
	}

    /// Return whether the receiver is definitely prime
    /// About `reps` see `isProbablyPrime`
    ///
    /// - Parameter `reps`: number of probabilistic prime tests
    /// - Parameter `secure`: whether answer is definite (`true`) or probabilistic (`false`)
    /// - Returns: `true` iff receiver is (probably or definitely) prime, `false` otherwise
    public func isPrime(rounds: Int = 15, secure: Bool = false) -> Bool {
        let isProbPrime = isProbablyPrime(rounds: rounds)
        return secure ? isProbPrime == 2 : isProbPrime > 0
    }

    /// Return if the receiver is probably prime
    /// This function performs some trial divisions,
    /// then `reps` Miller-Rabin probabilistic primality tests.
    /// A higher `reps` value will reduce the chances of a non-prime
    /// being identified as “probably prime”.
    /// Reasonable values of reps are between 15 and 50.
    ///
    /// - Returns: `2` (definitely prime), `1` (probably prime), `0` (definitely non-prime)
    public func isProbablyPrime(rounds: Int = 15) -> Int {
        return Int(__gmpz_probab_prime_p(&mpz, Int32(rounds)))
    }
    
    public func bitSize() -> Int {
        return Int(__gmpz_sizeinbase(&self.mpz, 2))
    }
    
    public static func nextPrime(_ n: BigInt) -> BigInt {
        let r = BigInt()
        __gmpz_nextprime(&r.mpz, &n.mpz)
        return r
    }
    
    public static func randomInt(limit: BigInt) -> BigInt {
        let r = BigInt()
        var state = gmp_randstate_t()
        __gmp_randinit_mt(&state)
        __gmp_randseed_ui(&state, UInt.random(in: 0...UInt.max));
        __gmpz_urandomm(&r.mpz, &state, &limit.mpz)
        return r
    }
    
    public static func randomInt(bits: UInt) -> BigInt {
        let r = BigInt()
        var state = gmp_randstate_t()
        __gmp_randinit_mt(&state)
        __gmp_randseed_ui(&state, UInt.random(in: 0...UInt.max));
        __gmpz_urandomb(&r.mpz, &state, bits)
        return r
    }
}

// MARK: - Arithmetic operations
/// Unary minus
public prefix func -(i: BigInt) -> BigInt {
	let r = BigInt()
	__gmpz_neg(&r.mpz, &i.mpz)
	return r
}

/// Add two `BigInt` numbers
public func +(lhs: BigInt, rhs: BigInt) -> BigInt {
	let r = BigInt()
	__gmpz_add(&r.mpz, &lhs.mpz, &rhs.mpz)
	return r
}

/// Subtract two `BigInt` numbers
public func -(lhs: BigInt, rhs: BigInt) -> BigInt {
	let r = BigInt()
	__gmpz_sub(&r.mpz, &lhs.mpz, &rhs.mpz)
	return r
}

/// Multiply two `BigInt` numbers
public func *(lhs: BigInt, rhs: BigInt) -> BigInt {
	let r = BigInt()
	__gmpz_mul(&r.mpz, &lhs.mpz, &rhs.mpz)
	return r
}

/// Divide two `BigInt` numbers and round to zero
public func /(lhs: BigInt, rhs: BigInt) -> BigInt {
	let r = BigInt()
	__gmpz_tdiv_q(&r.mpz, &lhs.mpz, &rhs.mpz)
	return r
}


/// Add an unsigned Integer to a `BigInt` number
public func +(lhs: BigInt, rhs: UInt) -> BigInt {
	let r = BigInt()
	__gmpz_add_ui(&r.mpz, &lhs.mpz, CUnsignedLong(rhs))
	return r
}

/// Subtract an unsigned Integer to a `BigInt` number
public func -(lhs: BigInt, rhs: UInt) -> BigInt {
	let r = BigInt()
	__gmpz_sub_ui(&r.mpz, &lhs.mpz, CUnsignedLong(rhs))
	return r
}

/// Multiply a `BigInt` number by an unsigned integer
public func *(lhs: BigInt, rhs: UInt) -> BigInt {
	let r = BigInt()
	__gmpz_mul_ui(&r.mpz, &lhs.mpz, CUnsignedLong(rhs))
	return r
}

/// Divide a `BigInt` number by an unsigned integer, rounding to zero
public func /(lhs: BigInt, rhs: UInt) -> BigInt {
	let r = BigInt()
	__gmpz_tdiv_q_ui(&r.mpz, &lhs.mpz, CUnsignedLong(rhs))
	return r
}


/// Add a `BigInt` number to an unsigned integer
public func +(lhs: UInt, rhs: BigInt) -> BigInt {
	let r = BigInt()
	__gmpz_add_ui(&r.mpz, &rhs.mpz, CUnsignedLong(lhs))
	return r
}

/// Subtract a `BigInt` number from an unsigned Integer
public func -(lhs: UInt, rhs: BigInt) -> BigInt {
	let r = BigInt()
	__gmpz_ui_sub(&r.mpz, CUnsignedLong(lhs), &rhs.mpz)
	return r
}

/// Multiply an unsigned integer by a `BigInt` number
public func *(lhs: UInt, rhs: BigInt) -> BigInt {
	let r = BigInt()
	__gmpz_mul_ui(&r.mpz, &rhs.mpz, CUnsignedLong(lhs))
	return r
}

/// Divide an unsigned integer by a `BigInt` number, rounding to zero
public func /(lhs: UInt, rhs: BigInt) -> BigInt {
	let l = BigInt(lhs)
	let r = BigInt()
	__gmpz_tdiv_q(&r.mpz, &l.mpz, &rhs.mpz)
	return r
}


/// Add a signed Integer to a `BigInt` number
public func +(lhs: BigInt, rhs: Int) -> BigInt {
	let r = BigInt()
	if rhs >= 0 {
		__gmpz_add_ui(&r.mpz, &lhs.mpz, CUnsignedLong(rhs))
	} else {
		__gmpz_sub_ui(&r.mpz, &lhs.mpz, CUnsignedLong(abs(rhs)))
	}
	return r
}

/// Subtract a signed Integer to a `BigInt` number
public func -(lhs: BigInt, rhs: Int) -> BigInt {
	let r = BigInt()
	if rhs >= 0 {
		__gmpz_sub_ui(&r.mpz, &lhs.mpz, CUnsignedLong(rhs))
	} else {
		__gmpz_add_ui(&r.mpz, &lhs.mpz, CUnsignedLong(abs(rhs)))
	}
	return r
}

/// Multiply a `BigInt` number by a signed integer
public func *(lhs: BigInt, rhs: Int) -> BigInt {
	let r = BigInt()
	__gmpz_mul_si(&r.mpz, &lhs.mpz, CLong(rhs))
	return r
}

/// Divide a `BigInt` number by a signed integer, rounding to zero
public func /(lhs: BigInt, rhs: Int) -> BigInt {
	let r = BigInt()
	__gmpz_tdiv_q_ui(&r.mpz, &lhs.mpz, CUnsignedLong(abs(rhs)))
	if rhs < 0 { __gmpz_neg(&r.mpz, &r.mpz) }
	return r
}


/// Add a `BigInt` number to a signed integer
public func +(lhs: Int, rhs: BigInt) -> BigInt {
	let r = BigInt()
	if rhs >= 0 {
		__gmpz_add_ui(&r.mpz, &rhs.mpz, CUnsignedLong(lhs))
	} else {
		__gmpz_sub_ui(&r.mpz, &rhs.mpz, CUnsignedLong(abs(lhs)))
	}
	return r
}

/// Subtract a `BigInt` number from a signed Integer
public func -(lhs: Int, rhs: BigInt) -> BigInt {
	let r = BigInt()
	if lhs >= 0 {
		__gmpz_ui_sub(&r.mpz, CUnsignedLong(lhs), &rhs.mpz)
	} else {
		let l = BigInt(lhs)
		__gmpz_sub(&r.mpz, &l.mpz, &rhs.mpz)
	}
	return r
}

/// Multiply a signed integer by a `BigInt` number
public func *(lhs: Int, rhs: BigInt) -> BigInt {
	let r = BigInt()
	__gmpz_mul_si(&r.mpz, &rhs.mpz, CLong(lhs))
	return r
}

/// Divide a signed integer by a `BigInt` number, rounding to zero
public func /(lhs: Int, rhs: BigInt) -> BigInt {
	let l = BigInt(lhs)
	let r = BigInt()
	__gmpz_tdiv_q(&r.mpz, &l.mpz, &rhs.mpz)
	return r
}

// MARK: - Modulo operations

/// Divide two `BigInt` numbers and return the remainder
public func %(lhs: BigInt, rhs: BigInt) -> BigInt {
	let r = BigInt()
	__gmpz_tdiv_r(&r.mpz, &lhs.mpz, &rhs.mpz)
	return r
}

/// Divide a `BigInt` number by a `UInt` and return the remainder as a `UInt`
public func %(lhs: BigInt, rhs: UInt) -> UInt {
	let r = BigInt()
	return UInt(__gmpz_tdiv_r_ui(&r.mpz, &lhs.mpz, CUnsignedLong(rhs)))
}


/// Non-negative modulo operation
///
/// - Parameters:
///   - a: left hand side of the module operation
///   - m: modulus
/// - Returns: r := a % b such that 0 <= r < abs(m)
public func nnmod(_ a: BigInt, _ m: BigInt) -> BigInt {
	let r = BigInt()
	__gmpz_mod(&r.mpz, &a.mpz, &m.mpz)
	return r
}


/// Return the non-negative (a + b) % m
public func mod_add(_ a: BigInt, _ b: BigInt, _ m: BigInt) -> BigInt {
	return nnmod((a + b), m)
}

/// Quick exponentiation/modulo algorithm.algorith.
/// This uses the secure (constant time) algorithm `mpz_powm_sec` iff
/// `p > 0` and `m` is odd.
///
/// - Parameters:
///   - b: base
///   - p: power
///   - m: modulus
/// - Returns: pow(b, p) % m
public func mod_exp(_ b: BigInt, _ p: BigInt, _ m: BigInt) -> BigInt {
	let r = BigInt()
	if p.isPositive() && m.isOdd() {
		__gmpz_powm_sec(&r.mpz, &b.mpz, &p.mpz, &m.mpz)
	} else {
		__gmpz_powm(&r.mpz, &b.mpz, &p.mpz, &m.mpz)
	}
	return r
}

/// Quick exponentiation/modulo algorithm
///
/// - Parameters:
///   - b: base
///   - p: power
///   - m: modulus
/// - Returns: pow(b, p) % m
public func mod_exp(_ b: BigInt, _ p: UInt, _ m: BigInt) -> BigInt {
	let r = BigInt()
	__gmpz_powm_ui(&r.mpz, &b.mpz, CUnsignedLong(p), &m.mpz)
	return r
}

/// Inverse number operation
///
/// - Parameters:
///   - a: number to invert
///   - m: modulus
/// - Returns: a^(-1) % m
public func inverse(_ a: BigInt, _ m: BigInt) -> BigInt? {
    let r = BigInt()
    __gmpz_invert(&r.mpz, &a.mpz, &m.mpz)
    return r
}
