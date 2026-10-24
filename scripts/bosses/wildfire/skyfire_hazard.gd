class_name SkyfireHazard
extends Node2D
signal impact(hazard: SkyfireHazard)
var radius: float = 120.0:
	set(value):
		radius = value
		if is_instance_valid(ground_surface): _update_ground_radius()
var warning: float = 1.2
var impact_damage: float = 14.0
var burn_duration: float = 3.0
var burn_damage: float = 4.0
var elapsed: float = 0.0
var impacted := false
var ai_enabled := true
var splash := false
var ground_surface: Polygon2D
var ground_material: ShaderMaterial

func _init() -> void:
	set_meta("boss_hazard", true)
	top_level = true

var arena_bounds: Rect2 = Rect2()

func _ready() -> void:
	var clipping := ShaderMaterial.new()
	clipping.shader = preload("res://shaders/boss_hazard_clip.gdshader")
	clipping.set_shader_parameter("arena_rect", Vector4(arena_bounds.position.x, arena_bounds.position.y, arena_bounds.size.x, arena_bounds.size.y))
	material = clipping
	ground_surface = Polygon2D.new()
	ground_surface.show_behind_parent = true
	ground_material = ShaderMaterial.new()
	ground_material.shader = preload("res://shaders/fire_ground_surface.gdshader")
	ground_material.set_shader_parameter("arena_rect", Vector4(arena_bounds.position.x, arena_bounds.position.y, arena_bounds.size.x, arena_bounds.size.y))
	ground_material.set_shader_parameter("warning_opacity", VfxAtlasRenderer.setting(&"skyfire_warning_opacity"))
	ground_material.set_shader_parameter("ground_opacity", VfxAtlasRenderer.setting(&"skyfire_ground_opacity"))
	ground_material.set_shader_parameter("edge_softness", VfxAtlasRenderer.setting(&"skyfire_warning_edge_softness"))
	ground_surface.material = ground_material
	add_child(ground_surface)
	_update_ground_radius()
	_update_ground_clock()

func _physics_process(delta: float) -> void:
	if not ai_enabled or not is_finite(delta) or delta < 0.0: return
	elapsed += delta
	if not impacted and elapsed >= warning:
		impacted = true
		impact.emit(self)
	if elapsed >= warning + burn_duration: queue_free()
	_update_ground_clock()
	queue_redraw()

func contains(point: Vector2, target_radius: float) -> bool:
	return point.distance_to(global_position) <= radius + target_radius

func burning() -> bool:
	return impacted and elapsed < warning + burn_duration and not is_queued_for_deletion()

func _draw() -> void:
	if not impacted:
		var fraction := clampf(elapsed / maxf(0.01, warning), 0.0, 1.0)
		var fall_progress := visual_fall_progress(fraction)
		if fall_progress <= 0.0: return
		var meteor_radius := radius * VfxAtlasRenderer.setting(&"skyfire_mass_radius_ratio")
		var meteor_center := Vector2(0, -VfxAtlasRenderer.setting(&"skyfire_drop_height") * (1.0 - fall_progress))
		if VfxAtlasRenderer.draw_clip(self, &"skyfire_fall", fall_progress, Rect2(meteor_center - Vector2.ONE * meteor_radius, Vector2.ONE * meteor_radius * 2.0), Color.WHITE, true, true): return
		# Atlas-off fallback is a small fractured mass, never a target outline.
		var shape := PackedVector2Array([Vector2(-.7,-.2),Vector2(-.4,-.65),Vector2(.35,-.55),Vector2(.65,.1),Vector2(.2,.6),Vector2(-.5,.45)])
		for i in range(shape.size()): shape[i] = meteor_center + shape[i] * meteor_radius
		draw_colored_polygon(shape, Color(.48,.12,.025,.9))
	else:
		var age := elapsed - warning
		var progress := clampf(age / maxf(.01, burn_duration), 0.0, 1.0)
		# Low torn flames sit over persistent textured scorch. Ground opacity does
		# not collapse before the original burn deadline, even under atlas culling.
		var flame_alpha := (1.0 - progress * .65) * VfxAtlasRenderer.setting(&"skyfire_low_flame_opacity")
		VfxAtlasRenderer.draw_clip(self, &"fire_ground", age, Rect2(Vector2.ONE * -radius, Vector2.ONE * radius * 2.0), Color(1,1,1,flame_alpha), true)
		VfxAtlasRenderer.draw_clip(self, &"fire_burst", age, Rect2(Vector2.ONE * -radius, Vector2.ONE * radius * 2.0), Color(1,1,1,VfxAtlasRenderer.setting(&"skyfire_impact_opacity")), true)

func visual_fall_progress(warning_progress: float) -> float:
	var start := clampf(VfxAtlasRenderer.setting(&"skyfire_fall_start"), 0.0, .95)
	return pow(clampf((warning_progress - start) / (1.0 - start), 0.0, 1.0), maxf(1.0,VfxAtlasRenderer.setting(&"skyfire_fall_exponent")))

func _update_ground_radius() -> void:
	ground_surface.polygon = PackedVector2Array([Vector2(-radius,-radius),Vector2(radius,-radius),Vector2(radius,radius),Vector2(-radius,radius)])
	ground_material.set_shader_parameter("hazard_radius", radius)

func _update_ground_clock() -> void:
	if ground_material == null: return
	ground_material.set_shader_parameter("phase", elapsed)
	ground_material.set_shader_parameter("warning_progress", clampf(elapsed / maxf(.01, warning), 0.0, 1.0))
	ground_material.set_shader_parameter("burn_progress", clampf((elapsed - warning) / maxf(.01, burn_duration), 0.0, 1.0))
	ground_material.set_shader_parameter("active", impacted)
