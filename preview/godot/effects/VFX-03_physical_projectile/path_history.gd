extends RefCounted
## Independent point-path trail. No energy-bolt or swept-weapon dependency.
const CAP := 128
const SPACING := 0.65
const TELEPORT_DISTANCE := 96.0
var body_kind := 0
var body_scale := 1.0
var trail_width := 2.4
var length_min := 8.0
var length_max := 34.0
var speed_reference := 260.0
var speed_response := 0.05
var history_seconds := 0.20
var taper := 0.75
var lifetime := 1.6
var trail_color := Color("9aafb7")
var trail_edge := Color("546b79")
var metal_light := Color("e1ece9")
var metal_dark := Color("849ca6")
var wood_color := Color("b98c57")
var world_position := Vector2.ZERO
var velocity := Vector2.ZERO
var facing := Vector2.RIGHT
var points: Array[Vector2] = []
var times: Array[float] = []
var clock := 0.0
var age := 0.0
var trail_length := 0.0
var emitting := false
var active := false
var paused := false
var teleport_count := 0

func number(values: Dictionary, key: String, fallback: float) -> float:
	var n := float(values.get(key, fallback))
	return n if is_finite(n) else fallback
func configure(v: Dictionary) -> void:
	var old_kind := body_kind
	var old_scale := body_scale
	body_kind = clampi(int(number(v, "body_kind", body_kind)), 0, 1)
	body_scale = clampf(number(v, "body_scale", body_scale), 0.5, 2.0)
	trail_width = clampf(number(v, "trail_width", trail_width), 0.5, 6.0)
	length_min = clampf(number(v, "length_min", length_min), 0.0, 40.0)
	length_max = clampf(number(v, "length_max", length_max), length_min, 64.0)
	speed_reference = clampf(number(v, "speed_reference", speed_reference), 30.0, 600.0)
	speed_response = clampf(number(v, "speed_response", speed_response), 0.01, 0.3)
	history_seconds = clampf(number(v, "history_seconds", history_seconds), 0.02, 0.6)
	taper = clampf(number(v, "taper", taper), 0.25, 3.0)
	lifetime = clampf(number(v, "lifetime", lifetime), 0.1, 10.0)
	for key in ["trail_color", "trail_edge", "metal_light", "metal_dark", "wood_color"]:
		if v.has(key): set(key, Color(v[key]))
	trail_length = clampf(trail_length, 0.0, length_max)
	# A changed physical attachment must not connect to the old body's rear.
	if old_kind != body_kind or old_scale != body_scale:
		clear_history()
func rear() -> Vector2:
	return world_position - facing * (20.0 if body_kind == 0 else 18.0) * body_scale
func clear_history() -> void:
	points.clear()
	times.clear()
	trail_length = 0.0
func reset(p: Vector2, v: Vector2) -> void:
	world_position = p if p.is_finite() else Vector2.ZERO
	velocity = v if v.is_finite() else Vector2.ZERO
	facing = velocity.normalized() if velocity.length_squared() > 0.0001 else Vector2.RIGHT
	clear_history()
	clock = 0.0
	age = 0.0
	emitting = true
	active = true
	paused = false
	teleport_count = 0
	points.append(rear())
	times.append(clock)
func stop(immediate: bool = false) -> void:
	emitting = false
	velocity = Vector2.ZERO
	if immediate:
		clear_history()
		active = false
func tick(dt: float, p: Vector2, v: Vector2) -> void:
	if paused or not active or dt <= 0.0 or not is_finite(dt) or not p.is_finite() or not v.is_finite(): return
	var previous_age := age
	clock += dt
	age += dt
	if emitting:
		var sample_dt := minf(dt, maxf(0.0,lifetime-previous_age))
		var sample_time := clock-(dt-sample_dt)
		var teleported := world_position.distance_to(p) > TELEPORT_DISTANCE
		var final_pose := p if teleported else world_position.lerp(p,sample_dt/dt)
		world_position = final_pose
		velocity = v
		if v.length_squared() > 0.0001: facing = v.normalized()
		if teleported:
			clear_history()
			teleport_count += 1
		var anchor := rear()
		if points.is_empty() or points[0].distance_to(anchor) >= SPACING:
			points.push_front(anchor)
			times.push_front(sample_time)
		var speed := v.length()
		var target := lerpf(length_min, length_max, clampf(speed / speed_reference, 0.0, 1.0)) if speed > 0.01 else 0.0
		trail_length = lerpf(trail_length, target, 1.0 - exp(-sample_dt / speed_response))
		if age >= lifetime: stop()
	trim()
	active = emitting or not points.is_empty()
	if not active: trail_length=0.0
func trim() -> void:
	while not times.is_empty() and clock - times[-1] >= history_seconds:
		times.pop_back()
		points.pop_back()
	var distance := 0.0
	var previous := rear() if emitting else (points[0] if not points.is_empty() else world_position)
	var keep := points.size()
	for i in range(points.size()):
		distance += previous.distance_to(points[i])
		previous = points[i]
		if distance > length_max + 2.0:
			keep = i + 1
			break
	points.resize(mini(keep, CAP))
	times.resize(points.size())
func render_points() -> PackedVector4Array:
	var out := PackedVector4Array()
	if points.is_empty(): return out
	var first := rear() if emitting else points[0]
	var first_time := clock if emitting else times[0]
	var local := first - world_position
	out.append(Vector4(local.x, local.y, 0.0, clampf(1.0-(clock-first_time)/history_seconds, 0.0, 1.0)))
	var previous := first
	var previous_time := first_time
	var distance := 0.0
	for i in range(points.size()):
		var segment := previous.distance_to(points[i])
		if segment < 0.001: continue
		var end_distance := minf(trail_length, distance + segment)
		var t := (end_distance-distance)/segment
		var end := previous.lerp(points[i], t)
		var stamp := lerpf(previous_time, times[i], t)
		local = end-world_position
		out.append(Vector4(local.x, local.y, end_distance, clampf(1.0-(clock-stamp)/history_seconds, 0.0, 1.0)))
		distance = end_distance
		previous = points[i]
		previous_time = times[i]
		if distance >= trail_length or out.size() >= CAP: break
	return out
