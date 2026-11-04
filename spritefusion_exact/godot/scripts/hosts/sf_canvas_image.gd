# Restricted Skia raster-pipeline image stages, not a complete Canvas renderer.
# Derived from Skia 29ed1e87a0a50f3d8347e988842d9d59e7573efa:
# src/opts/SkRasterPipeline_opts.h and src/core/SkMatrix.cpp.
# Copyright 2016 Google Inc. and 2006 The Android Open Source Project.
# BSD-3-Clause; see res://licenses/SKIA_LICENSE.txt.
# The captured browser process flags were not inspectable; six complete outputs
# matched this source-based pipeline exactly, not every possible browser backend.
# Runtime use does not perform a pixel comparison or imply universal acceptance.
extends RefCounted

static func f32(value: float) -> float:
	return PackedFloat32Array([value])[0]

static func _i16(value: int) -> int:
	var low := value & 65535
	return low - 65536 if low >= 32768 else low

static func scaled_mult_x86(a: int, b: int) -> int:
	return _i16((_i16(a) * _i16(b) + 16384) >> 15)

static func _lerp_x(left: int, right: int, tx: int) -> int:
	var width := _i16((right - left) << 7)
	var middle := (right + left) << 7
	var total := scaled_mult_x86(tx, width) + middle
	assert(total >= 0 and total <= 65535)
	return ((total + 1) & 65535) >> 1

static func _lerp_y(top: int, bottom: int, ty: int) -> int:
	var width := _i16(_i16(bottom) - _i16(top))
	var middle := (bottom + top) & 65535
	var total := scaled_mult_x86(ty, width) + middle
	assert(total >= 0 and total <= 65535)
	return ((total + 128) & 65535) >> 8

# Coordinates use the source image's pixel edges; centers are n + 0.5.
# Input bytes must already be premultiplied RGBA8. The original crop geometry
# controls coverage separately; sampling clamps to full source image bounds.
static func bilerp_clamp_lowp(source: PackedByteArray, width: int, height: int, x: float, y: float) -> PackedByteArray:
	assert(width > 0 and height > 0 and source.size() == width * height * 4)
	assert(is_finite(x) and is_finite(y) and absf(x) < 32767.0 and absf(y) < 32767.0)
	var qx := int(floor(f32(f32(65536.0 * f32(x)) + 0.5))) - 32768
	var qy := int(floor(f32(f32(65536.0 * f32(y)) + 0.5))) - 32768
	var sx := qx >> 16
	var sy := qy >> 16
	var tx := _i16(qx ^ 32768)
	var ty := _i16(qy ^ 32768)
	var left := clampi(sx, 0, width - 1)
	var right := clampi(sx + 1, 0, width - 1)
	var top := clampi(sy, 0, height - 1)
	var bottom := clampi(sy + 1, 0, height - 1)
	var tl := (top * width + left) * 4
	var tr := (top * width + right) * 4
	var bl := (bottom * width + left) * 4
	var br := (bottom * width + right) * 4
	var output := PackedByteArray()
	output.resize(4)
	for channel in range(4):
		var upper := _lerp_x(source[tl + channel], source[tr + channel], tx)
		var lower := _lerp_x(source[bl + channel], source[br + channel], tx)
		output[channel] = _lerp_y(upper, lower, ty)
	return output

# Canvas [a,b,c,d,e,f] affine order. Pinned Skia computes its determinant and
# inverse intermediates as doubles, then stores each inverse coefficient as f32.
static func inverse_affine(canvas_transform: Array) -> Array:
	assert(canvas_transform.size() == 6)
	var a := f32(canvas_transform[0])
	var b := f32(canvas_transform[1])
	var c := f32(canvas_transform[2])
	var d := f32(canvas_transform[3])
	var e := f32(canvas_transform[4])
	var f := f32(canvas_transform[5])
	var determinant := a * d - c * b
	assert(absf(f32(determinant)) > pow(1.0 / 4096.0, 3.0), "Out-of-scope singular affine")
	var inv := 1.0 / determinant
	return [f32(d * inv), f32(-b * inv), f32(-c * inv), f32(a * inv), f32((c * f - d * e) * inv), f32((b * e - a * f) * inv)]

# Uniform non-FMA branch only; no selection by case or pixel.
static func map_affine_nonfma(inverse: Array, x: float, y: float) -> Array:
	assert(inverse.size() == 6)
	x = f32(x)
	y = f32(y)
	return [f32(f32(x * inverse[0]) + f32(f32(y * inverse[2]) + inverse[4])), f32(f32(x * inverse[1]) + f32(f32(y * inverse[3]) + inverse[5]))]

static func div255_accurate(value: int) -> int:
	assert(value >= 0 and value <= 65025)
	value += 128
	return (value + (value >> 8)) >> 8

static func div255_x86(value: int) -> int:
	assert(value >= 0 and value <= 65025)
	return (value + 255) >> 8

# A8 combination and source-prescale are deliberately separate operations.
static func combine_coverage(circle: int, image_edge: int) -> int:
	return div255_accurate(circle * image_edge)

static func scale_coverage_lowp_x86(source: PackedByteArray, coverage: int) -> PackedByteArray:
	assert(source.size() == 4 and coverage >= 0 and coverage <= 255)
	var result := PackedByteArray()
	result.resize(4)
	for channel in range(4): result[channel] = div255_x86(source[channel] * coverage)
	return result

# Ordinary source-over lowp stage; not the compound srcover_rgba_8888 stage.
static func srcover_lowp(source: PackedByteArray, destination: PackedByteArray, inaccurate_compile_switch: bool = false) -> PackedByteArray:
	assert(source.size() == 4 and destination.size() == 4)
	var result := PackedByteArray()
	result.resize(4)
	for channel in range(4):
		var product := destination[channel] * (255 - source[3])
		var other := div255_x86(product) if inaccurate_compile_switch else div255_accurate(product)
		result[channel] = mini(255, source[channel] + other)
	return result
