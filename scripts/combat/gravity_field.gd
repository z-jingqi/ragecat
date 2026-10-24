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
var _matter_surface: DarkMatterSurface

class DarkMatterSurface extends Node2D:
	var radius: float = 0.0
	func _draw() -> void:
		if radius > 0.0:
			draw_rect(Rect2(Vector2.ONE * -radius, Vector2.ONE * radius * 2.0), Color.WHITE)


func _ready() -> void:
	visual_definition = visual_definition.validated_copy()
	_matter_surface = DarkMatterSurface.new()
	_matter_surface.name = "DarkMaterialSurface"
	# Keep the surface above the arena floor while sorting behind this field.
	# Negative Z would put it behind the entire floor, not just the arrow.
	_matter_surface.z_index = 0
	_matter_surface.show_behind_parent = true
	var surface_material := ShaderMaterial.new()
	surface_material.shader = preload("res://shaders/dark_field_material.gdshader")
	_matter_surface.material = surface_material
	add_child(_matter_surface)

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
	if is_instance_valid(_matter_surface): _matter_surface.visible = false
	exposure.clear()

func _exit_tree() -> void:
	deactivate()

func _draw() -> void:
	_sync_matter_surface()
	if not active or outer_radius <= 0.0: return
	# The material masks and inward trails use the actual two gameplay radii.
	# No outline rings and no atlas-driven enlargement of attraction or damage.
	VfxAtlasRenderer.draw_clip(self, &"dark_vortex", age, Rect2(Vector2.ONE * -inner_radius, Vector2.ONE * inner_radius * 2.0))
	var stream_color := VfxAtlasRenderer.color_setting(&"dark_stream_color", color)
	var stream_opacity := clampf(VfxAtlasRenderer.setting(&"dark_stream_opacity"), 0.0, 1.0)
	var stream_width := maxf(0.1, VfxAtlasRenderer.setting(&"dark_stream_width"))
	for i in range(visual_definition.vortex_streaks):
		var points := _stream_points(i)
		var colors := PackedColorArray()
		var phase := fposmod(age * visual_definition.vortex_inward_speed + float(i) / visual_definition.vortex_streaks, 1.0)
		for step in range(points.size()):
			var along := float(step) / maxf(1.0, points.size() - 1)
			colors.append(Color(stream_color, stream_opacity * sin(phase * PI) * sin(along * PI)))
		draw_polyline_colors(points, colors, stream_width, true)

func _stream_points(index: int) -> PackedVector2Array:
	var config := visual_definition
	var phase := fposmod(age * config.vortex_inward_speed + float(index) / config.vortex_streaks, 1.0)
	var travel_span := maxf(1.0, outer_radius - inner_radius * 0.2)
	var tail_phase := maxf(0.0, phase - VfxAtlasRenderer.setting(&"dark_stream_length") / travel_span)
	var bend := VfxAtlasRenderer.setting(&"dark_stream_bend")
	var points := PackedVector2Array()
	for step in range(config.vortex_segments + 1):
		var along := float(step) / config.vortex_segments
		var inward := lerpf(tail_phase, phase, along)
		var angle := float(index) * TAU / config.vortex_streaks - age * config.vortex_rotation_speed * 0.1 + inward * bend
		points.append(Vector2.from_angle(angle) * lerpf(outer_radius, inner_radius * 0.2, inward))
	return points

func _sync_matter_surface() -> void:
	if not is_instance_valid(_matter_surface): return
	_matter_surface.visible = active and outer_radius > 0.0
	_matter_surface.radius = maxf(0.0, outer_radius)
	var surface_material := _matter_surface.material as ShaderMaterial
	surface_material.set_shader_parameter("outer_radius", maxf(1.0, outer_radius))
	surface_material.set_shader_parameter("core_ratio", clampf(inner_radius / maxf(1.0, outer_radius), 0.0, 1.0))
	surface_material.set_shader_parameter("phase", age * visual_definition.vortex_inward_speed)
	surface_material.set_shader_parameter("opacity", clampf(VfxAtlasRenderer.setting(&"dark_surface_opacity"), 0.0, 1.0))
	surface_material.set_shader_parameter("grain_scale", maxf(1.0, VfxAtlasRenderer.setting(&"dark_surface_scale")))
	surface_material.set_shader_parameter("warp_strength", clampf(VfxAtlasRenderer.setting(&"dark_surface_warp"), 0.0, 0.5))
	surface_material.set_shader_parameter("core_density", maxf(0.0, VfxAtlasRenderer.setting(&"dark_core_density")))
	surface_material.set_shader_parameter("outer_density", maxf(0.0, VfxAtlasRenderer.setting(&"dark_outer_density")))
	surface_material.set_shader_parameter("fold_color", VfxAtlasRenderer.color_setting(&"dark_fold_color", color))
	surface_material.set_shader_parameter("edge_softness", clampf(VfxAtlasRenderer.setting(&"dark_edge_softness"), 0.01, 0.3))
	surface_material.set_shader_parameter("matter_color", VfxAtlasRenderer.color_setting(&"dark_material_color", color.darkened(0.8)))
	_matter_surface.queue_redraw()

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
