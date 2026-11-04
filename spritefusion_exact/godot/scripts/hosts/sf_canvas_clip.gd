# Restricted port of Skia CPU analytic full-circle A8 clipping.
# Source revision: 29ed1e87a0a50f3d8347e988842d9d59e7573efa.
# Derived from SkGeometry.cpp, SkEdgeClipper.cpp, SkAnalyticEdge.cpp,
# SkEdgeBuilder.cpp and SkScan_AAAPath.cpp. Copyright 2006, 2009, 2016
# The Android Open Source Project; SkEdgeBuilder.cpp Copyright 2011 Google Inc.
# SkPathBuilder.cpp Copyright 2015 Google Inc.
# Skia BSD-3-Clause is reproduced below.
# SpriteFusion's original MIT license remains separate.
#
# This is a testable CPU candidate, NOT a claim about the browser's device.
# Only identity-CTM, positive full circles and a rectangular viewport exist
# in this API. No general path or shader/area/supersampling fallback exists.
# See also res://licenses/SKIA_LICENSE.txt. The two unknown build switches are GLOBAL diagnostic choices. Defaults
# match the unguarded pinned source; they must never be chosen per fixture.
# RLE is represented densely, with the same byte accumulation/flush rules.
# Direct full-height blits bypass the RLE near-zero/near-opaque snap.
#
# Copyright (c) 2011 Google Inc. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#
#   * Redistributions of source code must retain the above copyright
#     notice, this list of conditions and the following disclaimer.
#
#   * Redistributions in binary form must reproduce the above copyright
#     notice, this list of conditions and the following disclaimer in
#     the documentation and/or other materials provided with the
#     distribution.
#
#   * Neither the name of the copyright holder nor the names of its
#     contributors may be used to endorse or promote products derived
#     from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

extends RefCounted

const FIXED_ONE: int = 65536
const MAX_S32: int = 2147483647
const MIN_S32: int = -2147483648
const QUADRANT_WEIGHT: float = 0.707106769084930419921875
const SOURCE_REVISION: String = "29ed1e87a0a50f3d8347e988842d9d59e7573efa"

var rasterize_even_rounding: bool = false
var support_legacy_conic_chop: bool = false
var last_error: String = ""
var last_diagnostics: Dictionary = {}
var _width: int = 0
var _height: int = 0
var _left: int = 0
var _right: int = 0
var _top: int = 0
var _bottom: int = 0
var _current_y: int = -1
var _row: PackedInt32Array
var _output: PackedByteArray
var _edges: Array = []
var _flushes: int = 0
var _direct_pixels: int = 0
var _quad_count: int = 0

static func _f(value: float) -> float:
	return PackedFloat32Array([value])[0]

static func _mul(a: int, b: int) -> int:
	return (a * b) >> 16

static func _ceil(value: int) -> int:
	return (value + 65535) >> 16

static func _ceil_fixed(value: int) -> int:
	return (value + 65535) & ~65535

static func _snap_y(value: int) -> int:
	# The source unsigned intermediate has the same signed result here.
	return (value + 8192) & ~16383

static func _inverse(value: int) -> int:
	# Exact arithmetic reconstruction of the pinned 1025-entry reciprocal
	# table: entry for abs(x) is trunc(2^22 / abs(x)). No sampled asset.
	if value == 0:
		return 0
	return 4194304 / value

static func _quick_div(a: int, b: int) -> int:
	assert(b != 0)
	if absi(b) >= 8 and absi(b) < 1024 and absi(a) < 4096:
		return (a * _inverse(b)) >> 6
	return clampi((a << 16) / b, MIN_S32, MAX_S32)

static func _partial(alpha: int, full_alpha: int) -> int:
	return (alpha * full_alpha) >> 8

static func _fixed_alpha(value: int) -> int:
	return (255 * value + 32768) >> 16

static func _triangle(a: int, b: int) -> int:
	return (((a >> 11) * (a >> 11) * (b >> 11)) >> 8) & 255

static func _trapezoid(a: int, b: int) -> int:
	return ((a + b) / 2) >> 8

func _fdot(value: float) -> int:
	var scaled: float = _f(value * 256.0)
	if not rasterize_even_rounding:
		return int(scaled)
	var below: int = int(floor(scaled))
	var fraction: float = scaled - float(below)
	return below + (1 if fraction > 0.5 or (fraction == 0.5 and (below & 1) != 0) else 0)

static func _point(x: float, y: float) -> Array:
	return [_f(x), _f(y)]

static func _between(a: float, b: float, c: float) -> bool:
	return _f(_f(a - b) * _f(c - b)) <= 0.0

static func _interp(a: Array, b: Array, t: float) -> Array:
	return [_f(float(a[0]) + _f(_f(float(b[0]) - float(a[0])) * t)),
		_f(float(a[1]) + _f(_f(float(b[1]) - float(a[1])) * t))]

static func _chop_quad(points: Array, t: float) -> Array:
	var p01: Array = _interp(points[0], points[1], t)
	var p12: Array = _interp(points[1], points[2], t)
	return [points[0].duplicate(), p01, _interp(p01, p12, t), p12, points[2].duplicate()]

