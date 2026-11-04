# Restricted source port of rotated Canvas drawImage destination coverage.
# Source revision: 29ed1e87a0a50f3d8347e988842d9d59e7573efa.
# Derived from SkLineClipper.cpp (Copyright 2011 Google Inc.) and
# SkScan_AAAPath.cpp (Copyright 2016 The Android Open Source Project).
# Inherits the frozen analytic line/convex walker; never changes circle code.
# Runtime inputs are geometry and optional runtime clip bounds, never oracles.
# Supports finite, positive source/destination rectangles wholly inside the
# source image, non-axis-preserving affine transforms, and bounded coordinates.
# Source clipping and axis-preserving/non-AA image draws are explicitly outside
# this narrow API. The caller must validate source crop against source size.
# A BW clip permits the <=32-pixel/1024-byte mask path; AA clip forces RLE.
# Small-mask accumulation and RLE/direct span dispatch remain separate.
# See res://licenses/SKIA_LICENSE.txt. SpriteFusion's MIT license is separate.
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

extends "res://scripts/hosts/sf_canvas_clip.gd"

var _using_mask: bool = false
var _rle_left: int = 0
var _rle_right: int = 0
var _clip_ltrb: Array = []
var last_forced_edge: PackedByteArray

# SkLineClipper uses double intersections, then casts to float, with a float
# near-zero test. A float midpoint is computed through double precision.
static func _horizontal_intersection(p: Array, target: float) -> float:
	if absf(_f(float(p[1][1]) - float(p[0][1]))) <= 1.0 / 4096.0:
		return _f((float(p[0][0]) + float(p[1][0])) * 0.5)
	var result: float = float(p[0][0]) + (target - float(p[0][1])) * (float(p[1][0]) - float(p[0][0])) / (float(p[1][1]) - float(p[0][1]))
	return _f(clampf(result, minf(p[0][0], p[1][0]), maxf(p[0][0], p[1][0])))

static func _vertical_intersection(p: Array, target: float) -> float:
	var result: float
	if absf(_f(float(p[1][0]) - float(p[0][0]))) <= 1.0 / 4096.0:
		result = _f((float(p[0][1]) + float(p[1][1])) * 0.5)
	else:
		result = _f(float(p[0][1]) + (target - float(p[0][0])) * (float(p[1][1]) - float(p[0][1])) / (float(p[1][0]) - float(p[0][0])))
	return clampf(result, minf(p[0][1], p[1][1]), maxf(p[0][1], p[1][1]))

func _clip_line(p0: Array, p1: Array) -> void:
	# SkLineClipper::ClipLine with canCullToTheRight=false for convex paths.
	var pts: Array = [p0, p1]
	var low: int = 0 if p0[1] < p1[1] else 1
	var high: int = 1 - low
	if pts[high][1] <= _clip_ltrb[1] or pts[low][1] >= _clip_ltrb[3]:
		return
	var tmp: Array = pts.duplicate(true)
	if pts[low][1] < _clip_ltrb[1]:
		tmp[low] = [_horizontal_intersection(pts, _clip_ltrb[1]), _clip_ltrb[1]]
	if tmp[high][1] > _clip_ltrb[3]:
		tmp[high] = [_horizontal_intersection(pts, _clip_ltrb[3]), _clip_ltrb[3]]
	low = 0 if p0[0] < p1[0] else 1
	high = 1 - low
	var reverse: bool = low == 1
	var points: Array = []
	if tmp[high][0] <= _clip_ltrb[0]:
		tmp[0][0] = _clip_ltrb[0]
		tmp[1][0] = _clip_ltrb[0]
		points = tmp
		reverse = false
	elif tmp[low][0] >= _clip_ltrb[2]:
		tmp[0][0] = _clip_ltrb[2]
		tmp[1][0] = _clip_ltrb[2]
		points = tmp
		reverse = false
	else:
		if tmp[low][0] < _clip_ltrb[0]:
			points.append([_clip_ltrb[0], tmp[low][1]])
			points.append([_clip_ltrb[0], _vertical_intersection(tmp, _clip_ltrb[0])])
		else:
			points.append(tmp[low])
		if tmp[high][0] > _clip_ltrb[2]:
			points.append([_clip_ltrb[2], _vertical_intersection(tmp, _clip_ltrb[2])])
			points.append([_clip_ltrb[2], tmp[high][1]])
		else:
			points.append(tmp[high])
	if reverse:
		points.reverse()
	for index in range(points.size() - 1):
		_add_line(points[index], points[index + 1])

