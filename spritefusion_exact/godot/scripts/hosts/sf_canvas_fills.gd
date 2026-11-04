# Original drawLens fill order: Sprite Fusion, Copyright (c) 2026 Hugo Duprez,
# MIT. Selected raster stages derive from Skia revision
# 29ed1e87a0a50f3d8347e988842d9d59e7573efa. Copyright 2012 Google Inc.,
# 2018, 2019, 2022, 2025 Google LLC; 2016 The Android Open Source Project.
# Skia BSD-3-Clause terms: res://licenses/SKIA_LICENSE.txt.
# Chromium geometry dispatch: Copyright The Chromium Authors.
# BSD-style terms: res://licenses/CHROMIUM_LICENSE.txt.
# This helper alone is not a whole-lens or all-browser acceptance claim.
# No shader, JavaScript, reference image or runtime browser is used.
#
# MIT License (original Sprite Fusion effect algorithm only):
# Copyright (c) 2026 Hugo Duprez
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
extends RefCounted

const CanvasGradientModel = preload("res://scripts/hosts/sf_canvas_gradient.gd")

# Chrome155's stable CanvasUsesArcPaintOp routes a fresh full arc fill to
# SkPathPriv::CreateDrawArcPath -> addOval, NOT the clip's two half-arcs.
# Draw::drawDevPath -> AntiFillPath uses forceRLE=false with the rectangular
# device clip. Small bounds select MaskAdditiveBlitter and do not snap alpha.
# Preserve the frozen clip rasterizer and override only these fill distinctions.
class FillCoverage:
	extends "res://scripts/hosts/sf_canvas_clip.gd"
	var _using_mask: bool = false
	var _mask_trapezoid_add: bool = false

	func _init() -> void:
		support_legacy_conic_chop = true

	func _flush() -> void:
		if not _using_mask:
			super._flush()

	func _add(x: int, y: int, alpha: int) -> void:
		if not _using_mask:
			super._add(x, y, alpha)
		elif x >= _left and x < _right and y >= 0 and y < _height:
			var offset: int = y * _width + x
			_output[offset] = mini(255, int(_output[offset]) + alpha)

	func _add_span(x: int, y: int, count: int, alpha: int) -> void:
		if not _using_mask:
			super._add_span(x, y, count, alpha)
		else:
			for i in range(count):
				_add(x + i, y, alpha)

	func _direct(x: int, y: int, alpha: int) -> void:
		if _using_mask and _mask_trapezoid_add:
			_add(x, y, alpha)
		else:
			super._direct(x, y, alpha)

	func _two(x: int, y: int, a1: int, a2: int, full_alpha: int) -> void:
		if not _using_mask:
			super._two(x, y, a1, a2, full_alpha)
		else:
			# blit_two_alphas(maskRow) safely adds even for a full-height row.
			_add(x, y, a1)
			_add(x + 1, y, a2)

	func _full(x: int, y: int, count: int, full_alpha: int) -> void:
		if not _using_mask:
			super._full(x, y, count, full_alpha)
		else:
			_add_span(x, y, count, full_alpha)

	func _aaa_trapezoid(y: int, ul: int, ur: int, ll: int, lr: int, ldy: int, rdy: int, full_alpha: int) -> void:
		# The one-pixel helper still sets full-height coverage directly. The
		# general temporary-alpha array is always safely added to the mask.
		_mask_trapezoid_add = _using_mask and _ceil(lr) - (ul >> 16) > 1
		super._aaa_trapezoid(y, ul, ur, ll, lr, ldy, rdy, full_alpha)
		_mask_trapezoid_add = false

	func build_fill(width: int, height: int, cx: float, cy: float, radius: float) -> PackedByteArray:
		last_error = ""
		last_diagnostics = {}
		if width <= 0 or height <= 0 or width > 4096 or height > 4096:
			return _reject("Only positive viewports at most 4096 by 4096 are supported")
		if not is_finite(cx) or not is_finite(cy) or not is_finite(radius) or radius < 1.0:
			return _reject("The full-arc fill subset requires finite coordinates and radius >= 1")
		cx = _f(cx)
		cy = _f(cy)
		radius = _f(radius)
		if absf(cx) + radius > 4096.0 or absf(cy) + radius > 4096.0:
			return _reject("Circle bounds outside [-4096,4096] require an unsupported large-coordinate path")
		var left: float = _f(cx - radius)
		var right: float = _f(cx + radius)
		var top: float = _f(cy - radius)
		var bottom: float = _f(cy + radius)
		# SkRect center uses a binary64 midpoint then one binary32 conversion.
		var mx: float = _f(0.5 * (left + right))
		var my: float = _f(0.5 * (top + bottom))
		# addOval's direct LTRB/corner points must not be reconstructed from
		# rounded half-extents as clip arcTo does. addOval's default start index
		# is one: clockwise from the rightmost point.
		var points: Array = [[right, my], [right, bottom], [mx, bottom],
			[left, bottom], [left, my], [left, top], [mx, top], [right, top], [right, my]]
		var bound_width: int = int(ceil(right)) - int(floor(left))
		var bound_height: int = int(ceil(bottom)) - int(floor(top))
		_using_mask = bound_width <= 32 and ((bound_width + 3) & ~3) * bound_height <= 1024
		_mask_trapezoid_add = false
		_width = width
		_height = height
		_left = maxi(0, int(floor(left)))
		_right = mini(width, int(ceil(right)))
		_top = maxi(0, int(floor(top)))
		_bottom = mini(height, int(ceil(bottom)))
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
		var contained: bool = left >= 0.0 and top >= 0.0 and right <= float(width) and bottom <= float(height)
		if _left < _right and _top < _bottom:
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
		last_diagnostics = {"accepted_input": true, "whole_lens_accepted": false,
			"shape": "Chrome155 full arc fill -> addOval", "source_revision": SOURCE_REVISION,
			"coverage_dispatch": "small_mask" if _using_mask else "convex_rle",
			"support_legacy_conic_chop": support_legacy_conic_chop,
			"rasterize_even_rounding": rasterize_even_rounding,
			"oval_ltrb": [left, top, right, bottom], "path_bounds_size": [bound_width, bound_height],
			"viewport_clipped": not contained, "rle_flushes": _flushes, "conic_quadratics": _quad_count}
		return _output