static func _unit_divide(numerator: float, denominator: float) -> float:
	if numerator < 0.0:
		numerator = -numerator
		denominator = -denominator
	if denominator == 0.0 or numerator == 0.0 or numerator >= denominator:
		return -1.0
	var result: float = _f(numerator / denominator)
	return result if result > 0.0 and result < 1.0 else -1.0

static func _quad_roots(a: float, b: float, c: float) -> Array:
	if a == 0.0:
		var root: float = _unit_divide(-c, b)
		return [root] if root > 0.0 else []
	# SkFindUnitQuadRoots intentionally computes the discriminant in double.
	var discriminant: float = b * b - 4.0 * a * c
	if discriminant < 0.0:
		return []
	var r: float = _f(sqrt(discriminant))
	if not is_finite(r):
		return []
	var q: float = _f(-_f(b - r if b < 0.0 else b + r) * 0.5)
	var roots: Array = []
	var r0: float = _unit_divide(q, a)
	var r1: float = _unit_divide(c, q)
	if r0 > 0.0:
		roots.append(r0)
	if r1 > 0.0 and r1 != r0:
		roots.append(r1)
	roots.sort()
	return roots

static func _mono_t(points: Array, axis: int, target: float) -> float:
	var c0: float = points[0][axis]
	var c1: float = points[1][axis]
	var c2: float = points[2][axis]
	var a: float = _f(_f(_f(c0 - c1) - c1) + c2)
	var b: float = _f(2.0 * _f(c1 - c0))
	var roots: Array = _quad_roots(a, b, _f(c0 - target))
	return roots[0] if not roots.is_empty() else -1.0

static func _split_extrema(points: Array, axis: int) -> Array:
	var a: float = points[0][axis]
	var b: float = points[1][axis]
	var c: float = points[2][axis]
	var ab: float = _f(a - b)
	var bc: float = _f(b - c)
	# is_not_monotonic includes a == b, b == c. No strict-sign shortcut.
	if ab < 0.0:
		bc = -bc
	if ab == 0.0 or bc < 0.0:
		var t: float = _unit_divide(ab, _f(_f(ab - b) + c))
		if t > 0.0:
			var chopped: Array = _chop_quad(points, t)
			chopped[1][axis] = chopped[2][axis]
			chopped[3][axis] = chopped[2][axis]
			return [[chopped[0], chopped[1], chopped[2]], [chopped[2], chopped[3], chopped[4]]]
		var copy: Array = points.duplicate(true)
		copy[1][axis] = a if absf(ab) < absf(_f(b - c)) else c
		return [copy]
	return [points]

func _conic_level(points: Array, weight: float) -> int:
	var a: float = _f(weight - 1.0)
	var k: float = _f(a / _f(4.0 * _f(2.0 + a)))
	var x: float = _f(k * _f(_f(float(points[0][0]) - _f(2.0 * float(points[1][0]))) + float(points[2][0])))
	var y: float = _f(k * _f(_f(float(points[0][1]) - _f(2.0 * float(points[1][1]))) + float(points[2][1])))
	var error: float = _f(sqrt(_f(_f(x * x) + _f(y * y))))
	var level: int = 0
	while level < 5 and error > 0.25:
		error = _f(error * 0.25)
		level += 1
	return level

func _subdivide_conic(points: Array, weight: float, level: int, output: Array) -> void:
	if level == 0:
		output.append(points)
		return
	var scale: float = _f(1.0 / _f(1.0 + weight))
	var p1: Array = [0.0, 0.0]
	var p2: Array = [0.0, 0.0]
	var p3: Array = [0.0, 0.0]
	for axis in range(2):
		var v0: float = points[0][axis]
		var v1: float = points[1][axis]
		var v2: float = points[2][axis]
		if support_legacy_conic_chop:
			var wp1: float = _f(weight * v1)
			p1[axis] = _f(_f(v0 + wp1) * scale)
			p3[axis] = _f(_f(wp1 + v2) * scale)
			p2[axis] = _f(_f(_f(_f(v0 + _f(wp1 + wp1)) + v2) * scale) * 0.5)
		else:
			var t0: float = _f(v0 * scale)
			var t1: float = _f(v1 * _f(weight * scale))
			var t2: float = _f(v2 * scale)
			p1[axis] = _f(t0 + t1)
			p3[axis] = _f(t1 + t2)
			p2[axis] = _f(_f(_f(0.5 * t0) + t1) + _f(0.5 * t2))
	var start_y: float = points[0][1]
	var end_y: float = points[2][1]
	if _between(start_y, points[1][1], end_y):
		if not _between(start_y, p2[1], end_y):
			p2[1] = start_y if absf(_f(float(p2[1]) - start_y)) < absf(_f(float(p2[1]) - end_y)) else end_y
		if not _between(start_y, p1[1], p2[1]):
			p1[1] = start_y
		if not _between(p2[1], p3[1], end_y):
			p3[1] = end_y
	var new_weight: float = _f(sqrt(_f(0.5 + _f(weight * 0.5))))
	_subdivide_conic([points[0], p1, p2], new_weight, level - 1, output)
	_subdivide_conic([p2, p3, points[2]], new_weight, level - 1, output)

