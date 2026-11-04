# Uniform FMA implementation for the pinned Skia highp mad sites only.
# Inherits the original MIT fill order, geometry and byte storage without edits.
# Skia 29ed1e87a0a50f3d8347e988842d9d59e7573efa, Copyright 2018, 2022 Google LLC.
# BSD-3-Clause terms: res://licenses/SKIA_LICENSE.txt. The base helper retains
# the separate Sprite Fusion MIT notice, Copyright (c) 2026 Hugo Duprez.
# Whole-lens acceptance is bounded to the cases documented with the scene.
extends "res://scripts/hosts/sf_canvas_fills.gd"

const FloatFma = preload("res://scripts/hosts/sf_f32_fma.gd")

class FusedGradient:
	extends "res://scripts/hosts/sf_canvas_gradient.gd"
	const FmaArithmetic = preload("res://scripts/hosts/sf_f32_fma.gd")
	var _mad = FmaArithmetic.new()

	func gloom_alpha_at(x: int, y: int, config: Dictionary) -> float:
		if not config.enabled:
			return 0.0
		var ux: float = _mad.mad(f32(float(x) + 0.5), float(config.coordinate_scale), float(config.translation_x))
		var uy: float = _mad.mad(f32(float(y) + 0.5), float(config.coordinate_scale), float(config.translation_y))
		# xy_to_radius explicitly materializes X2 and Y2, then adds. It is not mad.
		var radius: float = f32(sqrt(f32(f32(ux * ux) + f32(uy * uy))))
		var t: float = _mad.mad(radius, float(config.t_scale), float(config.t_bias))
		if t < 0.0:
			return float(config.inner)
		if t < float(config.split):
			return _mad.mad(t, float(config.first_factor), float(config.first_bias))
		if t < 1.0:
			return _mad.mad(t, float(config.second_factor), float(config.second_bias))
		return 0.0

var _mad = FloatFma.new()

func _init() -> void:
	# Coefficient/radius setup still uses the frozen source's separate float
	# operations. Only explicit SkRasterPipeline mad sites use this alternative.
	_gradient = FusedGradient.new()

func inner_alpha_at(x: int, y: int, config: Dictionary) -> float:
	var ux: float = _mad.mad(_gradient.f32(float(x) + 0.5), float(config.coordinate_scale), float(config.translation_x))
	var uy: float = _mad.mad(_gradient.f32(float(y) + 0.5), float(config.coordinate_scale), float(config.translation_y))
	var radius: float = _gradient.f32(sqrt(_gradient.f32(_gradient.f32(ux * ux) + _gradient.f32(uy * uy))))
	var t: float = _mad.mad(radius, float(config.t_scale), float(config.t_bias))
	t = clampf(t, 0.0, 1.0)
	return _mad.mad(t, float(config.alpha_factor), float(config.inner))

func blend_pixel(destination: PackedByteArray, x: int, y: int, alpha: float, rgb: Array, coverage: int) -> PackedByteArray:
	assert(destination.size() == 4 and destination[3] == 255)
	assert(coverage >= 0 and coverage <= 255)
	if coverage == 0:
		return destination.duplicate()
	var result := PackedByteArray([0, 0, 0, 0])
	var rate: float = _gradient.f32(1.0 / 255.0)
	var yy: int = y ^ x
	var rank: int = ((yy & 1) << 5) | ((x & 1) << 4) | ((yy & 2) << 2) | ((x & 2) << 1) | ((yy & 4) >> 1) | ((x & 4) >> 2)
	var dither: float = _mad.mad(float(rank), _gradient.f32(2.0 / 128.0), -_gradient.f32(63.0 / 128.0))
	var cov: float = _gradient.f32(float(coverage) * rate)
	var covered_alpha: float = _gradient.f32(alpha * cov) if coverage != 255 else alpha
	var remaining: float = _gradient.f32(1.0 - covered_alpha)
	for channel in range(4):
		var source: float = alpha
		if channel < 3:
			source = _gradient.f32(float(rgb[channel]) * alpha)
			source = clampf(_mad.mad(dither, rate, source), 0.0, alpha)
		if coverage != 255:
			source = _gradient.f32(source * cov)
		var dest: float = _gradient.f32(float(destination[channel]) * rate)
		var blended: float = _mad.mad(dest, remaining, source)
		result[channel] = _gradient.byte_nearest_even(_gradient.f32(blended * 255.0))
	return result

func apply_fills(opaque_rgba: PackedByteArray, width: int, height: int, lens: Dictionary) -> PackedByteArray:
	var output: PackedByteArray = super.apply_fills(opaque_rgba, width, height, lens)
	last_diagnostics["arithmetic"] = "uniform_fma_explicit_highp_mad_sites"
	last_diagnostics["fma_reconstruction"] = "exact finite binary32 product plus error-free binary64 TwoSum"
	return output
