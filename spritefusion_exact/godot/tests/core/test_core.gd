extends SceneTree
const VectorReader = preload("res://tests/core/read_vectors.gd")
const JS = preload("res://scripts/core/sf_math.gd")
const Rng = preload("res://scripts/core/sf_rng.gd")
const Frame = preload("res://scripts/core/sf_frame.gd")
const Canvas = preload("res://scripts/core/sf_canvas.gd")
const Clock = preload("res://scripts/core/sf_fixed_clock.gd")
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	var vectors = VectorReader.read("res://tests/core/core_vectors.json")
	if vectors.is_empty():
		quit(2)
		return
	for case in vectors.rng:
		var rng = Rng.new(case.seed)
		for i in range(case.words.size()):
			check(int(rng.next() * 4294967296.0) == int(case.words[i]), "rng seed=%s index=%s" % [case.seed, i])
		check(rng.s == int(case.state), "rng state seed=%s" % case.seed)
	for case in vectors.rngMethods:
		var rng = Rng.new(case.seed)
		for operation in case.operations:
			var op: Array = operation.op
			var method: String = "integer" if op[0] == "int" else op[0]
			var actual = rng.callv(method, op.slice(1))
			var expected = operation.expected if operation.expected_bits.is_empty() else operation.expected_bits.hex_decode().decode_double(0)
			check(actual == expected, "RNG method=%s seed=%s" % [method, case.seed])
			check(rng.s == int(operation.state), "RNG state after method=%s seed=%s" % [method, case.seed])
	for case in vectors.numeric:
		check(JS.u32(case.n) == int(case.u32), "u32(%s)" % case.n)
		check(JS.i32(case.n) == int(case.i32), "i32(%s)" % case.n)
		check(JS.js_round(case.n) == int(case.round), "round(%s)" % case.n)
		for shift in case.shifts:
			check(JS.ushr(case.n, shift[0]) == int(shift[1]), "ushr(%s,%s)" % [case.n, shift[0]])
			check(JS.shl(case.n, shift[0]) == int(shift[2]), "shl(%s,%s)" % [case.n, shift[0]])
	for product in vectors.products:
		check(JS.imul(product[0], product[1]) == int(product[2]), "imul(%s,%s)" % [product[0], product[1]])
	for case in vectors.colors:
		var ch = case.channels
		check(JS.rgb(ch[0], ch[1], ch[2], ch[3]) == int(case.value), "rgb(%s)" % [ch])
	for values in vectors.mixes:
		check(JS.mix(int(values[0]), int(values[1]), values[2]) == int(values[3]), "mix(%s)" % [values])
	for values in vectors.hashes:
		check(JS.hash(values[0], values[1]) == values[2], "hash(%s)" % [values])
		check(JS.hash_muzzle(values[0], values[1]) == values[3], "hash_muzzle(%s)" % [values])
	for values in vectors.noise:
		var nx: float = values[3].hex_decode().decode_double(0)
		var nk: float = values[4].hex_decode().decode_double(0)
		var expected_noise: float = values[5].hex_decode().decode_double(0)
		check(JS.noise(nx, nk) == expected_noise, "noise(%s)" % [values])
	for case in vectors.pixels:
		var f = Frame.new(int(case.frame.w), int(case.frame.h), case.frame.ox, case.frame.oy)
		for snapshot in case.ops:
			apply_operation(f.color, snapshot.op, case.source == "fire.ts")
			for i in range(snapshot.expected.size()):
				if not check(f.color.data[i] == int(snapshot.expected[i]), "%s origin=(%s,%s) %s pixel=%s got=%08x expected=%08x" % [case.source, f.ox, f.oy, snapshot.op[0], i, f.color.data[i], int(snapshot.expected[i])]):
					break
		var bytes: PackedByteArray = f.color.rgba_bytes()
		for i in range(f.color.data.size()):
			check(bytes.decode_u32(i * 4) == f.color.data[i], "RGBA little-endian word conversion")
		check(f.color.to_image().get_data() == bytes, "Image RGBA byte preservation")
		f.clear()
		check(f.color.data.count(0) == f.w * f.h and f.light.data.count(0) == f.w * f.h, "frame clear")
	var alias_frame = Frame.new(3, 2)
	var source: Dictionary = alias_frame.as_source()
	var px_alias: PackedInt64Array = source.color
	px_alias[2] = 0xffaabbcc
	check(alias_frame.color.data[2] == 0xffaabbcc, "source Px constructor aliases frame data")
	alias_frame.color.put(0, 1, 0xff334455)
	check(source.color[3] == 0xff334455, "source frame sees native pixel writes")
	alias_frame.clear()
	check(px_alias[2] == 0, "source alias survives frame clear")
	var count := [0]
	var update := func(dt):
		check(dt == 1.0 / 60.0, "fixed dt")
		count[0] += 1
	var clock = Clock.new()
	for _i in range(120):
		clock.advance(1.0 / 120.0, update)
	check(count[0] == 60 and clock.ticks == 60, "120Hz input => 60 simulation ticks")
	clock.step(update, 5)
	check(count[0] == 65, "explicit tick stepping")
	clock.reset()
	count[0] = 0
	check(clock.advance(1.0, update) == 60 and clock.ticks == 60, "one-second chunk => exactly 60 ticks")
	check(clock.accumulator == 0.0, "exact boundary residual normalized")
	clock.reset()
	for _i in range(100):
		clock.advance(0.1, update)
	check(clock.ticks == 600, "100 decimal chunks => exactly 600 ticks")
	clock.reset()
	for _i in range(1000):
		clock.advance(0.016, update)
	check(clock.ticks == 960, "1000 16ms chunks => exactly 960 ticks")
	clock.reset()
	check(clock.advance(10.0, update) == 600 and clock.ticks == 600, "ten-second chunk => exactly 600 ticks")
	clock.reset()
	check(clock.advance(3600.0, update) == 216000 and clock.ticks == 216000, "one-hour chunk => exactly 216000 ticks")
	if failures.is_empty():
		print("CORE PASS: %s assertions; %s seeds; %s source/origin raster cases." % [checks, vectors.rng.size(), vectors.pixels.size()])
		quit(0)
	else:
		for problem in failures.slice(0, 30):
			printerr(problem)
		printerr("CORE FAIL: %s failures / %s checks" % [failures.size(), checks])
		quit(1)

func check(condition: bool, message: String) -> bool:
	checks += 1
	if not condition:
		failures.append(message)
	return condition

func apply_operation(buffer, op: Array, fire: bool) -> void:
	match op[0]:
		"set": buffer.put(op[1], op[2], int(op[3]))
		"blend": buffer.blend(op[1], op[2], int(op[3]), op[4])
		"add":
			if fire: buffer.add_fire(op[1], op[2], int(op[3]), op[4])
			else: buffer.add(op[1], op[2], int(op[3]), op[4])
		"disc": buffer.disc(op[1], op[2], op[3], int(op[4]), op[5] if op.size() > 5 else 1.0)
		"alphaDisc": buffer.alpha_disc(op[1], op[2], op[3], int(op[4]), op[5])
		"ring": buffer.ring(op[1], op[2], op[3], op[4], int(op[5]), op[6])
		"line": buffer.line(op[1], op[2], op[3], op[4], int(op[5]))
		"glow": buffer.glow(op[1], op[2], op[3], int(op[4]), op[5], fire)
