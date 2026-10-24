class_name ArrowPresentation
extends Node2D
## One compact ribbon and one material-preserving sprite per arrow. No RNG,
## damage, physics, particles, timers, global trail pool or detached remnants.
@export var definition: ArrowVisualDefinition = preload("res://resources/projectiles/bow_visual.tres")
var arrow: BowArrow
var points: Array[Vector2] = []
var ages: Array[float] = []
var owns_trail := false
static var active_trails := 0

func _ready() -> void:
	arrow = get_parent() as BowArrow
	if arrow == null: return
	if definition == null: definition = preload("res://resources/projectiles/bow_visual.tres")
	definition = definition.validated_copy()
	arrow.presentation_changed.connect(_sync_offset)
	# Run after Archer presentation (priority 20), so its bounded muzzle
	# handoff is already known before sampling the rendered tail.
	process_physics_priority = 100
	owns_trail = active_trails < definition.trail_visual_limit
	if owns_trail: active_trails += 1
	_sync_offset()

func _exit_tree() -> void:
	if owns_trail: active_trails = maxi(0, active_trails - 1)
	points.clear()
	ages.clear()

func _sync_offset() -> void:
	position = Vector2.ZERO
	if arrow.presentation_blend_distance > 0.0:
		position = arrow.presentation_origin_offset.rotated(-arrow.rotation) * (1.0 - clampf(arrow.traveled / arrow.presentation_blend_distance, 0.0, 1.0))

func _physics_process(delta: float) -> void:
	if not is_instance_valid(arrow) or arrow.retired: return
	_sync_offset()
	if owns_trail and delta > 0.0:
		var tip := to_global(definition.tail_position)
		var scale_factor := _trail_scale()
		if not points.is_empty() and points[-1].distance_to(tip) > definition.trail_max_length * 2.0:
			points.clear()
			ages.clear()
		for i in range(ages.size()): ages[i] += delta
		while not ages.is_empty() and (ages[0] > definition.trail_duration or points[0].distance_to(tip) > definition.trail_max_length * scale_factor):
			ages.pop_front()
			points.pop_front()
		if points.is_empty() or points[-1].distance_squared_to(tip) > 0.01:
			points.append(tip)
			ages.append(0.0)
		while not points.is_empty() and points.size() > definition.trail_point_limit:
			points.pop_front()
			ages.pop_front()
	queue_redraw()

func _trail_scale() -> float:
	if is_instance_valid(arrow.gravity_field): return definition.gravity_trail_scale
	return definition.fragment_trail_scale if arrow.secondary else 1.0

func _draw() -> void:
	if not is_instance_valid(arrow) or arrow.retired: return
	var color := definition.tint(arrow.visual_element)
	if points.size() > 1:
		var ribbon := PackedVector2Array()
		var colors := PackedColorArray()
		for side in [1.0, -1.0]:
			for j in range(points.size()):
				var i := j if side > 0.0 else points.size() - 1 - j
				var freshness := clampf(1.0 - ages[i] / definition.trail_duration, 0.0, 1.0)
				var taper := float(i) / float(points.size() - 1)
				var local_point := to_local(points[i])
				ribbon.append(local_point + Vector2(0, side * definition.trail_width * 0.5 * taper * _trail_scale()))
				var tint := color
				tint.a = freshness * taper * definition.trail_opacity
				colors.append(tint)
		draw_polygon(ribbon, colors)
	if definition.base_texture != null: draw_texture_rect(definition.base_texture, definition.sprite_rect, false)
	if not arrow.visual_element.is_empty() and definition.accent_texture != null:
		color.a = definition.accent_opacity
		draw_texture_rect(definition.accent_texture, definition.sprite_rect, false, color)
