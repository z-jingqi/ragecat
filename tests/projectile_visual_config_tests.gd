extends SceneTree
## Malformed authoring data may degrade presentation, never hang the game or
## put nonfinite/zero-divisor uniforms into the projectile renderer.
class BareBullet extends EnemyBullet:
	func _ready() -> void:
		pass

var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("PROJECTILE VISUAL CONFIG: " + label)

func check_unchanged(source: Resource, copy: Resource) -> void:
	check(source != copy, "Validation creates a private settings snapshot")
	for property in source.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_STORAGE:
			check(source.get(property.name) == copy.get(property.name), "Valid default remains unchanged: " + property.name)

func check_arrow_ranges(value: ArrowVisualDefinition) -> void:
	check(value.trail_point_limit >= 2 and value.trail_point_limit <= 12, "Trail point capacity is bounded")
	check(value.trail_visual_limit >= 1 and value.trail_visual_limit <= 1000, "Trail budget is bounded")
	check(is_finite(value.trail_duration) and value.trail_duration >= 0.01 and value.trail_duration <= 0.2, "Trail duration is positive finite")
	check(is_finite(value.trail_width) and value.trail_width >= 0.1 and value.trail_width <= 4.0, "Trail width is finite and bounded")
	check(is_finite(value.trail_max_length) and value.trail_max_length >= 0.0 and value.trail_max_length <= 80.0, "Trail length is finite and bounded")
	for key in ["accent_opacity", "dark_palette_mix", "trail_opacity", "secondary_trail_scale", "gravity_trail_scale"]:
		check(is_finite(float(value.get(key))) and float(value.get(key)) >= 0.0 and float(value.get(key)) <= 1.0, "Normalized visual parameter: " + key)
	check(value.sprite_rect.position.is_finite() and value.sprite_rect.size.is_finite() and value.sprite_rect.size.x > 0.0 and value.sprite_rect.size.y > 0.0, "Sprite rectangle is valid")
	check(value.tail_position.is_finite(), "Tail attachment is finite")
	check(is_finite(value.dark_tint.r) and is_finite(value.dark_tint.g) and is_finite(value.dark_tint.b) and is_finite(value.dark_tint.a), "Dark tint is finite")
	check(value.base_texture != null, "Arrow always has a body texture")

func check_fireball_ranges(value: FireballVisualDefinition) -> void:
	check(value.texture != null, "Fireball always has a real atlas")
	check(value.atlas_grid.x > 0 and value.atlas_grid.y > 0, "Atlas grid has no zero/negative divisor")
	check(value.frame_count >= 1 and value.frame_count <= mini(120,value.atlas_grid.x*value.atlas_grid.y), "Frame count fits grid")
	check(value.texture.get_width() % value.atlas_grid.x == 0 and value.texture.get_height() % value.atlas_grid.y == 0, "Grid divides texture into complete frames")
	check(is_finite(value.frames_per_second) and value.frames_per_second >= 1.0 and value.frames_per_second <= 120.0, "Playback rate is bounded and finite")
	check(is_finite(value.surface_opacity) and value.surface_opacity >= 0.0 and value.surface_opacity <= 1.0, "Fireball opacity is bounded and finite")
	check(value.bounds_in_radii.position.is_finite() and value.bounds_in_radii.size.is_finite() and value.bounds_in_radii.size.x > 0.0 and value.bounds_in_radii.size.y > 0.0, "Fireball mapping is finite with positive dimensions")

