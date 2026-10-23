class_name BossActor
extends EnemyActor

signal attack_player(damage: float)
signal phase_changed(phase: String)

# Subclass defaults initialize the inherited exported fields. They are not reapplied
# on _ready, so scene, arena and practice overrides remain authoritative.
const BOSS_DEFAULT_MAX_HEALTH: float = 1500.0
const BOSS_DEFAULT_RADIUS: float = 34.0
const BOSS_DEFAULT_SPEED: float = 32.0
const BOSS_DEFAULT_TINT: Color = Color('#e88b64')
# Numerical tolerances and hard work limits are safeguards, not balance settings.
const DIRECTION_LENGTH_SQUARED_EPSILON: float = 0.1
const MIN_ROCK_RADIUS: float = 0.01
const MAX_ROCK_COUNT: int = 128
const MAX_ROCK_SEARCH_RINGS: int = 64
const MAX_ROCK_ANGULAR_SAMPLES: int = 256
const MAX_ROCK_PLACEMENT_CANDIDATES: int = 8192
const MAX_LIVE_ROCK_WARNINGS: int = 256

@export_group("Boss Abilities")
@export_enum("alternate", "charge", "rocks") var ability_mode: String = "alternate":
	set(value):
		ability_mode = value if value in ["alternate", "charge", "rocks"] else "alternate"
@export var start_with_charge: bool = true:
	set(value):
		start_with_charge = value
		if not is_node_ready():
			next_is_charge = value
@export_range(0.0, 1000.0, 0.5, "or_greater") var attack_damage: float = 22.0:
	set(value):
		attack_damage = _boss_nonnegative(value)
@export_range(0.0, 100.0, 0.5, "or_greater") var fallback_target_radius: float = 15.0:
	set(value):
		fallback_target_radius = _boss_nonnegative(value)

@export_group("Boss Timing")
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var initial_recovery_duration: float = 0.8:
	set(value):
		initial_recovery_duration = _boss_nonnegative(value)
		if not is_node_ready() and state == "recovery":
			phase_time = initial_recovery_duration
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var recovery_duration: float = 1.15:
	set(value):
		recovery_duration = _boss_nonnegative(value)
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var warning_duration: float = 0.95:
	set(value):
		warning_duration = _boss_nonnegative(value)
@export_range(0.0, 20.0, 0.01, "or_greater", "suffix:s") var charge_timeout: float = 5.0:
	set(value):
		charge_timeout = _boss_nonnegative(value)

@export_group("Boss Charge")
@export_range(0.0, 2000.0, 1.0, "or_greater") var charge_distance: float = 940.0:
	set(value):
		charge_distance = _boss_nonnegative(value)
@export_range(0.0, 300.0, 1.0, "or_greater") var charge_width: float = 66.0:
	set(value):
		charge_width = _boss_nonnegative(value)
@export_range(0.0, 2000.0, 1.0, "or_greater") var charge_speed: float = 680.0:
	set(value):
		charge_speed = _boss_nonnegative(value)
@export_range(0.0, 10.0, 0.01, "or_greater") var charge_stop_tolerance: float = 0.5:
	set(value):
		charge_stop_tolerance = _boss_nonnegative(value)

@export_group("Boss Rocks")
@export_range(0.01, 200.0, 0.5, "or_greater") var rock_radius: float = 31.0:
	set(value):
		rock_radius = maxf(MIN_ROCK_RADIUS, _boss_nonnegative(value))
@export_range(0, 128, 1) var rock_count: int = 5:
	set(value):
		rock_count = clampi(value, 0, MAX_ROCK_COUNT)
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var rock_min_warning_duration: float = 0.7:
	set(value):
		rock_min_warning_duration = _boss_nonnegative(value)
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var rock_warning_offset: float = 0.3:
	set(value):
		rock_warning_offset = _boss_nonnegative(value)
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var rock_recovery_delay: float = 0.3:
	set(value):
		rock_recovery_delay = _boss_nonnegative(value)
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var rock_aftermath_duration: float = 0.28:
	set(value):
		rock_aftermath_duration = _boss_nonnegative(value)
@export_range(0.0, 5.0, 0.01, "or_greater") var rock_damage_multiplier: float = 0.8:
	set(value):
		rock_damage_multiplier = _boss_nonnegative(value)

@export_group("Boss Rock Pattern")
@export var rock_pattern_seed: int = 7319:
	set(value):
		rock_pattern_seed = value
		if rock_rng != null:
			rock_rng.seed = value