func _clip_mono_quad(source: Array) -> void:
	var points: Array = source.duplicate(true)
	var reverse: bool = points[0][1] > points[2][1]
	if reverse:
		points.reverse()
	if points[2][1] <= float(_top) or points[0][1] >= float(_bottom):
		return
	if points[0][1] < float(_top):
		var t: float = _mono_t(points, 1, float(_top))
		if t > 0.0:
			var chopped: Array = _chop_quad(points, t)
			chopped[2][1] = float(_top)
			chopped[3][1] = maxf(chopped[3][1], float(_top))
			points = [chopped[2], chopped[3], chopped[4]]
		else:
			for p in points:
				p[1] = maxf(p[1], float(_top))
	if points[2][1] > float(_bottom):
		var t: float = _mono_t(points, 1, float(_bottom))
		if t > 0.0:
			var chopped: Array = _chop_quad(points, t)
			chopped[1][1] = minf(chopped[1][1], float(_bottom))
			chopped[2][1] = float(_bottom)
			points = [chopped[0], chopped[1], chopped[2]]
		else:
			for p in points:
				p[1] = minf(p[1], float(_bottom))
	if points[0][0] > points[2][0]:
		points.reverse()
		reverse = not reverse
	if points[2][0] <= float(_left):
		_add_vertical(float(_left), points[0][1], points[2][1], reverse)
		return
	if points[0][0] >= float(_right):
		_add_vertical(float(_right), points[0][1], points[2][1], reverse)
		return
	if points[0][0] < float(_left):
		var t: float = _mono_t(points, 0, float(_left))
		if t <= 0.0:
			_add_vertical(float(_left), points[0][1], points[2][1], reverse)
			return
		var chopped: Array = _chop_quad(points, t)
		_add_vertical(float(_left), chopped[0][1], chopped[2][1], reverse)
		chopped[2][0] = float(_left)
		chopped[3][0] = maxf(chopped[3][0], float(_left))
		points = [chopped[2], chopped[3], chopped[4]]
	if points[2][0] > float(_right):
		var t: float = _mono_t(points, 0, float(_right))
		if t > 0.0:
			var chopped: Array = _chop_quad(points, t)
			chopped[1][0] = minf(chopped[1][0], float(_right))
			chopped[2][0] = float(_right)
			_add_quad([chopped[2], chopped[1], chopped[0]] if reverse else [chopped[0], chopped[1], chopped[2]])
			_add_vertical(float(_right), chopped[2][1], chopped[4][1], reverse)
			return
		points[1][0] = minf(points[1][0], float(_right))
		points[2][0] = minf(points[2][0], float(_right))
	if reverse:
		points.reverse()
	_add_quad(points)

func _add_vertical(x: float, y0: float, y1: float, reverse: bool) -> void:
	if reverse:
		_add_line(_point(x, y1), _point(x, y0))
	else:
		_add_line(_point(x, y0), _point(x, y1))

func _add_line(p0: Array, p1: Array) -> void:
	var x0: int = _fdot(p0[0]) << 8
	var y0: int = _snap_y(_fdot(p0[1]) << 8)
	var x1: int = _fdot(p1[0]) << 8
	var y1: int = _snap_y(_fdot(p1[1]) << 8)
	var winding: int = 1
	if y0 > y1:
		var temp: int = x0
		x0 = x1
		x1 = temp
		temp = y0
		y0 = y1
		y1 = temp
		winding = -1
	var dy: int = (y1 - y0) >> 10
	if dy == 0:
		return
	var dx: int = (x1 - x0) >> 10
	var slope: int = _quick_div(dx, dy)
	var inv: int = MAX_S32 if dx == 0 or slope == 0 else (_inverse(absi(slope)) if absi(slope) < 1024 else absi(_quick_div(dy, dx)))
	var edge: Dictionary = {"x": x0, "dx": slope, "ux": x0, "y": y0, "uy": y0, "ly": y1,
		"dy": inv, "type": 0, "count": 0, "winding": winding, "shift": 0}
	if slope == 0 and not _edges.is_empty():
		var combined: int = _combine_vertical(edge, _edges[-1])
		if combined == 2:
			_edges.pop_back()
		if combined != 0:
			return
	_edges.append(edge)

static func _combine_vertical(edge: Dictionary, last: Dictionary) -> int:
	if last.type != 0 or last.dx != 0 or edge.x != last.x:
		return 0
	if edge.winding == last.winding:
		if edge.ly == last.uy:
			last.uy = edge.uy
			last.y = last.uy
			return 1
		if absi(edge.uy - last.ly) < 256:
			last.ly = edge.ly
			return 1
		return 0
	if absi(edge.uy - last.uy) < 256:
		if absi(edge.ly - last.ly) < 256:
			return 2
		if edge.ly < last.ly:
			last.uy = edge.ly
			last.y = last.uy
			return 1
		last.uy = last.ly
		last.y = last.uy
		last.ly = edge.ly
		last.winding = edge.winding
		return 1
	if absi(edge.ly - last.ly) < 256:
		if edge.uy > last.uy:
			last.ly = edge.uy
			return 1
		last.ly = last.uy
		last.uy = edge.uy
		last.y = last.uy
		last.winding = edge.winding
		return 1
	return 0

