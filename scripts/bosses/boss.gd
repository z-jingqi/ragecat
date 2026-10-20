class_name BossActor
extends EnemyActor

signal attack_player(damage: float)
signal phase_changed(phase: String)

var warning_duration: float = 0.95
var charge_distance: float = 470.0
var charge_width: float = 66.0
var charge_speed: float = 680.0
var rock_radius: float = 31.0
var rock_count: int = 5
var ability_mode: String = "alternate"
var charge_active: bool = false
var state: String = "recovery"
var phase_time: float = 0.8
var next_is_charge: bool = true
var charge_start: Vector2
var charge_end: Vector2
var charge_direction: Vector2 = Vector2.RIGHT
var charge_hit: bool = false
var rocks: Array[RockWarning] = []
var attack_damage: float = 22.0
var rock_rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _init() -> void:
	rock_rng.seed = 7319
	max_health = 1500.0
	health = max_health
	radius = 34.0
	speed = 32.0
	tint = Color('#e88b64')

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	for rock: RockWarning in rocks:
		if is_instance_valid(rock):
			rock.ai_enabled = ai_enabled
	if not ai_enabled or is_dead:
		queue_redraw()
		return
	if stun_remaining > 0.0:
		queue_redraw()
		return
	phase_time -= delta
	match state:
		"recovery":
			if phase_time <= 0.0 and is_instance_valid(target):
				if ability_mode == "charge" or (ability_mode == "alternate" and next_is_charge):
					_start_charge_warning()
				else:
					_start_rocks()
				next_is_charge = not next_is_charge
		"warning":
			if phase_time <= 0.0:
				charge_active = true
				_set_state("charge", 5.0)
		"charge":
			var previous: Vector2 = position
			position = position.move_toward(charge_end, charge_speed * delta)
			if not charge_hit and is_instance_valid(target):
				if _charge_hits_target(previous, position):
					charge_hit = true
					attack_player.emit(attack_damage)
			if position.distance_to(charge_end) < 0.5 or phase_time <= 0.0:
				charge_active = false
				_set_state("recovery", 1.15)
		"rocks":
			if phase_time <= 0.0:
				_set_state("recovery", 1.15)
	queue_redraw()

func _move_ai(_delta: float) -> void:
	# Boss movement belongs exclusively to committed abilities.
	pass

func _charge_hits_target(previous: Vector2, current: Vector2) -> bool:
	# Circle against the exact swept rectangular portion of the locked telegraph.
	# Only the player's own radius may extend a hit beyond its edges.
	var relative: Vector2 = target.position - charge_start
	var longitudinal: float = relative.dot(charge_direction)
	var lateral: float = relative.dot(charge_direction.orthogonal())
	var segment_start: float = maxf(0.0, (previous - charge_start).dot(charge_direction))
	var segment_end: float = minf(charge_start.distance_to(charge_end), (current - charge_start).dot(charge_direction))
	var closest: Vector2 = Vector2(clampf(longitudinal, segment_start, segment_end), clampf(lateral, -charge_width * 0.5, charge_width * 0.5))
	return Vector2(longitudinal, lateral).distance_squared_to(closest) <= _target_radius() * _target_radius()

func _target_radius() -> float:
	if is_instance_valid(target):
		var value: Variant = target.get("radius")
		if value != null:
			return float(value)
	return 15.0

func _start_charge_warning() -> void:
	charge_start = position
	charge_direction = position.direction_to(target.position)
	if charge_direction.length_squared() < 0.1:
		charge_direction = Vector2.RIGHT
	var allowed_distance: float = charge_distance
	var inset: Rect2 = arena_bounds.grow(-radius)
	if charge_direction.x > 0.001:
		allowed_distance = minf(allowed_distance, (inset.end.x - position.x) / charge_direction.x)
	elif charge_direction.x < -0.001:
		allowed_distance = minf(allowed_distance, (inset.position.x - position.x) / charge_direction.x)
	if charge_direction.y > 0.001:
		allowed_distance = minf(allowed_distance, (inset.end.y - position.y) / charge_direction.y)
	elif charge_direction.y < -0.001:
		allowed_distance = minf(allowed_distance, (inset.position.y - position.y) / charge_direction.y)
	charge_end = charge_start + charge_direction * maxf(0.0, allowed_distance)
	charge_hit = false
	_set_state("warning", warning_duration)

