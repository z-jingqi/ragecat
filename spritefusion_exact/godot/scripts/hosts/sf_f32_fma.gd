# Exact finite-input binary32 fused multiply-add using binary64 arithmetic.
# Used by the highp fill pipeline; image stages retain separate arithmetic.
# All inputs must already be finite binary32 values. The output is IEEE-754
# round-to-nearest, ties-to-even, including signed zero, subnormals and overflow.
# Intended source sites are Skia's explicit highp mad operations, uniformly.
# No browser, external library, lookup table or pixel-dependent choice is used.
extends RefCounted

const MAX_FINITE: float = 3.4028234663852885981170418348451692544e38
# max-finite + half its ULP = 2^128 - 2^103, exactly representable in binary64.
const OVERFLOW_MIDPOINT: float = 3.40282356779733661637539395458142568448e38

var _single := PackedFloat32Array([0.0])
var _bits := PackedByteArray([0, 0, 0, 0])

func _f32(value: float) -> float:
	_single[0] = value
	return _single[0]

func _to_bits(value: float) -> int:
	_bits.encode_float(0, value)
	return _bits.decode_u32(0)

func _from_bits(value: int) -> float:
	_bits.encode_u32(0, value)
	return _bits.decode_float(0)

func mad(a: float, b: float, c: float) -> float:
	assert(is_finite(a) and is_finite(b) and is_finite(c), "SfF32Fma requires finite operands")
	assert(_f32(a) == a and _f32(b) == b and _f32(c) == c, "SfF32Fma operands must already be binary32")
	# The exact product has at most 48 significant bits and exponent range
	# [-298,256), so every finite binary32 product is exact in binary64.
	var product: float = a * b
	var sum: float = product + c
	# Error-free TwoSum: sum + residual is the exact real product+c. Every
	# intermediate remains well inside binary64's exponent range, including
	# products of the smallest binary32 subnormals. Keep separate operations.
	var virtual_c: float = sum - product
	var residual: float = (product - (sum - virtual_c)) + (c - virtual_c)
	# The finite/infinite rounding boundary needs explicit treatment because
	# an adjacent infinity cannot be used in a numerical midpoint expression.
	if sum >= OVERFLOW_MIDPOINT:
		return MAX_FINITE if sum == OVERFLOW_MIDPOINT and residual < 0.0 else INF
	if sum <= -OVERFLOW_MIDPOINT:
		return -MAX_FINITE if sum == -OVERFLOW_MIDPOINT and residual > 0.0 else -INF
	var rounded: float = _f32(sum)
	if residual == 0.0 or sum == rounded:
		# Returning the cast retains the correct sign of a zero. In particular,
		# (-0 * positive)+(-0) is -0, while exact nonzero cancellation is +0.
		return rounded
	var rounded_bits: int = _to_bits(rounded)
	var adjacent_bits: int
	if sum > rounded:
		adjacent_bits = rounded_bits + (1 if rounded >= 0.0 else -1)
	else:
		adjacent_bits = rounded_bits + (-1 if rounded > 0.0 else 1)
	var adjacent: float = _from_bits(adjacent_bits)
	var midpoint: float = 0.5 * (rounded + adjacent)
	if sum == midpoint:
		# Only an exactly represented binary32 midpoint can be double-rounded
		# incorrectly. The residual sign selects its correct neighboring float.
		return maxf(rounded, adjacent) if residual > 0.0 else minf(rounded, adjacent)
	return rounded