func _add_quad(points: Array) -> void:
	var x0: int = _fdot(points[0][0])
	var y0: int = _fdot(points[0][1])
	var x1: int = _fdot(points[1][0])
	var y1: int = _fdot(points[1][1])
	var x2: int = _fdot(points[2][0])
	var y2: int = _fdot(points[2][1])
	var winding: int = 1
	if y0 > y2:
		var temp: int = x0
		x0 = x2
		x2 = temp
		temp = y0
		y0 = y2
		y2 = temp
		winding = -1
	assert(y0 <= y1 and y1 <= y2)
	if ((y0 + 32) >> 6) == ((y2 + 32) >> 6):
		return
	var ddx: int = absi(((x1 << 1) - x0 - x2) >> 2)
	var ddy: int = absi(((y1 << 1) - y0 - y2) >> 2)
	var dist: int = maxi(ddx, ddy) + (mini(ddx, ddy) >> 1)
	dist = (dist + 16) >> 5
	var bits: int = 0
	while dist > 0:
		bits += 1
		dist >>= 1
	var shift: int = clampi(bits >> 1, 1, 6)
	var ax: int = (x0 - x1 - x1 + x2) << 9
	var bx: int = (x1 - x0) << 10
	var ay: int = (y0 - y1 - y1 + y2) << 9
	var by: int = (y1 - y0) << 10
	var edge: Dictionary = {
		"qx": x0 << 8, "qy": _snap_y(y0 << 8),
		"qdx": (bx + (ax >> shift)) >> 2, "qdy": (by + (ay >> shift)) >> 2,
		"qddx": (ax >> (shift - 1)) >> 2, "qddy": (ay >> (shift - 1)) >> 2,
		"lastx": x2 << 8, "lasty": _snap_y(y2 << 8),
		"sx": x0 << 8, "sy": _snap_y(y0 << 8),
		"winding": winding, "type": 1, "count": 1 << shift, "shift": shift - 1,
	}
	if _update_quad(edge):
		_edges.append(edge)

static func _update_quad(edge: Dictionary) -> bool:
	var count: int = edge.count
	var oldx: int = edge.qx
	var oldy: int = edge.qy
	var dx: int = edge.qdx
	var dy: int = edge.qdy
	var shift: int = edge.shift
	var success: bool = false
	var newx: int = 0
	var newy: int = 0
	var snapped_x: int = 0
	var snapped_y: int = 0
	while true:
		count -= 1
		var slope: int
		if count > 0:
			newx = oldx + (dx >> shift)
			newy = oldy + (dy >> shift)
			if absi(dy >> shift) >= 131072 and (absi(dy) << 6) > absi(dx):
				var diff_y: int = (newy - int(edge.sy)) >> 10
				slope = _quick_div((newx - int(edge.sx)) >> 10, diff_y) if diff_y != 0 else MAX_S32
				snapped_y = mini(edge.lasty, (newy + 32768) & ~65535)
				snapped_x = newx - _mul(slope, newy - snapped_y)
			else:
				snapped_y = mini(edge.lasty, _snap_y(newy))
				snapped_x = newx
				var diff_y: int = (snapped_y - int(edge.sy)) >> 10
				slope = _quick_div((newx - int(edge.sx)) >> 10, diff_y) if diff_y != 0 else MAX_S32
			dx += int(edge.qddx)
			dy += int(edge.qddy)
		else:
			newx = edge.lastx
			newy = edge.lasty
			snapped_x = newx
			snapped_y = newy
			var diff_y: int = (newy - int(edge.sy)) >> 10
			slope = _quick_div((newx - int(edge.sx)) >> 10, diff_y) if diff_y != 0 else MAX_S32
		if slope < MAX_S32:
			success = _update_line(edge, edge.sx, edge.sy, snapped_x, snapped_y, slope)
		oldx = newx
		oldy = newy
		if count == 0 or success:
			break
	edge.qx = newx
	edge.qy = newy
	edge.qdx = dx
	edge.qdy = dy
	edge.sx = snapped_x
	edge.sy = snapped_y
	edge.count = count
	return success

static func _update_line(edge: Dictionary, x0: int, y0: int, x1: int, y1: int, slope: int) -> bool:
	if y0 > y1:
		var temp: int = x0
		x0 = x1
		x1 = temp
		temp = y0
		y0 = y1
		y1 = temp
		edge.winding = -int(edge.winding)
	var dx: int = (x1 - x0) >> 10
	var dy: int = (y1 - y0) >> 10
	if dy == 0:
		return false
	var abs_slope: int = absi(slope >> 10)
	edge.x = x0
	edge.dx = slope
	edge.ux = x0
	edge.y = y0
	edge.uy = y0
	edge.ly = y1
	edge.dy = MAX_S32 if dx == 0 or slope == 0 else (_inverse(abs_slope) if abs_slope < 1024 else absi(_quick_div(dy, dx)))
	return true

static func _go_y(edge: Dictionary, y: int) -> void:
	if y == int(edge.y) + FIXED_ONE:
		edge.x = int(edge.x) + int(edge.dx)
		edge.y = y
	elif y != int(edge.y):
		edge.x = int(edge.ux) + _mul(edge.dx, y - int(edge.uy))
		edge.y = y

