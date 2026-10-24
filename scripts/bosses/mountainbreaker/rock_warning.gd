class_name RockWarning
extends Node2D

signal impact(center: Vector2, impact_radius: float)

# Guard values avoid degenerate geometry and division by zero; tune behavior below.
const MIN_RADIUS: float = 0.01
const MIN_DRAW_DURATION: float = 0.01

@export_group("Rock Hazard")
@export_range(0.01, 200.0, 0.5, "or_greater") var radius: float = 31.0:
	set(value):
		radius = maxf(MIN_RADIUS, _nonnegative(value))
		if is_instance_valid(ground_warning): _update_ground_radius()
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var warning_duration: float = 1.25:
	set(value):
		warning_duration = _nonnegative(value)
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var aftermath_duration: float = 0.28:
	set(value):
		aftermath_duration = _nonnegative(value)
var elapsed: float = 0.0
var ai_enabled: bool = true
var impacted: bool = false
var ground_warning: Polygon2D
var ground_material: ShaderMaterial

static func _nonnegative(value: float) -> float:
	return maxf(0.0, value) if is_finite(value) else 0.0

func _init() -> void:
	top_level = true

var arena_bounds: Rect2 = Rect2()

func _ready() -> void:
	var clipping := ShaderMaterial.new()
	clipping.shader = preload("res://shaders/boss_hazard_clip.gdshader")
	clipping.set_shader_parameter("arena_rect", Vector4(arena_bounds.position.x, arena_bounds.position.y, arena_bounds.size.x, arena_bounds.size.y))
	material = clipping
	ground_warning = Polygon2D.new()
	ground_warning.show_behind_parent = true

	ground_material = ShaderMaterial.new()
	ground_material.shader = preload("res://shaders/rock_ground_warning.gdshader")
	ground_material.set_shader_parameter("arena_rect", Vector4(arena_bounds.position.x, arena_bounds.position.y, arena_bounds.size.x, arena_bounds.size.y))
	ground_material.set_shader_parameter("hazard_radius", radius)
	ground_material.set_shader_parameter("dust_color", VfxAtlasRenderer.color_setting(&"rock_warning_color"))
	ground_material.set_shader_parameter("opacity", VfxAtlasRenderer.setting(&"rock_warning_opacity"))
	ground_material.set_shader_parameter("edge_softness", VfxAtlasRenderer.setting(&"rock_warning_edge_softness"))
	ground_warning.material = ground_material
	add_child(ground_warning)
	_update_ground_radius()

func _physics_process(delta: float) -> void:
	if not ai_enabled:
		return
	elapsed += delta
	if elapsed >= warning_duration and not impacted:
		impacted = true
		impact.emit(global_position, radius)
	if elapsed > warning_duration + aftermath_duration:
		queue_free()
	if is_instance_valid(ground_warning):
		ground_warning.visible = not impacted
		ground_material.set_shader_parameter("progress", clampf(elapsed / maxf(warning_duration, MIN_DRAW_DURATION), 0.0, 1.0))
	queue_redraw()

func _draw() -> void:
	var progress: float = clampf(elapsed / maxf(warning_duration, MIN_DRAW_DURATION), 0.0, 1.0)
	if not impacted:
		# Stable full footprint is handled by the textured ground child. Small
		# inward dust motes communicate gathering without inventing a new boundary.
		var mote_count := clampi(int(VfxAtlasRenderer.setting(&"rock_warning_mote_count")), 0, 16)
		for i in range(mote_count):
			var phase := fmod(progress * 1.25 + float(i) * 0.618, 1.0)
			var angle := float(i) * 2.4
			var mote_at := Vector2.from_angle(angle) * radius * (0.8 - phase * 0.5)
			mote_at.y -= sin(phase * PI) * 5.0
			draw_circle(mote_at, 0.8 + sin(phase * PI), Color(0.62, 0.50, 0.34, sin(phase * PI) * VfxAtlasRenderer.setting(&"rock_dust_opacity")))
		var fall_progress := visual_fall_progress(progress)
		if fall_progress <= 0.0: return
		var fall_center := Vector2(0, -VfxAtlasRenderer.setting(&"rock_drop_height") * (1.0 - fall_progress) - VfxAtlasRenderer.setting(&"rock_target_offset"))
		if VfxAtlasRenderer.draw_clip(self, &"stone_fall", fall_progress, Rect2(fall_center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), Color.WHITE, true, true): return
		var rock_y: float = fall_center.y
		draw_colored_polygon(PackedVector2Array([Vector2(-10, rock_y), Vector2(-6, rock_y - 15), Vector2(8, rock_y - 18), Vector2(15, rock_y - 5), Vector2(5, rock_y + 6)]), Color('#71849c'))
	else:
		if VfxAtlasRenderer.draw_clip(self, &"stone_impact", (elapsed - warning_duration) / maxf(aftermath_duration, MIN_DRAW_DURATION), Rect2(Vector2.ONE * -radius, Vector2.ONE * radius * 2.0), Color.WHITE, true, true): return
		var fade: float = clampf(1.0 - (elapsed - warning_duration) / maxf(aftermath_duration, MIN_DRAW_DURATION), 0.0, 1.0)
		draw_circle(Vector2.ZERO, radius, Color(1.0, 0.75, 0.42, fade * 0.65))
		for i: int in range(7):
			var direction: Vector2 = Vector2.from_angle(float(i) * TAU / 7.0)
			draw_circle(direction * radius * (1.3 - fade * 0.6), 4.0 * fade, Color('#a6b2c0'))

func visual_fall_progress(warning_progress: float) -> float:
	var start := clampf(VfxAtlasRenderer.setting(&"rock_fall_start"), 0.0, 0.95)
	var phase := clampf((warning_progress - start) / (1.0 - start), 0.0, 1.0)
	return pow(phase, maxf(1.0, VfxAtlasRenderer.setting(&"rock_fall_exponent")))

func _update_ground_radius() -> void:
	ground_warning.polygon = PackedVector2Array([Vector2(-radius, -radius), Vector2(radius, -radius), Vector2(radius, radius), Vector2(-radius, radius)])
	if ground_material != null: ground_material.set_shader_parameter("hazard_radius", radius)
