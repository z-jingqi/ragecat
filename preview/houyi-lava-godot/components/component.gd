extends Node2D
## Caller-owned clock, deterministic seek, no physics, damage, timers or auto-free.
const Profile = preload("lava_profile.gd")
var profile = Profile.new()
var age := 0.0
var done := true
var enabled := true
var _started := false

func play(origin: Vector2 = Vector2.ZERO, configuration: Resource = null) -> void:
	if not origin.is_finite():
		stop()
		return
	profile = (configuration if configuration is Profile else Profile.new()).sanitized()
	position = origin
	_started = true
	_build()
	seek(0.0)

func _build() -> void:
	pass

func seek(seconds: float) -> void:
	if not _started or not is_finite(seconds): return
	age = clampf(seconds, 0.0, profile.total_time())
	done = age >= profile.total_time()
	visible = enabled and not done
	_changed()
	queue_redraw()

func _changed() -> void:
	pass

func advance(delta: float) -> void:
	if not done and is_finite(delta) and delta > 0: seek(age + delta)

func set_enabled(value: bool) -> void:
	enabled = value
	visible = enabled and _started and not done

func stop() -> void:
	_started = false
	done = true
	visible = false

func clear() -> void:
	stop()

func hashf(index: int, salt: int = 0) -> float:
	var n: int = (index * 374761393 + profile.shape_seed * 668265263 + salt * 1274126177) & 0x7fffffff
	n = ((n ^ (n >> 13)) * 1274126177) & 0x7fffffff
	return float((n ^ (n >> 16)) & 65535) / 65535.0

func site(index: int, salt: int = 0) -> Vector2:
	var angle := hashf(index, salt) * TAU
	var r: float = sqrt(hashf(index, salt + 91)) * profile.radius * 0.68
	return Vector2(cos(angle) * r, sin(angle) * r * profile.perspective).snapped(Vector2.ONE * profile.pixel_size)

func pixel(point: Vector2, color: Color, size: Vector2 = Vector2.ONE) -> void:
	var p: float = profile.pixel_size
	draw_rect(Rect2(point.snapped(Vector2.ONE * p), size * p), color)

func pixel_line(a: Vector2, b: Vector2, color: Color) -> void:
	var steps := maxi(1, int(a.distance_to(b) / profile.pixel_size))
	var visited:Dictionary={}
	for i in range(steps + 1):
		var point:=a.lerp(b,float(i)/steps).snapped(Vector2.ONE*profile.pixel_size)
		if visited.has(point): continue
		visited[point]=true
		pixel(point,color)

func raster_grid(minimum: Vector2, maximum: Vector2) -> PackedVector2Array:
	# One sample per art pixel. Never stack alpha through repeated snapped points.
	var result := PackedVector2Array()
	var p := int(profile.pixel_size)
	var start := Vector2(ceilf(minimum.x/p)*p,ceilf(minimum.y/p)*p)
	for y in range(int(start.y),int(floorf(maximum.y/p)*p)+1,p):
		for x in range(int(start.x),int(floorf(maximum.x/p)*p)+1,p): result.append(Vector2(x,y))
	return result
