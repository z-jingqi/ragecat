# V8/fdlibm binary64 trigonometry, ported without changing operation order.
# Source: https://raw.githubusercontent.com/v8/v8/13.6.233/src/base/ieee754.cc
# Copyright (C) 1993 by Sun Microsystems, Inc. All rights reserved.
# Developed at SunSoft, a Sun Microsystems, Inc. business.
# Permission to use, copy, modify, and distribute this software is freely
# granted, provided that this notice is preserved.
# The original source has been modified significantly by Google Inc.
# Copyright 2016 the V8 project authors. All rights reserved.
# V8-derived code is additionally covered by LICENSE.v8.txt in this directory.
extends RefCounted

static var TWO_N27: float = _words(0x3e400000, 0)
static var invpio2: float = _words(0x3FE45F30, 0x6DC9C883)
static var pio2_1: float = _words(0x3FF921FB, 0x54400000)
static var pio2_1t: float = _words(0x3DD0B461, 0x1A626331)
static var pio2_2: float = _words(0x3DD0B461, 0x1A600000)
static var pio2_2t: float = _words(0x3BA3198A, 0x2E037073)
static var pio2_3: float = _words(0x3BA3198A, 0x2E000000)
static var pio2_3t: float = _words(0x397B839A, 0x252049C1)
static var C1: float = _words(0x3FA55555, 0x5555554C)
static var C2: float = _words(0xBF56C16C, 0x16C15177)
static var C3: float = _words(0x3EFA01A0, 0x19CB1590)
static var C4: float = _words(0xBE927E4F, 0x809C52AD)
static var C5: float = _words(0x3E21EE9E, 0xBDB4B1C4)
static var C6: float = _words(0xBDA8FAE9, 0xBE8838D4)
static var S1: float = _words(0xBFC55555, 0x55555549)
static var S2: float = _words(0x3F811111, 0x1110F8A6)
static var S3: float = _words(0xBF2A01A0, 0x19C161D5)
static var S4: float = _words(0x3EC71DE3, 0x57B1FE7D)
static var S5: float = _words(0xBE5AE5E6, 0x8A2B9CEB)
static var S6: float = _words(0x3DE5D93A, 0x5ACFD57C)
const TWO_OVER_PI: Array[int] = [0xA2F983, 0x6E4E44, 0x1529FC, 0x2757D1, 0xF534DD, 0xC0DB62, 0x95993C, 0x439041, 0xFE5163, 0xABDEBB, 0xC561B7, 0x246E3A, 0x424DD2, 0xE00649, 0x2EEA09, 0xD1921C, 0xFE1DEB, 0x1CB129, 0xA73EE8, 0x8235F5, 0x2EBB44, 0x84E99C, 0x7026B4, 0x5F7E41, 0x3991D6, 0x398353, 0x39F49C, 0x845F8B, 0xBDF928, 0x3B1FF8, 0x97FFDE, 0x05980F, 0xEF2F11, 0x8B5A0A, 0x6D1F6D, 0x367ECF, 0x27CB09, 0xB74F46, 0x3F669E, 0x5FEA2D, 0x7527BA, 0xC7EBE5, 0xF17B3D, 0x0739F7, 0x8A5292, 0xEA6BFB, 0x5FB11F, 0x8D5D08, 0x560330, 0x46FC7B, 0x6BABF0, 0xCFBC20, 0x9AF436, 0x1DA9E3, 0x91615E, 0xE61B08, 0x659985, 0x5F14A0, 0x68408D, 0xFFD880, 0x4D7327, 0x310606, 0x1556CA, 0x73A8C9, 0x60E27B, 0xC08C6B]
const NPIO2_HW: Array[int] = [0x3FF921FB, 0x400921FB, 0x4012D97C, 0x401921FB, 0x401F6A7A, 0x4022D97C, 0x4025FDBB, 0x402921FB, 0x402C463A, 0x402F6A7A, 0x4031475C, 0x4032D97C, 0x40346B9C, 0x4035FDBB, 0x40378FDB, 0x403921FB, 0x403AB41B, 0x403C463A, 0x403DD85A, 0x403F6A7A, 0x40407E4C, 0x4041475C, 0x4042106C, 0x4042D97C, 0x4043A28C, 0x40446B9C, 0x404534AC, 0x4045FDBB, 0x4046C6CB, 0x40478FDB, 0x404858EB, 0x404921FB]
static var PI_O2: Array[float] = [_words(0x3FF921FB,0x40000000), _words(0x3E74442D,0x00000000), _words(0x3CF84698,0x80000000), _words(0x3B78CC51,0x60000000), _words(0x39F01B83,0x80000000), _words(0x387A2520,0x40000000), _words(0x36E38222,0x80000000), _words(0x3569F31D,0x00000000)]

