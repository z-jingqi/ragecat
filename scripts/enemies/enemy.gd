class_name EnemyActor
extends Node2D

signal killed(enemy: EnemyActor)
signal damaged(amount: float, crit: bool, pos: Vector2)

var status: StatusEffects = StatusEffects.new()
var is_dummy: bool = false
var show_health_bar: bool = true
## Authored inertia: acceleration, not eligibility, scales inversely with mass.
@export_range(0.01, 1000, 0.01) var mass: float = 1.0:
	set(value): mass = maxf(0.01, value) if is_finite(value) else 1.0
var gravity_source: Node2D
var gravity_velocity := Vector2.ZERO
var gravity_contact_grace: float = 0.0
var _gravity_was_affected: bool = false
var _gravity_grace_duration: float = 0.1
var _gravity_release_pending: bool = false
var _gravity_release_frame: int = -1
var _ai_displacement := Vector2.ZERO


@export var max_health: float = 44.0:
	set(value):
		var was_full := is_equal_approx(health, max_health)
		max_health = maxf(1.0, value) if is_finite(value) else 44.0
		health = max_health if was_full else minf(health, max_health)
var health: float = 44.0
@export_range(0.01, 200, 0.01) var radius: float = 16.0:
	set(value): radius = maxf(0.01, value) if is_finite(value) else 16.0
@export_range(0, 2000, 1) var speed: float = 64.0:
	set(value): speed = maxf(0.0, value) if is_finite(value) else 64.0
@export_range(0, 1000, 1) var default_knockback_force: float = 26.0
var target: Node2D
@export var arena_bounds: Rect2 = Rect2(80, 80, 1120, 560)
var ai_enabled: bool = true
var is_dead: bool = false
var variant: int = 0
var slow_multiplier: float = 1.0
var stun_remaining: float = 0.0
var flash_remaining: float = 0.0
var age: float = 0.0
@export_range(0.0, 2.0, 0.01) var hit_flash_duration: float = 0.11
@export var tint: Color = Color('#ac89ff')

func _enter_tree() -> void:
	process_physics_priority = -10

func _physics_process(delta: float) -> void:
	age += delta
	flash_remaining = maxf(0.0, flash_remaining - delta)
	is_gravity_affected()
	if not _gravity_release_pending or _gravity_release_frame != Engine.get_physics_frames():
		gravity_contact_grace = maxf(0.0, gravity_contact_grace - delta)
		if gravity_contact_grace < 0.000001: gravity_contact_grace = 0.0
	_gravity_release_pending = false
	_ai_displacement = Vector2.ZERO
	if ai_enabled and not is_dead:
		stun_remaining = maxf(0.0, stun_remaining - delta)
		if not is_dummy and is_instance_valid(target) and stun_remaining <= 0.0:
			_move_ai(delta)
	if not is_dead:
		var displacement := _ai_displacement + _gravity_displacement(delta)
		if not displacement.is_zero_approx():
			position += displacement
			_clamp_to_arena()
		status.tick(delta)
	queue_redraw()

func _move_ai(delta: float) -> void:
	_ai_displacement = position.direction_to(target.position) * speed * slow_multiplier * status.movement_time(delta)

func gravity_eligible() -> bool:
	return not is_dead and not is_dummy

func is_gravity_affected() -> bool:
	# Recompute at the point of use, including before this enemy's physics callback.
	# Newly spawned targets and range exits therefore never rely on effect order.
	var affected := false
	if gravity_eligible() and is_instance_valid(gravity_source) and not gravity_source.is_queued_for_deletion():
		if gravity_source.is_active():
			_gravity_grace_duration = maxf(0.0, gravity_source.contact_grace)
			affected = global_position.distance_squared_to(gravity_source.global_position) <= gravity_source.outer_radius * gravity_source.outer_radius
	if _gravity_was_affected and not affected:
		gravity_contact_grace = maxf(gravity_contact_grace, _gravity_grace_duration)
		_gravity_release_pending = true
		_gravity_release_frame = Engine.get_physics_frames()
	_gravity_was_affected = affected
	return affected

func contact_damage_suppressed() -> bool:
	return is_gravity_affected() or gravity_contact_grace > 0.0

func clear_gravity(reset_grace: bool = false) -> void:
	# Must run before removing the source, so current geometry can be sampled.
	var affected := is_gravity_affected()
	if affected and not reset_grace:
		gravity_contact_grace = maxf(gravity_contact_grace, _gravity_grace_duration)
		_gravity_release_pending = true
		_gravity_release_frame = Engine.get_physics_frames()
	gravity_source = null
	_gravity_was_affected = false
	gravity_velocity = Vector2.ZERO
	if reset_grace:
		gravity_contact_grace = 0.0
		_gravity_release_pending = false

