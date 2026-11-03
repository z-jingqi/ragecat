# The shared Sprite Fusion Px rasterizer, including fire's optional-alpha disc.
# ABGR words stay integer-packed until the explicit RGBA byte conversion.
extends RefCounted
const JS = preload("res://scripts/core/sf_math.gd")
# Validate native byte order and signed narrowing once before enabling bulk packing.
static var _bulk_rgba_supported: bool = _supports_bulk_rgba()

static func _supports_bulk_rgba() -> bool:
	var words = PackedInt64Array([0x04030201, 0x80706050, 0xffffffff, 0x80000000])
	var expected = PackedByteArray([1, 2, 3, 4, 80, 96, 112, 128, 255, 255, 255, 255, 0, 0, 0, 128])
	return PackedInt32Array(Array(words)).to_byte_array() == expected

var w: int
var h: int
var ox: float
var oy: float
var data: PackedInt64Array = PackedInt64Array()

func _init(width: int, height: int, origin_x: float = 0.0, origin_y: float = 0.0) -> void:
	assert(width > 0 and height > 0)
	w = width
	h = height
	ox = origin_x
	oy = origin_y
	data.resize(w * h)
	data.fill(0)

func clear(c: int = 0) -> void:
	data.fill(JS.u32(c))

func at(x: float, y: float) -> int:
	var px: int = JS.i32(x - ox)
	var py: int = JS.i32(y - oy)
	return -1 if px < 0 or py < 0 or px >= w or py >= h else py * w + px

func put(x: float, y: float, c: int) -> void:
	var i: int = at(x, y)
	if i >= 0:
		data[i] = JS.u32(c)

func blend(x: float, y: float, c: int, a: float) -> void:
	var i: int = at(x, y)
	if i < 0:
		return
	var d: int = data[i]
	var oa: float = a + (float(d >> 24) / 255.0) * (1.0 - a)
	if oa <= 0.0:
		return
	var k: float = a / oa
	var j: float = 1.0 - k
	data[i] = JS.rgb((c & 255) * k + (d & 255) * j, ((c >> 8) & 255) * k + ((d >> 8) & 255) * j, ((c >> 16) & 255) * k + ((d >> 16) & 255) * j, oa * 255.0)

func add(x: float, y: float, c: int, k: float) -> void:
	var i: int = at(x, y)
	if i < 0:
		return
	_add_at(i, c, k)

func add_fire(x: float, y: float, c: int, k: float) -> void:
	# Original fire's add uses an unchecked typed-array index, not Px.at.
	# Fractional/out-of-range canonical numeric indices silently discard writes.
	var index: float = (y - oy) * w + (x - ox)
	if not is_finite(index) or index != floor(index) or index < 0.0 or index >= data.size():
		return
	_add_at(int(index), c, k)

func _add_at(i: int, c: int, k: float) -> void:
	var d: int = data[i]
	data[i] = JS.rgb(minf(255.0, (d & 255) + (c & 255) * k), minf(255.0, ((d >> 8) & 255) + ((c >> 8) & 255) * k), minf(255.0, ((d >> 16) & 255) + ((c >> 16) & 255) * k))

func disc(cx: float, cy: float, radius: float, c: int, a: float = 1.0) -> void:
	if a <= 0.01:
		return
	if radius <= 0.5 and a >= 1.0:
		put(JS.js_round(cx), JS.js_round(cy), c)
		return
	var r2: float = radius * radius
	for y in range(int(floor(cy - radius)), int(ceil(cy + radius)) + 1):
		var dy: float = y + 0.5 - cy
		for x in range(int(floor(cx - radius)), int(ceil(cx + radius)) + 1):
			var dx: float = x + 0.5 - cx
			if dx * dx + dy * dy <= r2:
				if a >= 1.0:
					put(x, y, c)
				else:
					blend(x, y, c, a)

func alpha_disc(cx: float, cy: float, radius: float, c: int, a: float) -> void:
	if a <= 0.01:
		return
	var r2: float = radius * radius
	for y in range(int(floor(cy - radius)), int(ceil(cy + radius)) + 1):
		var dy: float = y + 0.5 - cy
		for x in range(int(floor(cx - radius)), int(ceil(cx + radius)) + 1):
			var dx: float = x + 0.5 - cx
			if dx * dx + dy * dy <= r2:
				blend(x, y, c, a)

func ring(cx: float, cy: float, radius: float, thick: float, c: int, alpha: float = 1.0) -> void:
	var ro: float = radius + thick * 0.5
	var ri: float = maxf(0.0, radius - thick * 0.5)
	var ro2: float = ro * ro
	var ri2: float = ri * ri
	for y in range(int(floor(cy - ro)), int(ceil(cy + ro)) + 1):
		var dy: float = y + 0.5 - cy
		for x in range(int(floor(cx - ro)), int(ceil(cx + ro)) + 1):
			var dx: float = x + 0.5 - cx
			var d2: float = dx * dx + dy * dy
			if d2 <= ro2 and d2 >= ri2 and (alpha >= 1.0 or alpha > JS.bayer(x, y)):
				put(x, y, c)