static func _words(hi: int, lo: int) -> float:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(8)
	bytes.encode_u32(0, lo & 0xffffffff)
	bytes.encode_u32(4, hi & 0xffffffff)
	return bytes.decode_double(0)

static func _high(value: float) -> int:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(8)
	bytes.encode_double(0, value)
	return bytes.decode_u32(4)

static func _low(value: float) -> int:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(8)
	bytes.encode_double(0, value)
	return bytes.decode_u32(0)

static func _scalbn(value: float, exponent: int) -> float:
	# The argument-reduction routine only requests normal exact powers of two.
	return value * _words((exponent + 1023) << 20, 0)

static func _kernel_sin(x: float, y: float, iy: int) -> float:
	if absf(x) < TWO_N27:
		return x
	var z: float = x * x
	var v: float = z * x
	var r: float = S2 + z * (S3 + z * (S4 + z * (S5 + z * S6)))
	if iy == 0:
		return x + v * (S1 + z * r)
	return x - ((z * (0.5 * y - v * r) - y) - v * S1)

static func _kernel_cos(x: float, y: float) -> float:
	var ix: int = _high(x) & 0x7fffffff
	if ix < 0x3e400000:
		return 1.0
	var z: float = x * x
	var r: float = z * (C1 + z * (C2 + z * (C3 + z * (C4 + z * (C5 + z * C6)))))
	if ix < 0x3fd33333:
		return 1.0 - (0.5 * z - (z * r - x * y))
	var qx: float = 0.28125 if ix > 0x3fe90000 else _words(ix - 0x00200000, 0)
	var iz: float = 0.5 * z - qx
	var a: float = 1.0 - qx
	return a - (iz - (z * r - x * y))

static func sinv(x: float) -> float:
	var ix: int = _high(x) & 0x7fffffff
	if ix <= 0x3fe921fb:
		return _kernel_sin(x, 0.0, 0)
	if ix >= 0x7ff00000:
		return x - x
	var reduced: Array = _rem_pio2(x)
	match int(reduced[0]) & 3:
		0: return _kernel_sin(reduced[1], reduced[2], 1)
		1: return _kernel_cos(reduced[1], reduced[2])
		2: return -_kernel_sin(reduced[1], reduced[2], 1)
		_: return -_kernel_cos(reduced[1], reduced[2])

static func cosv(x: float) -> float:
	var ix: int = _high(x) & 0x7fffffff
	if ix <= 0x3fe921fb:
		return _kernel_cos(x, 0.0)
	if ix >= 0x7ff00000:
		return x - x
	var reduced: Array = _rem_pio2(x)
	match int(reduced[0]) & 3:
		0: return _kernel_cos(reduced[1], reduced[2])
		1: return -_kernel_sin(reduced[1], reduced[2], 1)
		2: return -_kernel_cos(reduced[1], reduced[2])
		_: return _kernel_sin(reduced[1], reduced[2], 1)

# Returns [quadrant, leading remainder, trailing remainder]. No native trig fallback.
static func _rem_pio2(x: float) -> Array:
	var hx: int = _high(x)
	var ix: int = hx & 0x7fffffff
	var negative: bool = (hx & 0x80000000) != 0
	var y0: float = 0.0
	var y1: float = 0.0
	var z: float = 0.0
	if ix <= 0x3fe921fb:
		return [0, x, 0.0]
	if ix < 0x4002d97c:
		if not negative:
			z = x - pio2_1
			if ix != 0x3ff921fb:
				y0 = z - pio2_1t
				y1 = (z - y0) - pio2_1t
			else:
				z -= pio2_2
				y0 = z - pio2_2t
				y1 = (z - y0) - pio2_2t
			return [1, y0, y1]
		z = x + pio2_1
		if ix != 0x3ff921fb:
			y0 = z + pio2_1t
			y1 = (z - y0) + pio2_1t
		else:
			z += pio2_2
			y0 = z + pio2_2t
			y1 = (z - y0) + pio2_2t
		return [-1, y0, y1]
	if ix <= 0x413921fb:
		var t: float = absf(x)
		var n: int = int(t * invpio2 + 0.5)
		var fn: float = float(n)
		var r: float = t - fn * pio2_1
		var w: float = fn * pio2_1t
		y0 = r - w
		if not (n < 32 and ix != NPIO2_HW[n - 1]):
			var j: int = ix >> 20
			var i: int = j - ((_high(y0) >> 20) & 0x7ff)
			if i > 16:
				t = r
				w = fn * pio2_2
				r = t - w
				w = fn * pio2_2t - ((t - r) - w)
				y0 = r - w
				i = j - ((_high(y0) >> 20) & 0x7ff)
				if i > 49:
					t = r
					w = fn * pio2_3
					r = t - w
					w = fn * pio2_3t - ((t - r) - w)
					y0 = r - w
		y1 = (r - y0) - w
		return [-n, -y0, -y1] if negative else [n, y0, y1]
	if ix >= 0x7ff00000:
		return [0, NAN, NAN]
	var e0: int = (ix >> 20) - 1046
	z = _words(ix - (e0 << 20), _low(x))
	var tx: Array[float] = [0.0, 0.0, 0.0]
	for i in range(2):
		tx[i] = float(int(z))
		z = (z - tx[i]) * 16777216.0
	tx[2] = z
	var nx: int = 3
	while tx[nx - 1] == 0.0:
		nx -= 1
	var result: Array = _kernel_rem_pio2(tx, e0, nx)
	if negative:
		return [-int(result[0]), -float(result[1]), -float(result[2])]
	return result

