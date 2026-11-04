# Pinned-stage v2: isolated non-FMA reference, not a complete Skia/lens raster.
# See external PINNED_STAGE_REPORT.md for source dispatch and remaining limits.
# CSS alpha8: Chromium 155.0.8059.79 legacy comma-separated rgba() parsing.
# Dither: Skia 29ed1e87a0a50f3d8347e988842d9d59e7573efa CPU raster stage.
# Source links and version limits are retained in the external QA manifest.
# No ring drawing, snapshot sampling, transform rasterization, or path AA here.
extends RefCounted

const MODEL_NAMES := ["nonfma_source_compatible"]

# GDScript float expressions are binary64. Round each specified operation to
# binary32 using one reusable store, rather than allocating a packed array for
# every operation. One instance belongs to one sequential diagnostic render.
var _single := PackedFloat32Array([0.0])
var _double_bits := PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0])

func f32(value: float) -> float:
	_single[0] = value
	return _single[0]

# Exact toFixed(3) rounding for the nonnegative [0,1] alpha domain used here.
# The integer ratio avoids changing a binary64 tie through value*1000. The
# largest mantissa*1000 is below INT64_MAX. A positive tie rounds upward, as
# ECMAScript toFixed requires. This is not a general number-formatting API.
func to_fixed3_alpha(value: float) -> String:
	assert(is_finite(value) and value >= 0.0 and value <= 1.0)
	if value < 0.0005:
		return "0.000"
	_double_bits.encode_double(0, value)
	var bits: int = _double_bits.decode_u64(0)
	var exponent: int = (bits >> 52) & 2047
	var numerator: int = ((bits & 4503599627370495) | 4503599627370496) * 1000
	var shift: int = 1075 - exponent
	var milli: int
	if shift == 63:
		milli = 1 if numerator >= 4611686018427387904 else 0
	else:
		var denominator: int = 1 << shift
		milli = numerator / denominator
		if numerator % denominator >= denominator / 2:
			milli += 1
	return "%d.%03d" % [milli / 1000, milli % 1000]

# Parse the original decimal text as binary64 before lround(alpha*255).
# This applies only to legacy rgba() alpha, not all CSS color syntax.
func legacy_alpha_byte(decimal_alpha: String) -> int:
	var parsed: float = clampf(decimal_alpha.to_float(), 0.0, 1.0)
	return clampi(int(floor(parsed * 255.0 + 0.5)), 0, 255)

func prepare_gloom(lens: Dictionary) -> Dictionary:
	var inner_text := to_fixed3_alpha(minf(0.85, 0.55 * float(lens.gloom)))
	var middle_text := to_fixed3_alpha(minf(0.5, 0.26 * float(lens.gloom)))
	var inner_byte := legacy_alpha_byte(inner_text)
	var middle_byte := legacy_alpha_byte(middle_text)
	var inner := f32(float(inner_byte) / 255.0)
	var middle := f32(float(middle_byte) / 255.0)
	# Independently convert the original binary64 API radius arguments.
	var r0 := f32(float(lens.rs))
	var r1 := f32(float(lens.rs) * 7.5)
	var maximum := maxf(r0, r1)
	var delta := f32(r1 - r0)
	var coordinate_scale := f32(1.0 / maximum)
	var split := f32(0.3)
	var first_factor := f32(f32(middle - inner) * f32(1.0 / split))
	var second_factor := f32(f32(0.0 - middle) * f32(1.0 / f32(1.0 - split)))
	var second_bias := f32(middle - f32(second_factor * split))
	return {
		"enabled": float(lens.gloom) > 0.01,
		"r0": r0, "r1": r1, "radius_delta": delta,
		"coordinate_scale": coordinate_scale,
		"translation_x": f32(-f32(float(lens.x)) * coordinate_scale),
		"translation_y": f32(-f32(float(lens.y)) * coordinate_scale),
		"t_scale": f32(maximum / delta), "t_bias": f32(-r0 / delta),
		"split": split, "first_factor": first_factor,
		"first_bias": inner, "second_factor": second_factor,
		"second_bias": second_bias, "inner": inner, "middle": middle,
		"inner_text": inner_text, "middle_text": middle_text,
		"inner_byte": inner_byte, "middle_byte": middle_byte,
		# Stop RGB uses the Chromium double-literal division then float32.
		"rgb": [f32(12.0 / 255.0), f32(4.0 / 255.0), f32(24.0 / 255.0)],
		"dither_rate": f32(1.0 / 255.0),
	}