@export_range(0.0, 10.0, 0.01, "or_greater") var rock_ring_offset: float = 2.3:
	set(value):
		rock_ring_offset = _boss_nonnegative(value)
@export_range(0.0, 10.0, 0.01, "or_greater") var rock_min_separation: float = 2.65:
	set(value):
		rock_min_separation = _boss_nonnegative(value)
@export_range(0.0, 5.0, 0.01, "or_greater") var rock_spacing_random_min: float = 0.92:
	set(value):
		rock_spacing_random_min = _boss_nonnegative(value)
@export_range(0.0, 5.0, 0.01, "or_greater") var rock_spacing_random_max: float = 1.10:
	set(value):
		rock_spacing_random_max = _boss_nonnegative(value)
@export_range(1, 64, 1) var rock_search_rings: int = 6:
	set(value):
		rock_search_rings = clampi(value, 1, MAX_ROCK_SEARCH_RINGS)
@export_range(1, 256, 1) var rock_angular_samples: int = 16:
	set(value):
		rock_angular_samples = clampi(value, 1, MAX_ROCK_ANGULAR_SAMPLES)

var charge_active: bool = false
var state: String = "recovery"
var phase_time: float = initial_recovery_duration
var next_is_charge: bool = start_with_charge
var charge_start: Vector2
var charge_end: Vector2
var charge_direction: Vector2 = Vector2.RIGHT
var charge_hit: bool = false
var rocks: Array[RockWarning] = []
var rock_rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _init() -> void:
	rock_rng.seed = rock_pattern_seed
	mass = 10.0
	max_health = BOSS_DEFAULT_MAX_HEALTH
	health = max_health
	radius = BOSS_DEFAULT_RADIUS
	speed = BOSS_DEFAULT_SPEED
	tint = BOSS_DEFAULT_TINT

static func _boss_nonnegative(value: float) -> float:
	return maxf(0.0, value) if is_finite(value) else 0.0

func _ability_safe_bounds(inset: float) -> Rect2:
	# An oversized radius must not invert the arena rectangle or its clamp limits.
	var bounds: Rect2 = arena_bounds.abs()
	var safe_inset: float = minf(_boss_nonnegative(inset), minf(bounds.size.x, bounds.size.y) * 0.5)
	return bounds.grow(-safe_inset)

func _physics_process(delta: float) -> void:
	if not is_finite(delta) or delta < 0.0: return
	super._physics_process(delta)
	_prune_rock_warnings()
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
				_set_state("charge", charge_timeout)
		"charge":
			var previous: Vector2 = position
			position = position.move_toward(charge_end, charge_speed * delta)
			if not charge_hit and is_instance_valid(target):
				if _charge_hits_target(previous, position):
					charge_hit = true
					attack_player.emit(attack_damage)
			if position == charge_end or position.distance_to(charge_end) < charge_stop_tolerance or phase_time <= 0.0:
				charge_active = false
				_set_state("recovery", recovery_duration)
		"rocks":
			if phase_time <= 0.0:
				_set_state("recovery", recovery_duration)
	queue_redraw()

func hit_movement_eligible() -> bool:
	# Boss attack commitments and all phase clocks are never retimed by hits.
	return false

func gravity_eligible() -> bool:
	return super.gravity_eligible() and state not in ["warning", "charge"]

func contact_damage_suppressed() -> bool:
	# Committed charge attacks always override any remaining release grace.
	if state in ["warning", "charge"]: return false
	return super.contact_damage_suppressed()

func _move_ai(_delta: float) -> void:
	# Boss movement belongs exclusively to committed abilities. Ice chill is
	# recorded for feedback, but never scales charge speed, distance or timing.
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
			return _boss_nonnegative(float(value))
	return fallback_target_radius

func _start_charge_warning() -> void:
	if not is_instance_valid(target):
		return
	charge_start = position
	charge_direction = position.direction_to(target.position)
	if charge_direction.length_squared() < DIRECTION_LENGTH_SQUARED_EPSILON:
		charge_direction = Vector2.RIGHT
	# Distance is authored, never derived from target range. Clip the locked ray,
	# not its endpoint coordinates, so a diagonal charge cannot slide along walls.
	var allowed_distance: float = charge_distance
	var inset: Rect2 = _ability_safe_bounds(radius)
	if charge_direction.x > 0.0:
		allowed_distance = minf(allowed_distance, (inset.end.x - position.x) / charge_direction.x)
	elif charge_direction.x < 0.0:
		allowed_distance = minf(allowed_distance, (inset.position.x - position.x) / charge_direction.x)
	if charge_direction.y > 0.0:
		allowed_distance = minf(allowed_distance, (inset.end.y - position.y) / charge_direction.y)
	elif charge_direction.y < 0.0:
		allowed_distance = minf(allowed_distance, (inset.position.y - position.y) / charge_direction.y)
	charge_end = charge_start + charge_direction * maxf(0.0, allowed_distance)
	charge_hit = false
	_set_state("warning", warning_duration)