func _gravity_displacement(delta: float) -> Vector2:
	if not is_gravity_affected():
		gravity_velocity = Vector2.ZERO
		return Vector2.ZERO
	var offset := gravity_source.global_position - global_position
	var distance := offset.length()
	var acceleration: float = maxf(0.0, gravity_source.pull_acceleration) / mass
	var cap: float = maxf(0.0, gravity_source.pull_speed_cap)
	var damping: float = maxf(0.0, gravity_source.pull_damping)
	# A damped velocity approaches a mass-dependent terminal speed. The stopping
	# envelope decelerates near the tip instead of overshooting or teleporting.
	var terminal := cap / maxf(1.0, mass)
	var desired := offset.normalized() * minf(terminal, sqrt(2.0 * acceleration * distance))
	if damping > 0.0:
		var smoothed := gravity_velocity.lerp(desired, 1.0 - exp(-damping * maxf(0.0, delta)))
		gravity_velocity = gravity_velocity.move_toward(smoothed, acceleration * maxf(0.0, delta))
	else:
		gravity_velocity = gravity_velocity.move_toward(desired, acceleration * maxf(0.0, delta))
	gravity_velocity = gravity_velocity.limit_length(cap)
	var displacement := gravity_velocity * maxf(0.0, delta)
	if displacement.length() > distance:
		displacement = displacement.limit_length(distance)
	return displacement

func knockback(direction: Vector2, force: float = -1.0) -> void:
	if not is_dummy:
		position += direction.normalized() * (default_knockback_force if force < 0.0 else force)
		_clamp_to_arena()

func _clamp_to_arena() -> void:
	var inset := Vector2.ONE * radius
	inset = inset.min(arena_bounds.size * 0.5)
	position = position.clamp(arena_bounds.position + inset, arena_bounds.end - inset)

func receive_damage(amount: float, crit: bool = false) -> void:
	if is_dead or amount <= 0.0:
		return
	var dealt := minf(health, amount)
	health = maxf(0.0, health - dealt)
	flash_remaining = hit_flash_duration
	damaged.emit(dealt, crit, global_position)
	if health <= 0.0:
		is_dead = true
		clear_gravity(true)
		killed.emit(self)
		queue_free()

func health_bar_visible() -> bool:
	return show_health_bar

func _draw() -> void:
	var body_color: Color = _status_body_color()
	var bob: float = 0.0 if status.is_frozen() else sin(age * 7.0) * 2.0
	draw_ellipse_shadow()
	_draw_status_rings()
	if variant % 2 == 0:
		var wing: float = 0.0 if status.is_frozen() else sin(age * 12.0) * 6.0
		draw_colored_polygon(PackedVector2Array([Vector2(-6, -5 + bob), Vector2(-27, -16 + wing), Vector2(-24, 8), Vector2(-10, 5 + bob)]), body_color.darkened(0.25))
		draw_colored_polygon(PackedVector2Array([Vector2(6, -5 + bob), Vector2(27, -16 + wing), Vector2(24, 8), Vector2(10, 5 + bob)]), body_color.darkened(0.25))
		draw_circle(Vector2(0, bob), radius * 0.78, body_color)
		draw_colored_polygon(PackedVector2Array([Vector2(-10, -6 + bob), Vector2(-8, -20 + bob), Vector2(-1, -10 + bob)]), body_color)
		draw_colored_polygon(PackedVector2Array([Vector2(10, -6 + bob), Vector2(8, -20 + bob), Vector2(1, -10 + bob)]), body_color)
	else:
		draw_circle(Vector2(0, bob), radius, body_color)
		draw_circle(Vector2(-6, -6 + bob), 5, body_color.lightened(0.25))
	for side: float in [-1.0, 1.0]:
		draw_circle(Vector2(side * 5.0, -2 + bob), 3.5, Color('#191c35'))
		draw_circle(Vector2(side * 5.0, -3 + bob), 1.2, Color('#fff2d6'))
	if health_bar_visible():
		draw_rect(Rect2(-18, -29, 36, 4), Color('#171b2b'))
		draw_rect(Rect2(-18, -29, 36 * health / max_health, 4), Color('#fd7e94'))
	if stun_remaining > 0.0:
		draw_arc(Vector2(0, -23), 10, age * 4.0, age * 4.0 + 4.0, 12, Color('#ffe396'), 2)

func draw_ellipse_shadow() -> void:
	draw_set_transform(Vector2(0, radius * 0.7), 0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, radius * 1.1, Color(0.02, 0.03, 0.07, 0.35))
	draw_set_transform(Vector2.ZERO)

func _status_body_color() -> Color:
	if flash_remaining > 0.0:
		return Color.WHITE
	if status.is_frozen():
		return tint.lerp(Color('#c7f6ff'), 0.8)
	if status.chill_remaining > 0.0:
		return tint.lerp(Color('#81d8ff'), 0.35)
	return tint

func _draw_status_rings() -> void:
	if status.is_frozen():
		var crystal := PackedVector2Array()
		for i: int in range(6):
			crystal.append(Vector2.from_angle(float(i) * TAU / 6.0 - PI * 0.5) * (radius + 8.0))
		draw_colored_polygon(crystal, Color(0.45, 0.85, 1.0, 0.18))
		crystal.append(crystal[0])
		draw_polyline(crystal, Color('#c7f6ff'), 2.0)
	elif status.chill_remaining > 0.0:
		draw_arc(Vector2.ZERO, radius + 4.0, age, age + TAU * 0.85, 28, Color('#81d8ff'), 2.0)
	for i: int in range(status.frost_stacks):
		var offset := Vector2((float(i) - float(status.frost_stacks - 1) * 0.5) * 7.0, radius + 10.0)
		draw_circle(offset, 2.5, Color('#c7f6ff'))