func _flush() -> void:
	if _current_y < 0:
		return
	var any_alpha: bool = false
	for x in range(_left, _right):
		var alpha: int = _row[x]
		_row[x] = 255 if alpha > 247 else (0 if alpha < 8 else alpha)
		any_alpha = any_alpha or _row[x] != 0
	if any_alpha and _current_y < _height:
		for x in range(_left, _right):
			_output[_current_y * _width + x] = _row[x]
		_flushes += 1
	_row.fill(0)
	_current_y = -1

func _flush_changed(y: int, next_y: int) -> void:
	if (y >> 16) != (next_y >> 16):
		_flush()

func _add(x: int, y: int, alpha: int) -> void:
	if _current_y != y:
		_flush()
		_current_y = y
	if x >= _left and x < _right and y >= 0 and y < _height:
		var total: int = _row[x] + alpha
		assert(total <= 256 and total >= 0, "Convex alpha accumulation out of range")
		_row[x] = total - (total >> 8)

func _add_span(x: int, y: int, count: int, alpha: int) -> void:
	# RunBasedAdditiveBlitter's uniform span overload rejects out-of-bound
	# spans rather than trimming. Its per-alpha array overload trims.
	if _current_y != y:
		_flush()
		_current_y = y
	if x < _left or x + count > _right:
		return
	for i in range(count):
		_add(x + i, y, alpha)

func _direct(x: int, y: int, alpha: int) -> void:
	if x >= _left and x < _right and y >= 0 and y < _height:
		assert(alpha >= 0 and alpha <= 255)
		_output[y * _width + x] = alpha
		_direct_pixels += 1

func _single(x: int, y: int, alpha: int, full_alpha: int) -> void:
	if full_alpha == 255:
		_direct(x, y, alpha)
	else:
		_add(x, y, _partial(alpha, full_alpha))

func _two(x: int, y: int, a1: int, a2: int, full_alpha: int) -> void:
	if full_alpha == 255:
		_direct(x, y, a1)
		_direct(x + 1, y, a2)
	else:
		_add(x, y, a1)
		_add(x + 1, y, a2)

func _full(x: int, y: int, count: int, full_alpha: int) -> void:
	if full_alpha == 255:
		for i in range(count):
			_direct(x + i, y, 255)
	else:
		_add_span(x, y, count, full_alpha)

static func _above_line(l: int, r: int, dy: int, full_alpha: int) -> PackedInt32Array:
	var right: int = _ceil(r)
	var alphas: PackedInt32Array = []
	alphas.resize(right)
	if right == 0:
		return alphas
	if right == 1:
		alphas[0] = _partial(((right << 17) - l - r) >> 9, full_alpha)
	else:
		var first: int = FIXED_ONE - l
		var last: int = r - ((right - 1) << 16)
		var first_h: int = _mul(first, dy)
		alphas[0] = _mul(first, first_h) >> 9
		var alpha16: int = mini(MAX_S32, first_h + (dy >> 1))
		for i in range(1, right - 1):
			alphas[i] = (alpha16 >> 8) & 255
			alpha16 = mini(MAX_S32, alpha16 + dy)
		alphas[right - 1] = (full_alpha - _triangle(last, dy)) & 255
	return alphas

static func _below_line(l: int, r: int, dy: int, full_alpha: int) -> PackedInt32Array:
	var right: int = _ceil(r)
	var alphas: PackedInt32Array = []
	alphas.resize(right)
	if right == 0:
		return alphas
	if right == 1:
		alphas[0] = _partial(_trapezoid(l, r), full_alpha)
	else:
		var first: int = FIXED_ONE - l
		var last: int = r - ((right - 1) << 16)
		var last_h: int = _mul(last, dy)
		alphas[right - 1] = _mul(last, last_h) >> 9
		var alpha16: int = mini(MAX_S32, last_h + (dy >> 1))
		for i in range(right - 2, 0, -1):
			alphas[i] = (alpha16 >> 8) & 255
			alpha16 = mini(MAX_S32, alpha16 + dy)
		alphas[0] = (full_alpha - _triangle(first, dy)) & 255
	return alphas

