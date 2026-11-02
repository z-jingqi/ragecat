extends RefCounted
## Visual state only. Game-supplied poses remain continuous; no damage or homing.
const HISTORY_CAP := 96
const SAMPLE_SPACING := 0.75
const TELEPORT_DISTANCE := 96.0
const EXIT_SECONDS := 0.09
var head_radius := 4.5
var tail_min := 9.0
var tail_max := 27.0
var speed_reference := 240.0
var speed_response := 0.055
var flow_strength := 0.8
var lifetime := 1.6
var core_color := Color("ecfff4")
var body_color := Color("7ae7c5")
var edge_color := Color("238b90")
var world_position := Vector2.ZERO
var velocity := Vector2.ZERO
var facing := Vector2.RIGHT
var history: Array[Vector2] = []
var age := 0.0
var flow_time := 0.0
var exit_age := 0.0
var tail_length := 0.0
var active := false
var exiting := false
var paused := false
var teleport_count := 0

func number(values: Dictionary, key: String, fallback: float) -> float:
	var value := float(values.get(key, fallback))
	return value if is_finite(value) else fallback

func configure(values: Dictionary) -> void:
	head_radius = clampf(number(values, "head_radius", head_radius), 2.0, 8.0)
	tail_min = clampf(number(values, "tail_min", tail_min), 0.0, 30.0)
	tail_max = clampf(number(values, "tail_max", tail_max), tail_min, 42.0)
	speed_reference = clampf(number(values, "speed_reference", speed_reference), 30.0, 600.0)
	speed_response = clampf(number(values, "speed_response", speed_response), 0.01, 0.3)
	flow_strength = clampf(number(values, "flow_strength", flow_strength), 0.0, 1.0)
	lifetime = clampf(number(values, "lifetime", lifetime), 0.1, 10.0)
	core_color = Color(values.get("core_color", core_color.to_html()))
	body_color = Color(values.get("body_color", body_color.to_html()))
	edge_color = Color(values.get("edge_color", edge_color.to_html()))
	tail_length = clampf(tail_length, 0.0, tail_max)

func reset(start: Vector2, initial_velocity: Vector2) -> void:
	world_position = start if start.is_finite() else Vector2.ZERO
	velocity = initial_velocity if initial_velocity.is_finite() else Vector2.ZERO
	facing = velocity.normalized() if velocity.length_squared() > 0.0001 else Vector2.RIGHT
	history.clear()
	history.append(world_position)
	age = 0.0
	flow_time = 0.0
	exit_age = 0.0
	tail_length = 0.0
	active = true
	exiting = false
	paused = false
	teleport_count = 0

func stop(immediate: bool = false) -> void:
	velocity = Vector2.ZERO
	if immediate:
		active = false
		exiting = false
		history.clear()
		tail_length = 0.0
	elif active and not exiting:
		exiting = true
		exit_age = 0.0

func tick(delta: float, new_position: Vector2, new_velocity: Vector2) -> void:
	if paused or not active or delta <= 0.0 or not is_finite(delta):
		return
	if not new_position.is_finite() or not new_velocity.is_finite():
		return
	var remaining := minf(delta, maxf(0.0, lifetime - age)) if not exiting else 0.0
	age += delta
	flow_time += delta
	if not exiting:
		var jump := world_position.distance_to(new_position)
		if jump > TELEPORT_DISTANCE:
			history.clear()
			history.append(new_position)
			tail_length = 0.0
			teleport_count += 1
		elif history.is_empty() or history[0].distance_to(new_position) >= SAMPLE_SPACING:
			history.push_front(new_position)
		world_position = new_position
		velocity = new_velocity
		if velocity.length_squared() > 0.0001:
			facing = velocity.normalized()
		var target := lerpf(tail_min, tail_max, clampf(velocity.length() / speed_reference, 0.0, 1.0))
		if velocity.length() < 0.01:
			target = 0.0
		tail_length = lerpf(tail_length, target, 1.0 - exp(-delta / speed_response))
		trim_history()
		if age >= lifetime:
			stop()
			exit_age = maxf(0.0, delta - remaining)
	else:
		exit_age += delta
	if exiting and exit_age >= EXIT_SECONDS:
		stop(true)

func trim_history() -> void:
	var distance := 0.0
	var previous := world_position
	var keep := history.size()
	for i in range(history.size()):
		distance += previous.distance_to(history[i])
		previous = history[i]
		if distance > tail_max + 2.0:
			keep = i + 1
			break
	history.resize(mini(keep, HISTORY_CAP))

func envelope() -> float:
	if not active:
		return 0.0
	var entrance := minf(1.0, age / 0.025)
	return entrance * (maxf(0.0, 1.0 - exit_age / EXIT_SECONDS) if exiting else 1.0)

func path_points() -> PackedVector4Array:
	# Clip actual sampled history by arc distance; never invent an old path.
	var points := PackedVector4Array()
	var desired := tail_length * envelope()
	var distance := 0.0
	var previous := world_position
	points.append(Vector4(0.0, 0.0, 0.0, 0.0))
	for p in history:
		var segment := previous.distance_to(p)
		if segment < 0.001:
			continue
		var next_distance := minf(desired, distance + segment)
		var endpoint := previous.lerp(p, (next_distance - distance) / segment)
		var local := endpoint - world_position
		points.append(Vector4(local.x, local.y, next_distance, 0.0))
		distance = next_distance
		previous = p
		if distance >= desired or points.size() >= HISTORY_CAP:
			break
	return points
