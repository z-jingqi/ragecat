# Sprite Fusion compatibility primitives. MIT, original effects © 2026 Hugo Duprez.
# All simulation scalars are Godot float (IEEE binary64), never Vector2/float32.
extends RefCounted

const PX: int = 2
const U32_MASK: int = 0xffffffff
const U32_MOD: float = 4294967296.0
const BAYER: Array[int] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

static func u32(value) -> int:
	if value is int:
		return value & U32_MASK
	var n: float = float(value)
	if not is_finite(n) or n == 0.0:
		return 0
	return int(fmod(floor(n) if n >= 0.0 else ceil(n), U32_MOD)) & U32_MASK

static func i32(value) -> int:
	var n: int = u32(value)
	return n - 0x100000000 if n >= 0x80000000 else n

static func ushr(value, bits) -> int:
	return u32(value) >> (u32(bits) & 31)

static func shl(value, bits) -> int:
	return i32(u32(value) << (u32(bits) & 31))

static func imul(a, b) -> int:
	# 16-bit limbs avoid overflowing Godot's signed int64 at uint32 extremes.
	var x: int = u32(a)
	var y: int = u32(b)
	var low: int = (x & 65535) * (y & 65535)
	var cross: int = (((x >> 16) * (y & 65535)) + ((y >> 16) * (x & 65535))) & 65535
	return i32(low + (cross << 16))

static func js_round(value: float) -> int:
	# Godot round(-0.5) is -1; JavaScript Math.round(-0.5) is -0.
	var base: float = floor(value)
	return int(base + 1.0) if value - base >= 0.5 else int(base)

static func rgb(r, g, b, a = 255) -> int:
	return ((u32(a) & 255) << 24) | ((u32(b) & 255) << 16) | ((u32(g) & 255) << 8) | (u32(r) & 255)

static func hex(text: String) -> int:
	var n: int = text.trim_prefix("#").hex_to_int()
	return rgb((n >> 16) & 255, (n >> 8) & 255, n & 255)

static func mix(c1: int, c2: int, t: float) -> int:
	var u: float = 1.0 - t
	return rgb((c1 & 255) * u + (c2 & 255) * t, ((c1 >> 8) & 255) * u + ((c2 >> 8) & 255) * t, ((c1 >> 16) & 255) * u + ((c2 >> 16) & 255) * t, ((c1 >> 24) & 255) * u + ((c2 >> 24) & 255) * t)

static func ramp(stops, t: float) -> int:
	var u: float = maxf(0.0, minf(0.9999, t)) * (stops.size() - 1)
	var i: int = int(floor(u))
	return mix(stops[i], stops[i + 1], u - i)

static func smooth(a: float, b: float, x: float) -> float:
	var t: float = clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

static func source_hash(n: float, k: float = 0.0) -> float:
	return float(u32(imul(n + 1.0 + k * 7919.0, 2654435761)) % 100000) / 100000.0

static func hash_muzzle(n: float, k: float = 0.0) -> float:
	# Muzzle flash alone truncates n and floors k before multiplication.
	return float(u32(imul(float(i32(n)) + 1.0 + floor(k) * 7919.0, 2654435761)) % 100000) / 100000.0

static func noise(x: float, seed: float = 0.0) -> float:
	var i: float = floor(x)
	var f: float = x - i
	var u: float = f * f * (3.0 - 2.0 * f)
	var a: float = source_hash(i, seed) * 2.0 - 1.0
	return a + (source_hash(i + 1.0, seed) * 2.0 - 1.0 - a) * u

static func bayer(x, y) -> float:
	return (BAYER[((i32(y) & 3) << 2) | (i32(x) & 3)] + 0.5) / 16.0

static func hash(n: float, k: float = 0.0) -> float:
	return source_hash(n, k)
