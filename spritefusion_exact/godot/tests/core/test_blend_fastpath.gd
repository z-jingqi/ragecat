extends SceneTree
const Pixels = preload("res://scripts/core/sf_pixel_buffer.gd")
const JS = preload("res://scripts/core/sf_math.gd")
var checks: int = 0
var failures: Array[String] = []

# Complete original at+blend expression, independent of candidate methods.
func original_blend(px, x: float, y: float, c: int, a: float) -> void:
	var ix: int = JS.i32(x - px.ox)
	var iy: int = JS.i32(y - px.oy)
	if ix < 0 or iy < 0 or ix >= px.w or iy >= px.h: return
	var i: int = iy * px.w + ix
	var d: int = px.data[i]
	var oa: float = a + (float(d >> 24) / 255.0) * (1.0 - a)
	if oa <= 0.0: return
	var k: float = a / oa
	var j: float = 1.0 - k
	px.data[i] = JS.rgb((c & 255) * k + (d & 255) * j, ((c >> 8) & 255) * k + ((d >> 8) & 255) * j, ((c >> 16) & 255) * k + ((d >> 16) & 255) * j, oa * 255.0)

func compare(fast, scalar, x: float, y: float, c: int, a: float) -> void:
	fast.blend(x, y, c, a)
	original_blend(scalar, x, y, c, a)
	checks += 1
	if fast.data != scalar.data and failures.size() < 30:
		failures.append("origin=(%s,%s) pos=(%s,%s) color=%s alpha=%s" % [fast.ox, fast.oy, x, y, c, a])

func _initialize() -> void:
	var alphas: Array[float] = [-INF, -1.7976931348623157e308, -2.0, -1.0, -0.1, -5e-324, -0.0, 0.0, 5e-324, 1e-300, 1e-20, 0.00392156862745098, 0.01, 0.1, 0.2, 0.3, 0.49999999999999994, 0.5, 0.5000000000000001, 0.7, 0.9, 0.996078431372549, 0.9999999999999999, 1.0, 1.0000000000000002, 1.1, 2.0, 255.0, 1.7976931348623157e308, INF, NAN]
	# Decode critical binary64 boundaries explicitly, without relying on the
	# engine's long-decimal literal conversion. Preserve the original cases.
	for bits in ["0100000000000080", "0000000000000080", "0100000000000000", "ffffffffffffdf3f", "000000000000e03f", "010000000000e03f", "ffffffffffffef3f", "000000000000f03f", "010000000000f03f", "ffffffffffffef7f"]:
		alphas.append(bits.hex_decode().decode_double(0))
	var words: Array[int] = [0, 1, 0x000102ff, 0x007f80fe, 0x01000000, 0x01ffffff, 0x7fffffff, 0x80010203, 0x80ffffff, 0xfeffffff, 0xff000000, 0xffffffff, 0x100000000, 0x123456789abcdef, -1, -2147483648, -9223372036854775807]
	var fast = Pixels.new(1,1)
	var scalar = Pixels.new(1,1)
	for a in alphas:
		for old in words:
			for color in words:
				fast.data[0] = old
				scalar.data[0] = old
				compare(fast, scalar, 0.0, 0.0, color, a)
	var random = RandomNumberGenerator.new()
	random.seed = 0x4e21b6a3
	var coordinates: Array[float] = [-INF, -1.7976931348623157e308, -4294967296.5, -4294967296.0, -2147483648.0, -1.0, -0.9999999999999999, -0.5, -5e-324, -0.0, 0.0, 5e-324, 0.5, 0.9999999999999999, 1.0, 12.99999, 13.0, 16.99999, 17.0, 2147483647.9999998, 2147483648.0, 4294967296.0, 4294967296.5, 1.7976931348623157e308, INF, NAN]
	for origin in [[0.0,0.0], [-4.0,3.0], [0.5,-0.75], [-0.5,1.25], [4294967296.0,-4294967296.0], [INF,-INF], [NAN,NAN]]:
		fast = Pixels.new(17,13,origin[0],origin[1])
		scalar = Pixels.new(17,13,origin[0],origin[1])
		for i in range(fast.data.size()):
			fast.data[i] = random.randi()
			scalar.data[i] = fast.data[i]
		for x in coordinates:
			for y in coordinates:
				for a in [0.0, 5e-324, 0.3, 1.0, -0.1, 1.1, INF, NAN]:
					compare(fast,scalar,x,y,random.randi(),a)
	# Ordered, overlapping writes from mixed seeded buffers; reset regularly so
	# nonfinite and saturation cases cannot erase coverage of ordinary mixing.
	var bytes = PackedByteArray()
	bytes.resize(8)
	fast = Pixels.new(17,13,-0.5,0.75)
	scalar = Pixels.new(17,13,-0.5,0.75)
	for n in range(20000):
		if n % 200 == 0:
			for i in range(fast.data.size()):
				fast.data[i] = random.randi()
				scalar.data[i] = fast.data[i]
		bytes.encode_u32(0,random.randi())
		bytes.encode_u32(4,random.randi())
		var a: float = bytes.decode_double(0) if n % 3 == 0 else random.randf_range(-0.1,1.1)
		var color: int = (int(random.randi()) << 32) | int(random.randi())
		compare(fast,scalar,random.randf_range(-2.0,18.0),random.randf_range(-1.0,15.0),color,a)
	if failures.is_empty():
		print("BLEND FASTPATH PASS: %s complete-buffer comparisons" % checks)
		quit(0)
	else:
		for failure in failures: printerr(failure)
		quit(1)