func _flush() -> void:
	if not _using_mask:
		super._flush()

func _add(x: int, y: int, alpha: int) -> void:
	if _using_mask:
		if x >= _left and x < _right and y >= _top and y < _bottom:
			var index: int = y * _width + x
			_output[index] = mini(255, int(_output[index]) + alpha)
	elif x >= _rle_left and x < _rle_right:
		super._add(x, y, alpha)

func _add_span(x: int, y: int, count: int, alpha: int) -> void:
	if _using_mask:
		for index in range(count):
			_add(x + index, y, alpha)
	elif x >= _rle_left and x + count <= _rle_right:
		super._add_span(x, y, count, alpha)

func _two(x: int, y: int, a1: int, a2: int, full_alpha: int) -> void:
	if _using_mask:
		_add(x, y, a1)
		_add(x + 1, y, a2)
	else:
		super._two(x, y, a1, a2, full_alpha)

func _full(x: int, y: int, count: int, full_alpha: int) -> void:
	if _using_mask:
		_add_span(x, y, count, full_alpha)
	else:
		super._full(x, y, count, full_alpha)

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
		if full_alpha == 255 and not _using_mask:
			_direct(left + i, y, alphas[i])
		else:
			_add(left + i, y, alphas[i])

static func mul_div255_round(a: int, b: int) -> int:
	var product: int = a * b + 128
	return (product + (product >> 8)) >> 8

static func multiply_coverage(a: PackedByteArray, b: PackedByteArray) -> PackedByteArray:
	assert(a.size() == b.size())
	var output := PackedByteArray()
	output.resize(a.size())
	for index in range(a.size()):
		output[index] = mul_div255_round(a[index], b[index])
	return output

static func coverage_bounds(coverage: PackedByteArray, width: int, height: int) -> Rect2i:
	# SkAAClip::trimBounds removes all-zero rows and all-zero outer columns.
	assert(width > 0 and height > 0 and coverage.size() == width * height)
	var l: int = width
	var r: int = 0
	var t: int = height
	var b: int = 0
	for index in range(coverage.size()):
		if coverage[index] != 0:
			var x: int = index % width
			var y: int = index / width
			l = mini(l, x)
			r = maxi(r, x + 1)
			t = mini(t, y)
			b = maxi(b, y + 1)
	return Rect2i(l, t, r - l, b - t) if l < r and t < b else Rect2i()

func build_combined(width: int, height: int, canvas_transform: Array, draw_image_args: Array, circle_coverage: PackedByteArray) -> PackedByteArray:
	assert(circle_coverage.size() == width * height)
	var bounds: Rect2i = coverage_bounds(circle_coverage, width, height)
	if not bounds.has_area():
		last_forced_edge = PackedByteArray()
		last_forced_edge.resize(width * height)
		last_forced_edge.fill(0)
		return last_forced_edge.duplicate()
	last_forced_edge = build_image_edge(width, height, canvas_transform, draw_image_args, true, bounds)
	if last_forced_edge.size() != circle_coverage.size():
		return PackedByteArray()
	return multiply_coverage(circle_coverage, last_forced_edge)