var last_error: String = ""
var last_diagnostics: Dictionary = {}
var _gradient = CanvasGradientModel.new()
var _coverage = FillCoverage.new()

func prepare_inner(lens: Dictionary) -> Dictionary:
	var r0: float = _gradient.f32(float(lens.rs) * 0.9)
	var r1: float = _gradient.f32(float(lens.rs) * 1.6)
	var delta: float = _gradient.f32(r1 - r0)
	var scale: float = _gradient.f32(1.0 / r1)
	var inner: float = _gradient.f32(float(_gradient.legacy_alpha_byte("0.5")) / 255.0)
	return {"enabled": true, "r0": r0, "r1": r1, "radius_delta": delta,
		"coordinate_scale": scale,
		"translation_x": _gradient.f32(-_gradient.f32(float(lens.x)) * scale),
		"translation_y": _gradient.f32(-_gradient.f32(float(lens.y)) * scale),
		"t_scale": _gradient.f32(r1 / delta), "t_bias": _gradient.f32(-r0 / delta),
		"inner": inner, "alpha_factor": _gradient.f32(0.0 - inner),
		"rgb": [_gradient.f32(6.0 / 255.0), _gradient.f32(2.0 / 255.0), _gradient.f32(10.0 / 255.0)],
		"dither_rate": _gradient.f32(1.0 / 255.0), "inner_byte": 128}

func inner_alpha_at(x: int, y: int, config: Dictionary) -> float:
	var ux: float = _gradient.f32(_gradient.f32(_gradient.f32(float(x) + 0.5) * float(config.coordinate_scale)) + float(config.translation_x))
	var uy: float = _gradient.f32(_gradient.f32(_gradient.f32(float(y) + 0.5) * float(config.coordinate_scale)) + float(config.translation_y))
	var radius: float = _gradient.f32(sqrt(_gradient.f32(_gradient.f32(ux * ux) + _gradient.f32(uy * uy))))
	var t: float = _gradient.f32(_gradient.f32(radius * float(config.t_scale)) + float(config.t_bias))
	t = clampf(t, 0.0, 1.0)
	return _gradient.f32(_gradient.f32(t * float(config.alpha_factor)) + float(config.inner))

func _reject(message: String) -> PackedByteArray:
	last_error = message
	last_diagnostics = {"accepted_input": false, "error": message, "whole_lens_accepted": false}
	push_error("SfCanvasFills: " + message)
	return PackedByteArray()

