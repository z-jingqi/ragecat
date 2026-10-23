class_name GravityField
extends Node2D
## Arrow-tip effect; enemy physics owns movement and queries membership directly.
var visual_definition: ElementVisualDefinition = preload("res://resources/feedback/element_visuals.tres")
var outer_radius: float
var inner_radius: float
var pull_acceleration: float
var pull_speed_cap: float
var pull_damping: float
var contact_grace: float
var damage_per_second: float
var tick_interval: float
var enemies: Node2D
var damage_callback: Callable
var active := true
var age := 0.0
var exposure: Dictionary = {}
var color := Color("ba8bff")

func _ready() -> void:
	visual_definition = visual_definition.validated_copy()

func is_active() -> bool:
	return active and is_inside_tree() and not is_queued_for_deletion()

func configure(stats: CombatStats, container: Node2D, callback: Callable) -> void:
	var config := stats.element_skill.gravity
	outer_radius = stats.gravity_outer_radius
	inner_radius = stats.gravity_inner_radius
	pull_acceleration = stats.gravity_acceleration
	pull_speed_cap = config.pull_speed_cap
	pull_damping = config.pull_damping
	contact_grace = config.contact_grace
	damage_per_second = stats.gravity_dps
	tick_interval = config.tick_interval
	enemies = container
	damage_callback = callback
	color = stats.element_skill.color

func attach_enemy(enemy: EnemyActor) -> void:
	if is_active(): enemy.gravity_source = self

func tick(delta: float, previous_tip: Vector2 = Vector2.INF) -> void:
	if not is_active(): return
	age += delta
	if previous_tip == Vector2.INF: previous_tip = global_position
	var live: Dictionary = {}
	for enemy: EnemyActor in enemies.get_children():
		if enemy.is_dead: continue
		attach_enemy(enemy)
		var id := enemy.get_instance_id()
		live[id] = true
		var in_core_time := maxf(0.0, delta) * _inside_fraction(previous_tip, global_position, enemy.global_position)
		var elapsed := float(exposure.get(id, 0.0)) + in_core_time
		# Carry partial exposure through exits. Pay only quanta earned during
		# an in-core part of this step, even if the tip has since passed by.
		# Batch quanta into one packet to bound stalled-frame work.
		if in_core_time > 0.0:
			var ticks := floori((elapsed + 0.000001) / tick_interval)
			if ticks > 0:
				elapsed = maxf(0.0, elapsed - ticks * tick_interval)
				if damage_callback.is_valid(): damage_callback.call(enemy, damage_per_second * tick_interval * ticks, "dark")
		exposure[id] = elapsed

	for id in exposure.keys():
		if not live.has(id): exposure.erase(id)
	queue_redraw()

func deactivate(reset_grace: bool = false) -> void:
	if not active: return
	# Release while the source is still valid so the enemy can capture grace.
	if is_instance_valid(enemies):
		for enemy: EnemyActor in enemies.get_children():
			if enemy.gravity_source == self: enemy.clear_gravity(reset_grace)
	active = false
	exposure.clear()

func _exit_tree() -> void:
	deactivate()

func _draw() -> void:
	var config := visual_definition
	draw_circle(Vector2.ZERO, outer_radius, Color(color, config.vortex_outer_opacity * 0.4))
	draw_arc(Vector2.ZERO, outer_radius, 0, TAU, 64, Color(color, config.vortex_outer_opacity * 2.0), 1.0, true)
	draw_circle(Vector2.ZERO, inner_radius, Color(color, config.vortex_core_opacity))
	var core_outline := VfxAtlasRenderer.setting(&"dark_core_outline_opacity") if VfxAtlasRenderer.available(&"dark_vortex") else 0.55
	draw_arc(Vector2.ZERO, inner_radius, 0, TAU, 48, Color(color, core_outline), 1.5, true)
	var atlas_drawn := VfxAtlasRenderer.draw_clip(self, &"dark_vortex", age, Rect2(Vector2.ONE * -inner_radius, Vector2.ONE * inner_radius * 2.0))
	for arm in range(0 if atlas_drawn else config.vortex_arms):
		var points := PackedVector2Array()
		for step in range(config.vortex_segments + 1):
			var fraction := float(step) / config.vortex_segments
			var angle := arm * TAU / config.vortex_arms + fraction * TAU - age * config.vortex_rotation_speed
			points.append(Vector2.from_angle(angle) * lerpf(inner_radius * 0.08, inner_radius, fraction))
		draw_polyline(points, Color(color, 0.25), 4.0, true)
		draw_polyline(points, Color(color.lightened(0.3), 0.7), 1.5, true)
	for i in range(config.vortex_streaks):
		var phase := fposmod(age * config.vortex_inward_speed + float(i) / config.vortex_streaks, 1.0)
		var angle := float(i) * TAU / config.vortex_streaks - age * config.vortex_rotation_speed * 0.25 + phase * 0.6
		var distance := lerpf(outer_radius, inner_radius * 0.2, phase)
		var tip := Vector2.from_angle(angle) * distance
		var tail := Vector2.from_angle(angle - 0.07) * minf(outer_radius, distance + 10.0)
		draw_line(tail, tip, Color(color, sin(phase * PI) * 0.5), 1.5, true)
	draw_circle(Vector2.ZERO, inner_radius * 0.12, color.darkened(0.8))

func _inside_fraction(start: Vector2, end: Vector2, center: Vector2) -> float:
	var travel := end - start
	var length_squared := travel.length_squared()
	if length_squared <= 0.000001:
		return 1.0 if center.distance_squared_to(end) <= inner_radius * inner_radius else 0.0
	var relative := start - center
	var b := 2.0 * relative.dot(travel)
	var c := relative.length_squared() - inner_radius * inner_radius
	var discriminant := b * b - 4.0 * length_squared * c
	if discriminant < 0.0: return 0.0
	var root := sqrt(discriminant)
	var entry := clampf((-b-root)/(2.0*length_squared), 0.0, 1.0)
	var exit := clampf((-b+root)/(2.0*length_squared), 0.0, 1.0)
	return maxf(0.0, exit-entry)