func _aaa_trapezoid(y: int, ul: int, ur: int, ll: int, lr: int, ldy: int, rdy: int, full_alpha: int) -> void:
	var left: int = ul >> 16
	var right: int = _ceil(lr)
	var count: int = right - left
	if count <= 0:
		return
	if count == 1:
		_single(left, y, _trapezoid(ur - ul, lr - ll), full_alpha)
		return
	var alphas: PackedInt32Array = []
	alphas.resize(count)
	alphas.fill(full_alpha)
	var upper_left: int = ul >> 16
	var lower_left: int = _ceil(ll)
	if upper_left + 2 == lower_left:
		var first: int = (upper_left << 16) + FIXED_ONE - ul
		var second: int = ll - ul - first
		var a1: int = (full_alpha - _triangle(first, ldy)) & 255
		var a2: int = _triangle(second, ldy)
		alphas[0] = maxi(0, alphas[0] - a1)
		alphas[1] = maxi(0, alphas[1] - a2)
	else:
		var temporary: PackedInt32Array = _below_line(ul - (upper_left << 16), ll - (upper_left << 16), ldy, full_alpha)
		for i in range(upper_left, lower_left):
			alphas[i - left] = maxi(0, alphas[i - left] - temporary[i - upper_left])
	var upper_right: int = ur >> 16
	var lower_right: int = _ceil(lr)
	if upper_right + 2 == lower_right:
		var first: int = (upper_right << 16) + FIXED_ONE - ur
		var second: int = lr - ur - first
		var a1: int = _triangle(first, rdy)
		var a2: int = (full_alpha - _triangle(second, rdy)) & 255
		alphas[count - 2] = maxi(0, alphas[count - 2] - a1)
		alphas[count - 1] = maxi(0, alphas[count - 1] - a2)
	else:
		var temporary: PackedInt32Array = _above_line(ur - (upper_right << 16), lr - (upper_right << 16), rdy, full_alpha)
		for i in range(upper_right, lower_right):
			alphas[i - left] = maxi(0, alphas[i - left] - temporary[i - upper_right])
	for i in range(count):
		if full_alpha == 255:
			_direct(left + i, y, alphas[i])
		else:
			_add(left + i, y, alphas[i])

func _blit_trapezoid(y: int, ul: int, ur: int, ll: int, lr: int, ldy: int, rdy: int, full_alpha: int) -> void:
	if ul > ur:
		return
	if ll > lr:
		var intersect: int = (maxi(mini(ul, ll), mini(ur, lr)) + mini(maxi(ul, ll), maxi(ur, lr))) / 2
		ll = intersect
		lr = intersect
	if ul == ur and ll == lr:
		return
	if ul > ll:
		var swap: int = ul
		ul = ll
		ll = swap
	if ur > lr:
		var swap: int = ur
		ur = lr
		lr = swap
	var join_left: int = _ceil_fixed(ll)
	var join_right: int = ur & ~65535
	if join_left > join_right:
		_aaa_trapezoid(y, ul, ur, ll, lr, ldy, rdy, full_alpha)
		return
	if ul < join_left:
		var count: int = _ceil(join_left - ul)
		if count == 1:
			_single(ul >> 16, y, _trapezoid(join_left - ul, join_left - ll), full_alpha)
		elif count == 2:
			var first: int = join_left - FIXED_ONE - ul
			var second: int = ll - ul - first
			_two(ul >> 16, y, _triangle(first, ldy), (full_alpha - _triangle(second, ldy)) & 255, full_alpha)
		else:
			_aaa_trapezoid(y, ul, join_left, ll, join_left, ldy, MAX_S32, full_alpha)
	if join_left < join_right:
		_full(join_left >> 16, y, (join_right - join_left) >> 16, full_alpha)
	if lr > join_right:
		var count: int = _ceil(lr - join_right)
		if count == 1:
			_single(join_right >> 16, y, _trapezoid(ur - join_right, lr - join_right), full_alpha)
		elif count == 2:
			var first: int = join_right + FIXED_ONE - ur
			var second: int = lr - ur - first
			_two(join_right >> 16, y, (full_alpha - _triangle(first, rdy)) & 255, _triangle(second, rdy), full_alpha)
		else:
			_aaa_trapezoid(y, join_right, ur, join_right, lr, MAX_S32, rdy, full_alpha)

static func _smooth_edge(edge: Dictionary, next: Dictionary) -> bool:
	if int(edge.count) > 0:
		return (absi(edge.qdx) >> 1) >= absi(edge.qddx) and (absi(edge.qdy) >> 1) >= absi(edge.qddy) and ((int(edge.qdy) - int(edge.qddy)) >> int(edge.shift)) >= FIXED_ONE
	return absi(clampi(int(next.dx) - int(edge.dx), MIN_S32, MAX_S32)) <= FIXED_ONE and int(next.ly) - int(next.uy) >= FIXED_ONE

func _smooth(left: Dictionary, right: Dictionary, current: int, stop_y: int) -> bool:
	var next: Dictionary = _edges[current]
	if int(next.uy) >= (stop_y << 16):
		return false
	if int(left.ly) + FIXED_ONE < int(right.ly):
		return _smooth_edge(left, next)
	if int(left.ly) > int(right.ly) + FIXED_ONE:
		return _smooth_edge(right, next)
	var next_next: Dictionary = _edges[current + 1]
	if int(next_next.uy) >= (stop_y << 16):
		return false
	if int(next_next.ux) < int(next.ux):
		var swap: Dictionary = next
		next = next_next
		next_next = swap
	return _smooth_edge(left, next) and _smooth_edge(right, next_next)

