extends RefCounted
## Original CPU raster helpers. The returned Image is also the actual runtime texture.
var image: Image
var anchor: Vector2

func _init(size: Vector2i, origin: Vector2) -> void:
	image = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	anchor = origin

func pixel(point: Vector2, color: Color, alpha: float = 1.0) -> void:
	var p: Vector2i = Vector2i((point + anchor).round())
	if p.x < 0 or p.y < 0 or p.x >= image.get_width() or p.y >= image.get_height() or alpha <= 0.0: return
	var src := Color(color, clampf(alpha, 0.0, 1.0))
	image.set_pixelv(p, image.get_pixelv(p).blend(src))

func line(a: Vector2, b: Vector2, color: Color, alpha: float = 1.0) -> void:
	var from := Vector2i(a.round())
	var to := Vector2i(b.round())
	var dx := absi(to.x - from.x)
	var dy := -absi(to.y - from.y)
	var sx := 1 if from.x < to.x else -1
	var sy := 1 if from.y < to.y else -1
	var error := dx + dy
	for _i in range(512):
		pixel(Vector2(from), color, alpha)
		if from == to: break
		var e2 := error * 2
		if e2 >= dy: error += dy; from.x += sx
		if e2 <= dx: error += dx; from.y += sy

func point_on_ground(angle: float, radius: float, perspective: float) -> Vector2:
	return Vector2(cos(angle) * radius, sin(angle) * radius * perspective)

func arc(radius: float, squash: float, start: float, end: float, color: Color, alpha: float, jag: float = 0.0) -> void:
	var steps := maxi(2, int((end - start) * radius * 1.3))
	var last := point_on_ground(start, radius, squash)
	for i in range(1, steps + 1):
		var angle := lerpf(start, end, float(i) / steps)
		var r := radius + sin(angle * 17.0) * jag
		var next := point_on_ground(angle, r, squash)
		line(last, next, color, alpha)
		last = next

static func noise(index: int, seed_value: int) -> float:
	var n: int = (index * 1664525 + seed_value * 1013904223 + 374761393) & 0x7fffffff
	n = ((n ^ (n >> 13)) * 1274126177) & 0x7fffffff
	return float((n ^ (n >> 16)) & 65535) / 65535.0