func run() -> void:
	var arrow_default := load("res://resources/projectiles/bow_visual.tres") as ArrowVisualDefinition
	var fireball_default := load("res://resources/projectiles/enemy_fireball.tres") as FireballVisualDefinition
	var arrow_copy := arrow_default.validated_copy()
	var fireball_copy := fireball_default.validated_copy()
	check_unchanged(arrow_default,arrow_copy)
	check_unchanged(fireball_default,fireball_copy)
	check(arrow_copy.base_texture == arrow_default.base_texture and arrow_copy.accent_texture == arrow_default.accent_texture and arrow_copy.palette == arrow_default.palette, "Arrow textures and shared damage palette are not duplicated")
	check(fireball_copy.texture == fireball_default.texture, "Atlas texture remains shared")
	for poison in [NAN,INF,-INF,-1000000.0,0.0,1000000.0]:
		var value := arrow_default.duplicate(false) as ArrowVisualDefinition
		for key in ["accent_opacity","dark_palette_mix","trail_max_length","trail_duration","trail_width","trail_opacity","secondary_trail_scale","gravity_trail_scale"]:
			value.set(key,poison)
		value.sprite_rect = Rect2(Vector2(poison,poison),Vector2.ZERO)
		value.tail_position = Vector2(poison,poison)
		value.dark_tint = Color(poison,poison,poison,poison)
		check_arrow_ranges(value.validated_copy())
		var flame := FireballVisualDefinition.new()
		flame.frames_per_second = poison
		flame.surface_opacity = poison
		flame.bounds_in_radii = Rect2(Vector2(poison,poison),Vector2.ZERO)
		check_fireball_ranges(flame.validated_copy())
	for limit in [-2147483648,-1,0,1,999999]:
		var value := arrow_default.duplicate(false) as ArrowVisualDefinition
		value.trail_point_limit = limit
		value.trail_visual_limit = limit
		var safe := value.validated_copy()
		check_arrow_ranges(safe)
		check(value.trail_point_limit == limit and value.trail_visual_limit == limit, "Validation never mutates authored arrow resource")
	var missing := ArrowVisualDefinition.new()
	check_arrow_ranges(missing.validated_copy())
	check(missing.validated_copy().tint("fire") == Color.WHITE, "Optional missing palette retains safe white tint")
	for mode in ["null_texture","zero_grid","negative_grid","huge_grid","partial_cells","zero_frames","negative_frames","overflow_frames"]:
		var bad := FireballVisualDefinition.new()
		bad.bounds_in_radii = Rect2(-200,-200,400,400)
		match mode:
			"null_texture": bad.texture = null
			"zero_grid": bad.atlas_grid = Vector2i(0,4)
			"negative_grid": bad.atlas_grid = Vector2i(-1,4)
			"huge_grid": bad.atlas_grid = Vector2i(2147483647,2147483647)
			"partial_cells": bad.atlas_grid = Vector2i(7,4)
			"zero_frames": bad.frame_count = 0
			"negative_frames": bad.frame_count = -3
			"overflow_frames": bad.frame_count = 33
		var safe := bad.validated_copy()
		check_fireball_ranges(safe)
		check(safe.texture == fireball_default.texture and safe.atlas_grid == fireball_default.atlas_grid and safe.frame_count == fireball_default.frame_count and safe.bounds_in_radii == fireball_default.bounds_in_radii, "Broken atlas contract falls back as one matching set: " + mode)
	var custom := FireballVisualDefinition.new()
	custom.texture = ImageTexture.create_from_image(Image.create(8,8,false,Image.FORMAT_RGBA8))
	custom.atlas_grid = Vector2i(2,2)
	custom.frame_count = 4
	custom.bounds_in_radii = Rect2(-2,-1,3,2)
	check_unchanged(custom,custom.validated_copy())
	var initial_budget := ArrowPresentation.active_trails
	for use_null in [false,true]:
		var arrow := load("res://scenes/projectiles/bow_arrow.tscn").instantiate() as BowArrow
		arrow.position = Vector2(300,300)
		arrow.arena_bounds = Rect2(0,0,2000,2000)
		var visual := arrow.get_node("Presentation") as ArrowPresentation
		visual.definition = null if use_null else arrow_default.duplicate(false) as ArrowVisualDefinition
		if not use_null: visual.definition.trail_point_limit = -1
		root.add_child(arrow)
		arrow.set_physics_process(false)
		visual.set_physics_process(false)
		check_arrow_ranges(visual.definition)
		for tick in range(8):
			arrow._physics_process(1.0/60.0)
			visual._physics_process(1.0/60.0)
		check(visual.points.size() <= visual.definition.trail_point_limit, "Malformed source cannot hang the bounded trim loop")
		# Defensive protection also survives a debugger changing the live copy.
		visual.definition.trail_point_limit = -1
		visual._physics_process(1.0/60.0)
		check(visual.points.is_empty() and visual.ages.is_empty(), "Negative live point cap exits instead of looping on empty arrays")
		arrow.free()
	check(ArrowPresentation.active_trails == initial_budget, "Fallback arrows release their visual budget")
	for use_null in [false,true]:
		var bullet := BareBullet.new()
		bullet.definition = SpitterDefinition.new()
		bullet.set_physics_process(false)
		var visual := FireballPresentation.new()
		visual.definition = null if use_null else FireballVisualDefinition.new()
		if not use_null:
			visual.definition.atlas_grid = Vector2i.ZERO
			visual.definition.frames_per_second = NAN
			visual.definition.texture = null
		bullet.add_child(visual)
		root.add_child(bullet)
		bullet.set_physics_process(false)
		visual.set_physics_process(false)
		check_fireball_ranges(visual.definition)
		bullet.traveled = 24.0
		visual._physics_process(0.1)
		check(is_finite(float(visual.surface.get_shader_parameter("phase"))), "Malformed source cannot send nonfinite phase to shader")
		check(visual.surface.get_shader_parameter("atlas_grid") == Vector2(8,4) and visual.surface.get_shader_parameter("frame_count") == 32.0 and visual.surface.get_shader_parameter("flame_atlas") != null, "Renderer submits a coherent fallback atlas")
		bullet.free()
	print("PROJECTILE_VISUAL_CONFIG: %d checks, %d failures" % [checks,failures])
	quit(failures)