func _blit_vertical_rectangle(left: int, right: int, y: int, bottom: int) -> void:
	var full_left: int = _ceil(left)
	var full_right: int = right >> 16
	var partial_left: int = (full_left << 16) - left
	var partial_right: int = right - (full_right << 16)
	var full_top: int = _ceil(y)
	var full_bottom: int = bottom >> 16
	var partial_top: int = (full_top << 16) - y
	var partial_bottom: int = bottom - (full_bottom << 16)
	if full_top > full_bottom:
		partial_top -= FIXED_ONE - partial_bottom
		partial_bottom = 0
	if full_right >= full_left:
		if partial_top > 0:
			if partial_left > 0:
				_add(full_left - 1, full_top - 1, _fixed_alpha(_mul(partial_top, partial_left)))
			_add_span(full_left, full_top - 1, full_right - full_left, _fixed_alpha(partial_top))
			if partial_right > 0:
				_add(full_right, full_top - 1, _fixed_alpha(_mul(partial_top, partial_right)))
			_flush_changed(y, y + partial_top)
		if full_bottom > full_top:
			for row in range(full_top, full_bottom):
				_direct(full_left - 1, row, _fixed_alpha(partial_left))
				for x in range(full_left, full_right):
					_direct(x, row, 255)
				_direct(full_right, row, _fixed_alpha(partial_right))
		if partial_bottom > 0:
			if partial_left > 0:
				_add(full_left - 1, full_bottom, _fixed_alpha(_mul(partial_bottom, partial_left)))
			_add_span(full_left, full_bottom, full_right - full_left, _fixed_alpha(partial_bottom))
			if partial_right > 0:
				_add(full_right, full_bottom, _fixed_alpha(_mul(partial_bottom, partial_right)))
	else:
		var span: int = right - left
		if span <= 0:
			return
		if partial_top > 0:
			_add_span(full_left - 1, full_top - 1, 1, _fixed_alpha(_mul(partial_top, span)))
			_flush_changed(y, y + partial_top)
		for row in range(full_top, full_bottom):
			_direct(full_left - 1, row, _fixed_alpha(span))
		if partial_bottom > 0:
			_add_span(full_left - 1, full_bottom, 1, _fixed_alpha(_mul(partial_bottom, span)))

func _walk_convex(stop_y: int) -> void:
	_edges.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.uy != b.uy:
			return a.uy < b.uy
		if a.x != b.x:
			return a.x < b.x
		return a.dx < b.dx)
	var sentinel: Dictionary = {"uy": MAX_S32, "ly": MAX_S32, "ux": MAX_S32,
		"x": MAX_S32, "dx": 0, "dy": MAX_S32, "count": 0}
	_edges.append(sentinel)
	var left_edge: Dictionary = _edges[0]
	var right_edge: Dictionary = _edges[1]
	var current: int = 2
	var y: int = maxi(left_edge.uy, right_edge.uy)
	var left_bound: int = _left << 16
	var right_bound: int = _right << 16
	var guard: int = 0
	while true:
		guard += 1
		assert(guard < 100000, "Unsupported nonprogressing convex edge set")
		while int(left_edge.ly) <= y:
			if int(left_edge.count) <= 0 or not _update_quad(left_edge):
				if (int(_edges[current].uy) >> 16) >= stop_y:
					return
				left_edge = _edges[current]
				current += 1
		while int(right_edge.ly) <= y:
			if int(right_edge.count) <= 0 or not _update_quad(right_edge):
				if (int(_edges[current].uy) >> 16) >= stop_y:
					return
				right_edge = _edges[current]
				current += 1
		if (y >> 16) >= stop_y:
			return
		_go_y(left_edge, y)
		_go_y(right_edge, y)
		if int(left_edge.x) > int(right_edge.x) or (left_edge.x == right_edge.x and left_edge.dx > right_edge.dx):
			var swap: Dictionary = left_edge
			left_edge = right_edge
			right_edge = swap
		var bottom: int = mini(left_edge.ly, right_edge.ly)
		if _smooth(left_edge, right_edge, current, stop_y):
			bottom = _ceil_fixed(bottom)
		bottom = mini(bottom, stop_y << 16)
		var left: int = maxi(left_bound, left_edge.x)
		var right: int = mini(right_bound, right_edge.x)
		var dleft: int = left_edge.dx
		var dright: int = right_edge.dx
		if (dleft | dright) == 0:
			_blit_vertical_rectangle(left, right, y, bottom)
			y = bottom
		else:
			left += 2048
			right += 2048
			var count: int = _ceil(bottom) - (y >> 16)
			if count > 1:
				if (y & ~65535) != y:
					count -= 1
					var next_y: int = _ceil_fixed(y + 1)
					var dy: int = next_y - y
					var next_left: int = left + _mul(dleft, dy)
					var next_right: int = right + _mul(dright, dy)
					_blit_trapezoid(y >> 16, left & ~4095, right & ~4095, next_left & ~4095, next_right & ~4095, left_edge.dy, right_edge.dy, _fixed_alpha(dy))
					_flush_changed(y, next_y)
					left = next_left
					right = next_right
					y = next_y
				while count > 1:
					count -= 1
					var next_y: int = y + FIXED_ONE
					var next_left: int = left + dleft
					var next_right: int = right + dright
					_blit_trapezoid(y >> 16, left & ~4095, right & ~4095, next_left & ~4095, next_right & ~4095, left_edge.dy, right_edge.dy, 255)
					_flush_changed(y, next_y)
					left = next_left
					right = next_right
					y = next_y
			var dy: int = bottom - y
			var next_left: int = maxi(left + _mul(dleft, dy), left_bound + 2048)
			var next_right: int = mini(right + _mul(dright, dy), right_bound + 2048)
			_blit_trapezoid(y >> 16, left & ~4095, right & ~4095, next_left & ~4095, next_right & ~4095, left_edge.dy, right_edge.dy, _fixed_alpha(dy))
			_flush_changed(y, bottom)
			left = next_left - 2048
			right = next_right - 2048
			y = bottom
		left_edge.x = left
		right_edge.x = right
		left_edge.y = y
		right_edge.y = y