func _start_rocks() -> void:
	if not is_instance_valid(target):
		return
	var snapshot: Vector2 = target.global_position
	# Long configured aftermath can overlap the next attack. Keep those warnings
	# tracked so pause/reset still covers every live child.
	_prune_rock_warnings()
	var centers: Array[Vector2] = []
	var random_angle: float = rock_rng.randf_range(0.0, TAU)
	var ring_spacing: float = rock_rng.randf_range(minf(rock_spacing_random_min, rock_spacing_random_max), maxf(rock_spacing_random_min, rock_spacing_random_max))
	var safe_bounds: Rect2 = _ability_safe_bounds(rock_radius)
	var rock_warning_time: float = maxf(rock_min_warning_duration, warning_duration + rock_warning_offset)
	var candidates_checked: int = 0
	for i: int in range(rock_count):
		var center: Vector2 = snapshot
		center.x = clampf(center.x, safe_bounds.position.x, safe_bounds.end.x)
		center.y = clampf(center.y, safe_bounds.position.y, safe_bounds.end.y)
		if i > 0:
			var found: bool = false
			for ring: int in range(1, rock_search_rings + 1):
				for sample: int in range(rock_angular_samples):
					if candidates_checked >= MAX_ROCK_PLACEMENT_CANDIDATES:
						break
					candidates_checked += 1
					var angle: float = float(sample) * TAU / float(rock_angular_samples) + random_angle
					var candidate: Vector2 = snapshot + Vector2.from_angle(angle) * rock_radius * (rock_ring_offset + float(ring)) * ring_spacing
					if not safe_bounds.has_point(candidate):
						continue
					var separated: bool = true
					for other: Vector2 in centers:
						if other.distance_to(candidate) < rock_radius * rock_min_separation:
							separated = false
							break
					if separated:
						center = candidate
						found = true
						break
				if found or candidates_checked >= MAX_ROCK_PLACEMENT_CANDIDATES:
					break
			if not found:
				break
		centers.append(center)
		var rock := RockWarning.new()
		rock.radius = rock_radius
		rock.warning_duration = rock_warning_time
		rock.aftermath_duration = rock_aftermath_duration
		add_child(rock)
		rock.global_position = center
		rock.impact.connect(_rock_impact)
		rocks.append(rock)
		# Zero recovery with long aftermath must not accumulate unbounded nodes.
		if rocks.size() > MAX_LIVE_ROCK_WARNINGS:
			var oldest: RockWarning = rocks.pop_front()
			oldest.queue_free()
	_set_state("rocks", rock_warning_time + rock_recovery_delay)

func _prune_rock_warnings() -> void:
	for index: int in range(rocks.size() - 1, -1, -1):
		if not is_instance_valid(rocks[index]) or rocks[index].is_queued_for_deletion():
			rocks.remove_at(index)

func _rock_impact(center: Vector2, impact_radius: float) -> void:
	if not is_dead and is_instance_valid(target) and target.global_position.distance_to(center) <= impact_radius + _target_radius():
		attack_player.emit(attack_damage * rock_damage_multiplier)

func _set_state(new_state: String, duration: float) -> void:
	state = new_state
	if state in ["warning", "charge"]:
		gravity_velocity = Vector2.ZERO
		_gravity_was_affected = false
		gravity_contact_grace = 0.0
	phase_time = _boss_nonnegative(duration)
	phase_changed.emit(state)

func reset_state() -> void:
	clear_hit_reaction()
	clear_gravity(true)
	for rock: RockWarning in rocks:
		if is_instance_valid(rock):
			rock.queue_free()
	rocks.clear()
	charge_active = false
	charge_hit = false
	next_is_charge = start_with_charge
	_set_state("recovery", initial_recovery_duration)

func _exit_tree() -> void:
	for rock: RockWarning in rocks:
		if is_instance_valid(rock):
			rock.queue_free()

func health_bar_visible() -> bool:
	# Boss health remains critical encounter feedback regardless of mob settings.
	return true

func _draw() -> void:
	if state == "warning" and not charge_start.is_equal_approx(charge_end):
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
	var body: Color = _status_body_color()
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