func _start_rocks() -> void:
	var snapshot: Vector2 = target.global_position
	rocks.clear()
	var centers: Array[Vector2] = []
	var random_angle: float = rock_rng.randf_range(0.0, TAU)
	var ring_spacing: float = rock_rng.randf_range(0.92, 1.10)
	var safe_bounds: Rect2 = arena_bounds.grow(-rock_radius)
	for i: int in range(rock_count):
		var center: Vector2 = snapshot
		center.x = clampf(center.x, safe_bounds.position.x, safe_bounds.end.x)
		center.y = clampf(center.y, safe_bounds.position.y, safe_bounds.end.y)
		if i > 0:
			var found: bool = false
			for ring: int in range(1, 7):
				for sample: int in range(16):
					var angle: float = float(sample) * TAU / 16.0 + random_angle
					var candidate: Vector2 = snapshot + Vector2.from_angle(angle) * rock_radius * (2.3 + float(ring)) * ring_spacing
					if not safe_bounds.has_point(candidate):
						continue
					var separated: bool = true
					for other: Vector2 in centers:
						if other.distance_to(candidate) < rock_radius * 2.65:
							separated = false
							break
					if separated:
						center = candidate
						found = true
						break
				if found:
					break
			if not found:
				continue
		centers.append(center)
		var rock := RockWarning.new()
		rock.radius = rock_radius
		rock.warning_duration = maxf(0.7, warning_duration + 0.3)
		add_child(rock)
		rock.global_position = center
		rock.impact.connect(_rock_impact)
		rocks.append(rock)
	_set_state("rocks", maxf(0.7, warning_duration + 0.3) + 0.3)

func _rock_impact(center: Vector2, impact_radius: float) -> void:
	if not is_dead and is_instance_valid(target) and target.global_position.distance_to(center) <= impact_radius + _target_radius():
		attack_player.emit(attack_damage * 0.8)

func _set_state(new_state: String, duration: float) -> void:
	state = new_state
	phase_time = duration
	phase_changed.emit(state)

func reset_state() -> void:
	for rock: RockWarning in rocks:
		if is_instance_valid(rock):
			rock.queue_free()
	rocks.clear()
	charge_active = false
	charge_hit = false
	next_is_charge = true
	_set_state("recovery", 0.8)

func _exit_tree() -> void:
	for rock: RockWarning in rocks:
		if is_instance_valid(rock):
			rock.queue_free()

func _draw() -> void:
	if state == "warning":
		var start: Vector2 = to_local(charge_start)
		var end: Vector2 = to_local(charge_end)
		var side: Vector2 = charge_direction.orthogonal() * charge_width * 0.5
		var corners := PackedVector2Array([start + side, end + side, end - side, start - side])
		draw_colored_polygon(corners, Color(1.0, 0.24, 0.17, 0.24))
		draw_polyline(PackedVector2Array([corners[0], corners[1], corners[2], corners[3], corners[0]]), Color('#ffb56f'), 2.0)
		var distance: float = charge_start.distance_to(charge_end)
		for i: int in range(1, int(distance / 45.0)):
			var middle: Vector2 = start + charge_direction * float(i) * 45.0
			draw_polyline(PackedVector2Array([middle - charge_direction * 8 + side * 0.23, middle, middle - charge_direction * 8 - side * 0.23]), Color('#ffbc80'), 2)
	draw_ellipse_shadow()
	_draw_status_rings()
	var body: Color = Color.WHITE if flash_remaining > 0.0 else tint
	var bob: float = sin(age * 4.0) * 1.5
	draw_arc(Vector2(31, 8), 17, -0.5, 3.0, 18, body.darkened(0.18), 8)
	draw_circle(Vector2(0, 4), 31, body.darkened(0.18))
	draw_circle(Vector2(-16, 25), 11, body)
	draw_circle(Vector2(16, 25), 11, body)
	draw_circle(Vector2(0, -8 + bob), 29, body)
	for side: float in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([Vector2(side * 28, -14 + bob), Vector2(side * 24, -44 + bob), Vector2(side * 7, -28 + bob)]), body)
		draw_colored_polygon(PackedVector2Array([Vector2(side * 23, -24 + bob), Vector2(side * 22, -36 + bob), Vector2(side * 13, -27 + bob)]), Color('#9f475a'))
		draw_line(Vector2(side * 5, -15 + bob), Vector2(side * 20, -20 + bob), Color('#34283b'), 5)
		draw_circle(Vector2(side * 12, -12 + bob), 5, Color('#ffe6a4'))
		draw_line(Vector2(side * 12, -16 + bob), Vector2(side * 12, -8 + bob), Color('#34283b'), 2.5)
		for whisker: int in range(2):
			draw_line(Vector2(side * 18, -1 + bob + whisker * 5), Vector2(side * 39, -5 + bob + whisker * 10), Color('#ffd0a0'), 1.5)
	draw_colored_polygon(PackedVector2Array([Vector2(-4, -3 + bob), Vector2(4, -3 + bob), Vector2(0, 1 + bob)]), Color('#6b3648'))
	draw_arc(Vector2(0, 2 + bob), 7, 0.0, PI, 10, Color('#6b3648'), 2)
	# A compact bar remains over the boss even when the screen-wide HUD is elsewhere.
	draw_rect(Rect2(-43, -57, 86, 7), Color('#1c1e32'))
	draw_rect(Rect2(-42, -56, 84 * maxf(0, health / max_health), 5), Color('#ff786b'))

func knockback(_direction: Vector2, _force: float = 26.0) -> void:
	# A committed boss telegraph must not be displaced by incidental arrows.
	pass
