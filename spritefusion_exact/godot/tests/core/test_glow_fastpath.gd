extends SceneTree
const Pixels = preload("res://scripts/core/sf_pixel_buffer.gd")
var checks: int = 0
var failures: Array[String] = []
var random = RandomNumberGenerator.new()

func _initialize() -> void:
	random.seed = 0x721d45a3
	# Explicit source coercion/fallback and numeric bounds, then deterministic
	# random overlapping glows. Each operation compares the full packed buffers.
	for origin in [[0.0, 0.0], [-0.0, -0.0], [-27.0, 13.0], [0.5, -0.75], [-0.5, 1.25], [2147483600.0, -2147483600.0], [2147483648.0, -2147483649.0]]:
		for fire in [false, true]:
			var fast = Pixels.new(37, 29, origin[0], origin[1])
			var scalar = Pixels.new(37, 29, origin[0], origin[1])
			for i in range(fast.data.size()):
				fast.data[i] = random.randi()
				scalar.data[i] = fast.data[i]
			var operations: Array = []
			for radius in [-1.0, 0.0, 0.9999999999999999, 1.0, 1.0000000000000002, 3.0, 15.125, 80.0, 1.0e308, 1.7976931348623157e308]:
				for strength in [-1.0, 0.0, 0.01, 0.010000000000000002, 0.3, 1.0, 255.0, 1.0e308, 1.7976931348623157e308]:
					operations.append([origin[0] + 18.5, origin[1] + 14.5, radius, random.randi(), strength])
			for color in [0, -1, 0x7fffffff, 0x80000000, 0xffffffff, 0x123456789abcdef, -9223372036854775807]:
				operations.append([origin[0], origin[1], 20.0, color, 0.7])
			for n in range(100):
				operations.append([origin[0] + random.randf_range(-50.0, 80.0), origin[1] + random.randf_range(-40.0, 70.0), random.randf_range(1.0, 95.0), random.randi(), random.randf_range(0.01, 3.0)])
			for op in operations:
				# Reset between edge cases so a prior saturated result cannot
				# conceal a later channel/coordinate discrepancy.
				for i in range(fast.data.size()):
					fast.data[i] = random.randi()
					scalar.data[i] = fast.data[i]
				fast.glow(op[0], op[1], op[2], op[3], op[4], fire)
				scalar._glow_scalar(op[0], op[1], op[2], op[3], op[4], fire)
				checks += 1
				if fast.data != scalar.data:
					failures.append("origin=%s fire=%s operation=%s" % [origin, fire, op])
					break
			fast.clear()
			scalar.clear()
			for n in range(40):
				var cx: float = origin[0] + random.randf_range(-10.0, 45.0)
				var cy: float = origin[1] + random.randf_range(-10.0, 35.0)
				var radius: float = random.randf_range(1.0, 35.0)
				var color: int = random.randi()
				var strength: float = random.randf_range(0.01, 0.2)
				fast.glow(cx, cy, radius, color, strength, fire)
				scalar._glow_scalar(cx, cy, radius, color, strength, fire)
				checks += 1
				if fast.data != scalar.data:
					failures.append("overlap origin=%s fire=%s operation=%s" % [origin, fire, n])
					break
	# Empty/fully clipped geometry and non-finite centers/strengths are bounded
	# operations in the original. Infinite radius is intentionally excluded: the
	# source can encounter infinite iteration for unusual infinite cameras.
	for op in [[-1.0e308, 0.0, 1.0, 0xffffff, 1.0], [1.0e308, 0.0, 1.0, 0xffffff, 1.0], [INF, 0.0, 1.0, 0xffffff, 1.0], [-INF, 0.0, 1.0, 0xffffff, 1.0], [NAN, 0.0, 1.0, 0xffffff, 1.0], [2.0, 2.0, 3.0, 0xffffff, INF], [2.0, 2.0, 3.0, 0xffffff, NAN], [1.7976931348623157e308, 0.0, 1.7976931348623157e308, 0xffffffff, 1.7976931348623157e308], [-1.7976931348623157e308, 0.0, 1.7976931348623157e308, 0xffffffff, 1.7976931348623157e308], [0.0, 1.7976931348623157e308, 1.7976931348623157e308, 0xffffffff, 1.7976931348623157e308], [0.0, -1.7976931348623157e308, 1.7976931348623157e308, 0xffffffff, 1.7976931348623157e308]]:
		var fast = Pixels.new(7, 5)
		var scalar = Pixels.new(7, 5)
		fast.glow(op[0], op[1], op[2], op[3], op[4])
		scalar._glow_scalar(op[0], op[1], op[2], op[3], op[4])
		checks += 1
		if fast.data != scalar.data: failures.append("non-finite operation=%s" % [op])
	for origin in [-2147483647.0, 2147483647.0]:
		var fast = Pixels.new(1, 1, origin, origin)
		var scalar = Pixels.new(1, 1, origin, origin)
		checks += 1
		if not fast._integer_glow_camera(): failures.append("1x1 boundary camera rejected")
		for radius in [1.0, 1.0000000000000002, 80.0, 1.7976931348623157e308]:
			for color in [0, -1, 0x04030201, -9223372036854775807]:
				fast.clear(0x10203040)
				scalar.clear(0x10203040)
				fast.glow(origin, origin, radius, color, 0.75)
				scalar._glow_scalar(origin, origin, radius, color, 0.75)
				checks += 1
				if fast.data != scalar.data: failures.append("1x1 boundary output mismatch")
	var eligibility = Pixels.new(37, 29)
	if not eligibility._integer_glow_camera(): failures.append("integer origin not eligible")
	eligibility.ox = 0.5
	if eligibility._integer_glow_camera(): failures.append("fractional origin eligible")
	eligibility.ox = 2147483640.0
	if eligibility._integer_glow_camera(): failures.append("out-of-range far edge eligible")
	eligibility.ox = NAN
	if eligibility._integer_glow_camera(): failures.append("NaN origin eligible")
	checks += 4
	if failures.is_empty():
		print("GLOW FASTPATH PASS: %s complete-buffer comparisons/guards" % checks)
		quit(0)
	else:
		for failure in failures: printerr(failure)
		quit(1)