func _reject(message: String) -> PackedByteArray:
	last_error = message
	last_diagnostics = {"accepted_input": false, "error": message}
	push_error("SfCanvasClip: " + message)
	return PackedByteArray()

func build_circle(width: int, height: int, cx: float, cy: float, radius: float) -> PackedByteArray:
	last_error = ""
	last_diagnostics = {}
	if width <= 0 or height <= 0 or width > 4096 or height > 4096:
		return _reject("Only positive viewports at most 4096 by 4096 are supported")
	if not is_finite(cx) or not is_finite(cy) or not is_finite(radius) or radius < 0.0:
		return _reject("Circle parameters must be finite and radius must be nonnegative")
	cx = _f(cx)
	cy = _f(cy)
	radius = _f(radius)
	# This documented guard avoids all unported large-coordinate fallback and
	# signed fixed-point coefficient overflow branches, rather than approximating.
	if absf(cx) + radius > 4096.0 or absf(cy) + radius > 4096.0:
		return _reject("Circle bounds outside [-4096,4096] require an unsupported large-coordinate path")
	_width = width
	_height = height
	_output = PackedByteArray()
	_output.resize(width * height)
	_output.fill(0)
	_row = PackedInt32Array()
	_row.resize(width)
	_row.fill(0)
	_current_y = -1
	_edges = []
	_flushes = 0
	_direct_pixels = 0
	_quad_count = 0
	# Blink AddEllipse: independent float32 LTRB arithmetic. SkPathBuilder's
	# two 180-degree arcTo calls build two unit quadrant conics apiece.
	var oval_left: float = _f(cx - radius)
	var oval_right: float = _f(cx + radius)
	var oval_top: float = _f(cy - radius)
	var oval_bottom: float = _f(cy + radius)
	var scale_x: float = _f(_f(oval_right - oval_left) * 0.5)
	var scale_y: float = _f(_f(oval_bottom - oval_top) * 0.5)
	var center_x: float = _f((oval_left + oval_right) * 0.5)
	var center_y: float = _f((oval_top + oval_bottom) * 0.5)
	var unit_points: Array = [[1.0, 0.0], [1.0, 1.0], [0.0, 1.0], [-1.0, 1.0],
		[-1.0, 0.0], [-1.0, -1.0], [0.0, -1.0], [1.0, -1.0], [1.0, 0.0]]
	var points: Array = []
	for unit in unit_points:
		points.append(_point(_f(_f(float(unit[0]) * scale_x) + center_x), _f(_f(float(unit[1]) * scale_y) + center_y)))
	# Path bounds come from the generated points, not the original ideal oval.
	var bound_left: float = points[0][0]
	var bound_right: float = points[0][0]
	var bound_top: float = points[0][1]
	var bound_bottom: float = points[0][1]
	for p in points:
		bound_left = minf(bound_left, p[0])
		bound_right = maxf(bound_right, p[0])
		bound_top = minf(bound_top, p[1])
		bound_bottom = maxf(bound_bottom, p[1])
	_left = maxi(0, int(floor(bound_left)))
	_right = mini(width, int(ceil(bound_right)))
	_top = maxi(0, int(floor(bound_top)))
	_bottom = mini(height, int(ceil(bound_bottom)))
	var contained: bool = bound_left >= 0.0 and bound_top >= 0.0 and bound_right <= float(width) and bound_bottom <= float(height)
	if radius > 0.0 and _left < _right and _top < _bottom:
		for quadrant in range(4):
			var conic: Array = points.slice(quadrant * 2, quadrant * 2 + 3)
			var quads: Array = []
			_subdivide_conic(conic, QUADRANT_WEIGHT, _conic_level(conic, QUADRANT_WEIGHT), quads)
			_quad_count += quads.size()
			for quad in quads:
				for mono_y in _split_extrema(quad, 1):
					if contained:
						_add_quad(mono_y)
					else:
						for mono_x in _split_extrema(mono_y, 0):
							_clip_mono_quad(mono_x)
		if _edges.size() >= 2:
			_walk_convex(_bottom)
			_flush()
	last_diagnostics = {"accepted_input": true, "source_revision": SOURCE_REVISION,
		"cpu_dispatch_verified": false, "whole_lens_accepted": false,
		"rasterize_even_rounding": rasterize_even_rounding,
		"support_legacy_conic_chop": support_legacy_conic_chop,
		"conic_quadratics": _quad_count, "initial_edges": maxi(0, _edges.size() - (1 if _edges.size() >= 3 and _edges[-1].uy == MAX_S32 else 0)),
		"rle_flushes": _flushes, "direct_pixel_writes": _direct_pixels,
		"viewport_clipped": not contained, "lowered_geometry": [cx, cy, radius],
		"oval_ltrb": [oval_left, oval_top, oval_right, oval_bottom],
		"matrix_scale_center": [scale_x, scale_y, center_x, center_y]}
	return _output