func line(from_x: float, from_y: float, to_x: float, to_y: float, c: int) -> void:
	var x0: int = JS.js_round(from_x)
	var y0: int = JS.js_round(from_y)
	var x1: int = JS.js_round(to_x)
	var y1: int = JS.js_round(to_y)
	var dx: int = absi(x1 - x0)
	var dy: int = -absi(y1 - y0)
	var sx: int = 1 if x0 < x1 else -1
	var sy: int = 1 if y0 < y1 else -1
	var err: int = dx + dy
	for _n in range(4096):
		put(x0, y0, c)
		if x0 == x1 and y0 == y1:
			break
		var e2: int = 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy

func glow(cx: float, cy: float, radius: float, c: int, k: float, fire_indexing: bool = false) -> void:
	# The integer-camera fast path removes repeated coordinate coercion and
	# function dispatch only. Fractional cameras and fire retain source indexing.
	# Keep the global JavaScript numeric helpers and every float operation intact.
	if not fire_indexing and is_finite(cx) and is_finite(cy) and is_finite(radius) and is_finite(k) and _integer_glow_camera():
		_glow_integer(cx, cy, radius, c, k)
	else:
		_glow_scalar(cx, cy, radius, c, k, fire_indexing)

func _integer_glow_camera() -> bool:
	# A conservative bound makes x/y += 1 exact and every clipped offset safely
	# representable by source ToInt32. Do not narrow unusual inputs silently.
	return is_finite(ox) and is_finite(oy) and ox == floor(ox) and oy == floor(oy) and absf(ox) <= 2147483647.0 and absf(oy) <= 2147483647.0 and absf(ox + w - 1) <= 2147483647.0 and absf(oy + h - 1) <= 2147483647.0 and w <= 2147483647 and h <= 2147483647

func _glow_integer(cx: float, cy: float, radius: float, c: int, k: float) -> void:
	if radius < 1.0 or k <= 0.01:
		return
	var x0: float = maxf(ox, floor(cx - radius))
	var x1: float = minf(ox + w - 1, ceil(cx + radius))
	var y0: float = maxf(oy, floor(cy - radius))
	var y1: float = minf(oy + h - 1, ceil(cy + radius))
	if x0 > x1 or y0 > y1:
		return
	var red: int = c & 255
	var green: int = (c >> 8) & 255
	var blue: int = (c >> 16) & 255
	var y: float = y0
	while y <= y1:
		var dy: float = (y + 0.5 - cy) / radius
		var x: float = x0
		var index: int = int(y - oy) * w + int(x0 - ox)
		while x <= x1:
			var dx: float = (x + 0.5 - cx) / radius
			var d: float = dx * dx + dy * dy
			if d < 1.0:
				var f: float = 1.0 - sqrt(d)
				var strength: float = f * f * k
				var old: int = data[index]
				# Finite positive k and 0 <= f <= 1 bound all channels to
				# [0,255]. Here int truncation is exactly source ToUint32.
				data[index] = 0xff000000 | int(minf(255.0, (old & 255) + red * strength)) | (int(minf(255.0, ((old >> 8) & 255) + green * strength)) << 8) | (int(minf(255.0, ((old >> 16) & 255) + blue * strength)) << 16)
			x += 1.0
			index += 1
		y += 1.0

func _glow_scalar(cx: float, cy: float, radius: float, c: int, k: float, fire_indexing: bool = false) -> void:
	if radius < 1.0 or k <= 0.01:
		return
	var x0: float = maxf(ox, floor(cx - radius))
	var x1: float = minf(ox + w - 1, ceil(cx + radius))
	var y0: float = maxf(oy, floor(cy - radius))
	var y1: float = minf(oy + h - 1, ceil(cy + radius))
	# Use float iteration: original camera origins need not be integer.
	var y: float = y0
	while y <= y1:
		var dy: float = (y + 0.5 - cy) / radius
		var x: float = x0
		while x <= x1:
			var dx: float = (x + 0.5 - cx) / radius
			var d: float = dx * dx + dy * dy
			if d < 1.0:
				var f: float = 1.0 - sqrt(d)
				if fire_indexing:
					add_fire(x, y, c, f * f * k)
				else:
					add(x, y, c, f * f * k)
			x += 1.0
		y += 1.0

func rgba_bytes() -> PackedByteArray:
	if _bulk_rgba_supported:
		return PackedInt32Array(Array(data)).to_byte_array()
	return _rgba_bytes_scalar()

func _rgba_bytes_scalar() -> PackedByteArray:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(data.size() * 4)
	for i in range(data.size()):
		var c: int = data[i]
		bytes[i * 4] = c & 255
		bytes[i * 4 + 1] = (c >> 8) & 255
		bytes[i * 4 + 2] = (c >> 16) & 255
		bytes[i * 4 + 3] = (c >> 24) & 255
	return bytes

func to_image() -> Image:
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, rgba_bytes())
