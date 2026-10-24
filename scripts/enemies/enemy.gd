class_name EnemyActor
extends Node2D
## Reserved elemental affinity. Neutral by default; not exposed in player UI.
@export var element_damage_multipliers: Dictionary = {"fire":1.0,"lightning":1.0,"ice":1.0,"dark":1.0}
var contact_damage_multiplier: float = 1.0

signal killed(enemy: EnemyActor)
## Accounting signal: actual health removed, excluding overkill.
signal damaged(amount: float, crit: bool, pos: Vector2)
## Presentation signal: accepted, resolved damage before remaining-HP truncation.
signal damage_resolved(amount: float, crit: bool, pos: Vector2)
signal status_feedback(kind: String, at: Vector2)

var status: StatusEffects = StatusEffects.new()
var is_dummy: bool = false
var show_health_bar: bool = true
@export var health_bar_definition: HealthBarDefinition = preload("res://resources/settings/health_bars.tres")
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
var feedback_definition: HitFeedbackDefinition = preload("res://resources/feedback/hit_feedback.tres"):
	set(value): feedback_definition = value.validated_copy() if value != null else HitFeedbackDefinition.new()
var reaction_remaining: float = 0.0
var reaction_cooldown_remaining: float = 0.0
var knockback_remaining: float = 0.0
var _knockback_vector := Vector2.ZERO
var _knockback_duration: float = 0.08
var cosmetic_feedback_enabled: bool = true


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
var _occupancy_radius_locked := false
var _occupancy_radius_snapshot := 14.0
var occupancy_configuration_rejected := false
var occupancy_controller: Node
## Occupancy is an independent ground disk, not the visual outline/hurtbox.
@export_range(1, 100, 0.5) var occupancy_radius: float = 14.0:
	set(value):
		var proposed := clampf(value, 1.0, 100.0) if is_finite(value) else 14.0
		if _occupancy_radius_locked and (not is_finite(value) or not is_equal_approx(proposed, _occupancy_radius_snapshot)):
			if not occupancy_configuration_rejected: push_warning("Enemy occupancy radius is a spawn snapshot; apply tuning by respawning/resetting, not live expansion")
			occupancy_configuration_rejected = true
			occupancy_radius = _occupancy_radius_snapshot
		else: occupancy_radius = proposed
var occupancy_correction := Vector2.ZERO
var occupancy_motion_start := Vector2.ZERO
var occupancy_motion_frame: int = -1
## Authored charge supplies this; no new damage is generated.
var occupancy_priority_motion := Vector2.ZERO
var target: Node2D
@export var arena_bounds: Rect2 = Rect2(80, 80, 1120, 560)
var ai_enabled: bool = true
var is_dead: bool = false
var variant: int = 0
var slow_multiplier: float = 1.0
var stun_remaining: float = 0.0
var flash_remaining: float = 0.0
var flash_cooldown_remaining: float = 0.0
var age: float = 0.0
@export var tint: Color = Color('#ac89ff')

func _enter_tree() -> void:
	process_physics_priority = -10

func _physics_process(delta: float) -> void:
	if not is_finite(delta) or delta < 0.0: return
	occupancy_motion_start = position
	occupancy_motion_frame = Engine.get_physics_frames()
	occupancy_correction = Vector2.ZERO
	occupancy_priority_motion = Vector2.ZERO
	age += delta
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
		var displacement := _ai_displacement + _gravity_displacement(delta) + _knockback_displacement(delta)
		if not displacement.is_zero_approx():
			position += displacement
			_clamp_to_arena()
		var was_frozen := status.is_frozen()
		var was_marked := status.has_ice_mark()
		status.tick(delta)
		if was_frozen and not status.is_frozen(): status_feedback.emit("thaw", global_position)
		if was_marked and not status.has_ice_mark(): status_feedback.emit("mark_expire", global_position)
	flash_remaining = maxf(0.0, flash_remaining - delta)
	flash_cooldown_remaining = maxf(0.0, flash_cooldown_remaining - delta)
	reaction_remaining = maxf(0.0, reaction_remaining - delta)
	reaction_cooldown_remaining = maxf(0.0, reaction_cooldown_remaining - delta)
	queue_redraw()

func occupancy_locomotion_displacement(voluntary: Vector2) -> Vector2:
	# Only the opposing component cancels stride. Sideways/forward external
	# correction must never add locomotion, especially under freeze/gravity.
	if voluntary.is_zero_approx(): return Vector2.ZERO
	var direction := voluntary.normalized()
	return direction * maxf(0.0, voluntary.length() + minf(0.0, occupancy_correction.dot(direction)))

func lock_occupancy_radius() -> void:
	if not _occupancy_radius_locked:
		_occupancy_radius_snapshot = occupancy_radius
		_occupancy_radius_locked = true

func _move_ai(delta: float) -> void:
	_ai_displacement = position.direction_to(target.position) * speed * slow_multiplier * movement_time(delta)

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

func movement_time(delta: float) -> float:
	# Remove only the initial overlapping pause from ice's exact motion integral.
	# Freeze is stronger control, not another interval added after the hit pause.
	return maxf(0.0, status.movement_time(delta) - status.movement_time(minf(delta, reaction_remaining)))