static func _kernel_rem_pio2(x: Array[float], e0: int, nx: int) -> Array:
	# Precision 2 is the sole caller in V8's double-precision sin/cos path.
	const JK: int = 4
	const TWO24: float = 16777216.0
	var twon24: float = _words(0x3e700000, 0)
	var iq: Array[int] = []
	var f: Array[float] = []
	var fq: Array[float] = []
	var q: Array[float] = []
	iq.resize(20)
	f.resize(20)
	fq.resize(20)
	q.resize(20)
	iq.fill(0)
	f.fill(0.0)
	fq.fill(0.0)
	q.fill(0.0)
	var jx: int = nx - 1
	var jv: int = maxi(0, int(float(e0 - 3) / 24.0))
	var q0: int = e0 - 24 * (jv + 1)
	var j: int = jv - jx
	for i in range(jx + JK + 1):
		f[i] = 0.0 if j < 0 else float(TWO_OVER_PI[j])
		j += 1
	var fw: float = 0.0
	for i in range(JK + 1):
		fw = 0.0
		for jj in range(jx + 1):
			fw += x[jj] * f[jx + i - jj]
		q[i] = fw
	var jz: int = JK
	var z: float = 0.0
	var n: int = 0
	var ih: int = 0
	while true:
		z = q[jz]
		var ii: int = 0
		for jj in range(jz, 0, -1):
			fw = float(int(twon24 * z))
			iq[ii] = int(z - TWO24 * fw)
			z = q[jj - 1] + fw
			ii += 1
		z = _scalbn(z, q0)
		z -= 8.0 * floor(z * 0.125)
		n = int(z)
		z -= float(n)
		ih = 0
		if q0 > 0:
			var i: int = iq[jz - 1] >> (24 - q0)
			n += i
			iq[jz - 1] -= i << (24 - q0)
			ih = iq[jz - 1] >> (23 - q0)
		elif q0 == 0:
			ih = iq[jz - 1] >> 23
		elif z >= 0.5:
			ih = 2
		if ih > 0:
			n += 1
			var carry: int = 0
			for i in range(jz):
				j = iq[i]
				if carry == 0:
					if j != 0:
						carry = 1
						iq[i] = 0x1000000 - j
				else:
					iq[i] = 0xffffff - j
			if q0 == 1:
				iq[jz - 1] &= 0x7fffff
			elif q0 == 2:
				iq[jz - 1] &= 0x3fffff
			if ih == 2:
				z = 1.0 - z
				if carry != 0:
					z -= _scalbn(1.0, q0)
		if z == 0.0:
			j = 0
			for i in range(jz - 1, JK - 1, -1):
				j |= iq[i]
			if j == 0:
				var k: int = 1
				while JK >= k and iq[JK - k] == 0:
					k += 1
				for i in range(jz + 1, jz + k + 1):
					f[jx + i] = float(TWO_OVER_PI[jv + i])
					fw = 0.0
					for jj in range(jx + 1):
						fw += x[jj] * f[jx + i - jj]
					q[i] = fw
				jz += k
				continue
		break
	if z == 0.0:
		jz -= 1
		q0 -= 24
		while iq[jz] == 0:
			jz -= 1
			q0 -= 24
	else:
		z = _scalbn(z, -q0)
		if z >= TWO24:
			fw = float(int(twon24 * z))
			iq[jz] = int(z - TWO24 * fw)
			jz += 1
			q0 += 24
			iq[jz] = int(fw)
		else:
			iq[jz] = int(z)
	fw = _scalbn(1.0, q0)
	for i in range(jz, -1, -1):
		q[i] = fw * iq[i]
		fw *= twon24
	for i in range(jz, -1, -1):
		fw = 0.0
		for k in range(mini(JK, jz - i) + 1):
			fw += PI_O2[k] * q[i + k]
		fq[jz - i] = fw
	fw = 0.0
	for i in range(jz, -1, -1):
		fw += fq[i]
	var y0: float = fw if ih == 0 else -fw
	fw = fq[0] - fw
	for i in range(1, jz + 1):
		fw += fq[i]
	var y1: float = fw if ih == 0 else -fw
	return [n & 7, y0, y1]