# This public scalar operation also supports source-stage diagnostic vectors.
# Coverage scales the dithered premultiplied color, NOT the interpolated alpha
# before premultiplication/dither. The opaque input is materialized per draw.
func blend_pixel(destination: PackedByteArray, x: int, y: int, alpha: float, rgb: Array, coverage: int) -> PackedByteArray:
	assert(destination.size() == 4 and destination[3] == 255)
	assert(coverage >= 0 and coverage <= 255)
	if coverage == 0:
		return destination.duplicate()
	var result := PackedByteArray([0, 0, 0, 0])
	var rate: float = _gradient.f32(1.0 / 255.0)
	var noise: float = _gradient.cpu_noise(x, y, rate)
	var cov: float = _gradient.f32(float(coverage) * rate)
	var covered_alpha: float = _gradient.f32(alpha * cov) if coverage != 255 else alpha
	var remaining: float = _gradient.f32(1.0 - covered_alpha)
	for channel in range(4):
		var source: float = alpha
		if channel < 3:
			source = _gradient.f32(float(rgb[channel]) * alpha)
			source = clampf(_gradient.f32(source + noise), 0.0, alpha)
		if coverage != 255:
			source = _gradient.f32(source * cov)
		var dest: float = _gradient.f32(float(destination[channel]) * rate)
		var blended: float = _gradient.f32(_gradient.f32(dest * remaining) + source)
		result[channel] = _gradient.byte_nearest_even(_gradient.f32(blended * 255.0))
	return result

func _apply_one(destination: PackedByteArray, width: int, height: int, lens: Dictionary, kind: String) -> PackedByteArray:
	if kind == "gloom" and float(lens.gloom) <= 0.01:
		return destination.duplicate()
	var config: Dictionary = _gradient.prepare_gloom(lens) if kind == "gloom" else prepare_inner(lens)
	if not config.enabled:
		return destination.duplicate()
	# Preserve each original binary64 API radius expression until build_fill's
	# independent float32 lowering. Do not multiply already lowered rs.
	var fill_radius: float = float(lens.rs) * (7.5 if kind == "gloom" else 1.6)
	var coverage: PackedByteArray = _coverage.build_fill(width, height, float(lens.x), float(lens.y), fill_radius)
	if coverage.size() != width * height:
		return _reject(_coverage.last_error)
	var actual: PackedByteArray = destination.duplicate()
	var touched: int = 0
	var partial: int = 0
	for y in range(height):
		for x in range(width):
			var pixel: int = y * width + x
			var cov: int = coverage[pixel]
			if cov == 0:
				continue
			var alpha: float = _gradient.gloom_alpha_at(x, y, config) if kind == "gloom" else inner_alpha_at(x, y, config)
			var offset: int = pixel * 4
			var rgba: PackedByteArray = blend_pixel(destination.slice(offset, offset + 4), x, y, alpha, config.rgb, cov)
			for channel in range(4):
				actual[offset + channel] = rgba[channel]
			touched += 1
			partial += 1 if cov != 255 else 0
	last_diagnostics.fills.append({"kind": kind, "config": config,
		"coverage": _coverage.last_diagnostics.duplicate(true), "covered_pixels": touched,
		"partial_pixels": partial, "materialized_rgba8": true})
	return actual

# Input is the opaque RGBA8 result after all original ordered ring draws.
# Supported state: identity CTM, rectangular viewport clip, source-over, paint
# alpha one, no filters, sRGB/unorm8, the pinned non-FMA CPU stage alternative.
# Unsupported inputs fail explicitly with empty bytes and last_error, never an
# approximate fallback. The original drawLens early-return guard is retained.
func apply_fills(opaque_rgba: PackedByteArray, width: int, height: int, lens: Dictionary) -> PackedByteArray:
	last_error = ""
	last_diagnostics = {"accepted_input": true, "whole_lens_accepted": false, "fills": [],
		"arithmetic": "nonfma_source_compatible", "browser_dispatch_proven": false}
	if width <= 0 or height <= 0 or width > 4096 or height > 4096 or opaque_rgba.size() != width * height * 4:
		return _reject("Expected RGBA8 and a positive viewport at most 4096 by 4096")
	for key in ["x", "y", "rs", "rOut", "gloom"]:
		if not lens.has(key) or not is_finite(float(lens[key])):
			return _reject("Missing or nonfinite lens parameter: " + key)
	for offset in range(3, opaque_rgba.size(), 4):
		if opaque_rgba[offset] != 255:
			return _reject("Only opaque RGBA8 destinations are supported")
	if float(lens.rs) < 1.0 or float(lens.rOut) < float(lens.rs) + 4.0:
		last_diagnostics["original_early_return"] = true
		return opaque_rgba.duplicate()
	var result: PackedByteArray = _apply_one(opaque_rgba, width, height, lens, "gloom")
	if result.is_empty():
		return result
	return _apply_one(result, width, height, lens, "inner")