func hit_movement_eligible() -> bool:
	return not is_dummy and not is_dead

func request_hit_reaction(direct: bool = true) -> bool:
	if is_dead: return false
	# A derived impact may reserve translation first. It must not suppress the
	# first direct visual, but neither gate refreshes under repeated attacks.
	if direct and cosmetic_feedback_enabled and flash_cooldown_remaining <= 0.000001:
		flash_remaining = feedback_definition.flash_duration
		flash_cooldown_remaining = feedback_definition.reaction_cooldown
	if reaction_cooldown_remaining > 0.000001: return false
	var duration := feedback_definition.direct_pause if direct else feedback_definition.derived_pause
	reaction_cooldown_remaining = feedback_definition.reaction_cooldown
	if hit_movement_eligible(): reaction_remaining = duration
	queue_redraw()
	return true

func clear_hit_reaction() -> void:
	reaction_remaining = 0.0
	reaction_cooldown_remaining = 0.0
	flash_remaining = 0.0
	flash_cooldown_remaining = 0.0
	knockback_remaining = 0.0
	_knockback_vector = Vector2.ZERO

func knockback(direction: Vector2, force: float = -1.0) -> void:
	if is_dummy or is_dead or not direction.is_finite() or direction.is_zero_approx(): return
	if not is_finite(force): return
	var distance := default_knockback_force if force == -1.0 else maxf(0.0, force)
	if not is_finite(distance) or distance <= 0.0: return
	_knockback_duration = maxf(0.02, feedback_definition.knockback_duration)
	distance = minf(distance, minf(feedback_definition.knockback_distance_cap, feedback_definition.knockback_speed_cap * _knockback_duration * 0.5))
	# Replace, never add: same-frame spam cannot stack future travel or velocity.
	_knockback_vector = direction.normalized() * distance
	knockback_remaining = _knockback_duration

func _knockback_displacement(delta: float) -> Vector2:
	if knockback_remaining <= 0.0: return Vector2.ZERO
	var before := knockback_remaining / _knockback_duration
	knockback_remaining = maxf(0.0, knockback_remaining - delta)
	var after := knockback_remaining / _knockback_duration
	# Integral of a linearly decaying velocity, including a partial final frame.
	return _knockback_vector * (before * before - after * after)

func _clamp_to_arena() -> void:
	var inset := Vector2.ONE * radius
	inset = inset.min(arena_bounds.size * 0.5)
	position = position.clamp(arena_bounds.position + inset, arena_bounds.end - inset)

func receive_damage(amount: float, crit: bool = false) -> void:
	if is_dead or not is_finite(amount) or amount <= 0.0:
		return
	var dealt := minf(health, amount)
	health = maxf(0.0, health - dealt)
	damaged.emit(dealt, crit, global_position)
	if dealt > 0.0: damage_resolved.emit(amount, crit, global_position)
	if health <= 0.0:
		is_dead = true
		clear_hit_reaction()
		status.clear()
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
		draw_rect(Rect2(-18, -29, 36 * health / max_health, 4), health_bar_definition.fill_color)
	if stun_remaining > 0.0:
		draw_arc(Vector2(0, -23), 10, age * 4.0, age * 4.0 + 4.0, 12, Color('#ffe396'), 2)

func draw_ellipse_shadow() -> void:
	draw_set_transform(Vector2(0, radius * 0.7), 0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, radius * 1.1, Color(0.02, 0.03, 0.07, 0.35))
	draw_set_transform(Vector2.ZERO)

func _status_body_color() -> Color:
	var color := tint
	if flash_remaining > 0.0 and cosmetic_feedback_enabled:
		color = color.lerp(Color.WHITE, feedback_definition.flash_strength)
	return color

func _draw_status_rings() -> void:
	if status.shock_remaining > 0.0:
		# Two local ion filaments communicate charge without a decorative foot ring.
		var visual := feedback_definition.elements
		for side: float in [-1.0, 1.0]:
			var phase := sin(age * visual.shock_filament_speed + side)
			var x := side * (radius + visual.shock_filament_padding)
			var length := minf(radius * 0.75, visual.bolt_branch_length)
			var points := PackedVector2Array([Vector2(x, -length), Vector2(x - side * 3.0, -length * 0.25), Vector2(x + side * phase * 2.0, length * 0.2), Vector2(x - side * 2.0, length * 0.7)])
			draw_polyline(points, Color(feedback_definition.lightning_color, visual.shock_filament_opacity * (0.65 + 0.35 * absf(phase))), visual.bolt_core_width, true)
	if status.has_ice_mark():
		var center := Vector2(0, -radius - 16.0)
		var diamond := PackedVector2Array([center + Vector2(0, -9), center + Vector2(7, 0), center + Vector2(0, 9), center + Vector2(-7, 0), center + Vector2(0, -9)])
		draw_colored_polygon(diamond, Color(0.45, 0.85, 1.0, 0.35))
		draw_polyline(diamond, Color("#c7f6ff"), 2.0)
	for i: int in range(status.frost_stacks):
		var offset := Vector2((float(i) - float(status.frost_stacks - 1) * 0.5) * 7.0, radius + 10.0)
		draw_circle(offset, 2.5, Color('#c7f6ff'))