func build_image_edge(width: int, height: int, canvas_transform: Array, draw_image_args: Array, force_rle: bool = false, clip_bounds: Rect2i = Rect2i()) -> PackedByteArray:
	last_error = ""
	last_diagnostics = {}
	if width <= 0 or height <= 0 or width > 4096 or height > 4096:
		return _reject("Only viewports in [1,4096] are supported")
	if canvas_transform.size() != 6 or draw_image_args.size() != 8:
		return _reject("Expected Canvas affine [a,b,c,d,e,f] and eight drawImage arguments")
	var matrix: Array = []
	var args: Array = []
	for value in canvas_transform:
		if not is_finite(float(value)):
			return _reject("Nonfinite Canvas transform")
		matrix.append(_f(float(value)))
	for value in draw_image_args:
		if not is_finite(float(value)):
			return _reject("Nonfinite drawImage argument")
		args.append(_f(float(value)))
	if args[2] <= 0.0 or args[3] <= 0.0 or args[6] <= 0.0 or args[7] <= 0.0 or args[0] < 0.0 or args[1] < 0.0:
		return _reject("Only positive, already source-bounded crop rectangles are supported")
	if (matrix[1] == 0.0 and matrix[2] == 0.0) or (matrix[0] == 0.0 and matrix[3] == 0.0):
		return _reject("Axis-preserving image/non-AA rectangle dispatch is outside this adapter")
	# Blink RectF stores independently lowered origin and size; SkRect right
	# and bottom are float additions, not lowering the double sums.
	var x0: float = args[4]
	var y0: float = args[5]
	var x1: float = _f(x0 + float(args[6]))
	var y1: float = _f(y0 + float(args[7]))
	var points: Array = []
	for point in [[x0, y0], [x1, y0], [x1, y1], [x0, y1]]:
		# SkMatrix::Affine_vpts: scale products + skew products + translation.
		var x: float = _f(_f(_f(float(point[0]) * float(matrix[0])) + _f(float(point[1]) * float(matrix[2]))) + float(matrix[4]))
		var y: float = _f(_f(_f(float(point[1]) * float(matrix[3])) + _f(float(point[0]) * float(matrix[1]))) + float(matrix[5]))
		if not is_finite(x) or not is_finite(y) or absf(x) > 4096.0 or absf(y) > 4096.0:
			return _reject("Transformed coordinates must remain within [-4096,4096]")
		points.append([x, y])
	var bounds: Array = [points[0][0], points[0][1], points[0][0], points[0][1]]
	for point in points:
		bounds[0] = minf(bounds[0], point[0])
		bounds[1] = minf(bounds[1], point[1])
		bounds[2] = maxf(bounds[2], point[0])
		bounds[3] = maxf(bounds[3], point[1])
	var ir: Rect2i = Rect2i(int(floor(bounds[0])), int(floor(bounds[1])), int(ceil(bounds[2])) - int(floor(bounds[0])), int(ceil(bounds[3])) - int(floor(bounds[1])))
	var viewport: Rect2i = Rect2i(0, 0, width, height)
	var clip: Rect2i = viewport if not clip_bounds.has_area() else viewport.intersection(clip_bounds)
	var intersection: Rect2i = clip.intersection(ir)
	_width = width
	_height = height
	_output = PackedByteArray()
	_output.resize(width * height)
	_output.fill(0)
	_row = PackedInt32Array()
	_row.resize(width)
	_row.fill(0)
	_edges = []
	_current_y = -1
	_flushes = 0
	_direct_pixels = 0
	_using_mask = not force_rle and ir.size.x <= 32 and ((ir.size.x + 3) & ~3) * ir.size.y <= 1024
	_clip_ltrb = [float(clip.position.x), float(clip.position.y), float(clip.end.x), float(clip.end.y)]
	_rle_left = intersection.position.x
	_rle_right = intersection.end.x
	# AAA RLE walker bounds are the clip bounds, not the path's rounded bounds.
	# Mask mode additionally restricts them to its allocated path bounds.
	_left = intersection.position.x if _using_mask else clip.position.x
	_right = intersection.end.x if _using_mask else clip.end.x
	_top = intersection.position.y
	_bottom = intersection.end.y
	var contained: bool = clip.encloses(ir)
	if intersection.has_area():
		for index in range(4):
			if contained:
				_add_line(points[index], points[(index + 1) % 4])
			else:
				_clip_line(points[index], points[(index + 1) % 4])
		if _edges.size() >= 2:
			_walk_convex(_bottom)
			_flush()
	last_diagnostics = {"accepted_input": true, "source_revision": SOURCE_REVISION,
		"whole_lens_accepted": false, "force_rle": force_rle,
		"using_mask": _using_mask, "dispatch": "MaskAdditiveBlitter" if _using_mask else "RunBasedAdditiveBlitter",
		"viewport_clipped": not contained, "lowered_matrix": matrix, "lowered_draw_image_args": args,
		"destination_ltrb": [x0, y0, x1, y1], "transformed_points": points,
		"path_bounds_ltrb": bounds, "clip_ltrb": _clip_ltrb,
		"path_irect": [ir.position.x, ir.position.y, ir.end.x, ir.end.y],
		"rle_flushes": _flushes, "direct_pixel_writes": _direct_pixels}
	return _output