# Skia's scale/translate stage, separate X2/Y2, and concentric scale/bias.
# Every mad in this v2 is intentionally the uniform NON-FMA source alternative.
func gloom_alpha_at(x: int, y: int, config: Dictionary) -> float:
	if not config.enabled:
		return 0.0
	var ux := f32(f32(f32(float(x) + 0.5) * float(config.coordinate_scale)) + float(config.translation_x))
	var uy := f32(f32(f32(float(y) + 0.5) * float(config.coordinate_scale)) + float(config.translation_y))
	var radius := f32(sqrt(f32(f32(ux * ux) + f32(uy * uy))))
	var t := f32(f32(radius * float(config.t_scale)) + float(config.t_bias))
	# General explicit stops use >= boundaries and constant outside regions.
	if t < 0.0:
		return float(config.inner)
	if t < float(config.split):
		return f32(f32(t * float(config.first_factor)) + float(config.first_bias))
	if t < 1.0:
		return f32(f32(t * float(config.second_factor)) + float(config.second_bias))
	return 0.0

func cpu_noise(x: int, y: int, rate: float) -> float:
	var yy := y ^ x
	var rank: int = ((yy & 1) << 5) | ((x & 1) << 4) | ((yy & 2) << 2) | ((x & 2) << 1) | ((yy & 4) >> 1) | ((x & 4) >> 2)
	var centered := f32(f32(float(rank) * f32(2.0 / 128.0)) - f32(63.0 / 128.0))
	return f32(centered * rate)

func byte_nearest_even(scaled: float) -> int:
	var lower := int(floor(scaled))
	var fraction := scaled - float(lower)
	if fraction > 0.5 or (fraction == 0.5 and (lower & 1) != 0):
		lower += 1
	return clampi(lower, 0, 255)

# Strictly limited to opaque source-over inside the supplied gloom mask.
# Pixels outside it remain background, so this is never a complete lens image.
# The dither+compound byte blend is deliberately absent: its dispatch condition
# requires zero dither, whereas this gradient has rate 1/255.
func render_gloom_models(background: PackedByteArray, width: int, height: int, lens: Dictionary, support: PackedByteArray) -> Dictionary:
	assert(background.size() == width * height * 4)
	assert(support.size() == width * height)
	var actual := background.duplicate()
	var config := prepare_gloom(lens)
	assert(config.enabled and float(config.radius_delta) > 0.0)
	var rate: float = config.dither_rate
	for y in range(height):
		for x in range(width):
			var pixel := y * width + x
			if support[pixel] == 0:
				continue
			var offset := pixel * 4
			assert(background[offset + 3] == 255, "Reference only supports opaque backgrounds")
			var alpha := gloom_alpha_at(x, y, config)
			var remaining := f32(1.0 - alpha)
			var noise := cpu_noise(x, y, rate)
			for channel in range(4):
				var source := alpha
				if channel < 3:
					source = f32(float(config.rgb[channel]) * alpha)
					source = clampf(f32(source + noise), 0.0, alpha)
				# from_8888 multiplies by the binary32 reciprocal of 255.
				var destination := f32(float(background[offset + channel]) * rate)
				var blended := f32(f32(destination * remaining) + source)
				var scaled := f32(blended * 255.0)
				actual[offset + channel] = byte_nearest_even(scaled)
	return {"nonfma_source_compatible": actual, "config": config}
