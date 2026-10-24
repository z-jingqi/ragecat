class_name BossFireRing
extends Node2D
signal hit(damage: float)
var target: Node2D
var speed: float = 180.0
var width: float = 28.0
var damage: float = 12.0
var ring_radius: float = 42.0
var maximum_radius: float = 1500.0
var ai_enabled := true
var consumed := false
var previous_target := Vector2.ZERO
var _has_previous := false
var flame_band: Polygon2D
var flame_material: ShaderMaterial

func _init() -> void:
	set_meta("boss_hazard", true)
	top_level = true

var arena_bounds: Rect2 = Rect2()

func _ready() -> void:
	var clipping := ShaderMaterial.new()
	clipping.shader = preload("res://shaders/boss_hazard_clip.gdshader")
	clipping.set_shader_parameter("arena_rect", Vector4(arena_bounds.position.x, arena_bounds.position.y, arena_bounds.size.x, arena_bounds.size.y))
	material = clipping
	flame_band = Polygon2D.new()
	flame_band.show_behind_parent = true
	flame_material = ShaderMaterial.new()
	flame_material.shader = preload("res://shaders/fire_ring_surface.gdshader")
	flame_material.set_shader_parameter("arena_rect", Vector4(arena_bounds.position.x, arena_bounds.position.y, arena_bounds.size.x, arena_bounds.size.y))
	flame_material.set_shader_parameter("opacity", VfxAtlasRenderer.setting(&"fire_ring_surface_opacity"))
	flame_band.material = flame_material
	add_child(flame_band)
	_update_flame_band()

func _physics_process(delta: float) -> void:
	if not ai_enabled or not is_finite(delta) or delta < 0.0: return
	var old := ring_radius
	ring_radius += speed * delta
	if is_instance_valid(target):
		var current := target.global_position - global_position
		var previous := previous_target if _has_previous else current
		var target_radius := float(target.get("radius")) if target.get("radius") != null else 0.0
		if not consumed and swept_band_hit(previous, current, old, ring_radius, width * 0.5 + target_radius):
			consumed = true
			hit.emit(damage)
		previous_target = current
		_has_previous = true
	if ring_radius - width * 0.5 > maximum_radius: queue_free()
	_update_flame_band()
	queue_redraw()

static func swept_band_hit(from: Vector2, to: Vector2, before: float, after: float, half_width: float) -> bool:
	if absf(from.length() - before) <= half_width or absf(to.length() - after) <= half_width: return true
	var motion := to - from
	var growth := after - before
	for edge: float in [-half_width, half_width]:
		var start_radius := before + edge
		var a := motion.length_squared() - growth * growth
		var b := 2.0 * (from.dot(motion) - start_radius * growth)
		var c := from.length_squared() - start_radius * start_radius
		if absf(a) < 0.000001:
			if absf(b) > 0.000001:
				var t := -c / b
				if t >= 0.0 and t <= 1.0 and start_radius + growth * t >= 0.0: return true
		else:
			var discriminant := b * b - 4.0 * a * c
			if discriminant >= 0.0:
				for t in [(-b - sqrt(discriminant)) / (2.0 * a), (-b + sqrt(discriminant)) / (2.0 * a)]:
					if t >= 0.0 and t <= 1.0 and start_radius + growth * t >= 0.0: return true
	return false

func _draw() -> void:
	# The full continuous exact-width band is the owned textured material below.
	# Optional Blender flames add convection detail without mechanical core arcs.
	VfxAtlasRenderer.draw_ring(self, &"fire_ring", ring_radius / maxf(0.001, speed), ring_radius, width, Color(1,1,1,VfxAtlasRenderer.setting(&"fire_ring_texture_opacity")), true)

func _update_flame_band() -> void:
	if flame_material == null: return
	var extent := ring_radius + width * .5
	flame_band.polygon = PackedVector2Array([Vector2(-extent,-extent),Vector2(extent,-extent),Vector2(extent,extent),Vector2(-extent,extent)])
	flame_material.set_shader_parameter("ring_radius", ring_radius)
	flame_material.set_shader_parameter("band_width", width)
	flame_material.set_shader_parameter("phase", ring_radius / maxf(.001, speed))
