class_name ElementStatusVisual
extends Node2D
## Actor-local presentation, never the owner of status durations or damage.
var definition: ElementVisualDefinition = preload("res://resources/feedback/element_visuals.tres")
var actor: WeakRef
var freeze_coverage: float = 0.0
var frost_amount: float = 0.0
var _sprite: WeakRef
var _sprite_material: ShaderMaterial
var _original_material: Material

func setup(enemy: EnemyActor, settings: ElementVisualDefinition = null) -> void:
	actor = weakref(enemy)
	if settings != null: definition = settings
	definition = definition.validated_copy()
	z_index = 1

func bind_sprite(sprite: Sprite2D) -> void:
	unbind_sprite()
	_sprite = weakref(sprite)
	_original_material = sprite.material
	_sprite_material = ShaderMaterial.new()
	_sprite_material.shader = preload("res://shaders/frost_overlay.gdshader")
	sprite.material = _sprite_material
	_sync_sprite()

func unbind_sprite() -> void:
	if _sprite != null:
		var sprite := _sprite.get_ref() as Sprite2D
		if sprite != null and sprite.material == _sprite_material: sprite.material = _original_material
	_sprite = null
	_sprite_material = null
	_original_material = null

func _exit_tree() -> void:
	unbind_sprite()

func _process(delta: float) -> void:
	if actor == null: return
	var enemy := actor.get_ref() as EnemyActor
	if enemy == null or enemy.is_dead: return
	if not is_finite(delta) or delta < 0.0: return
	var frozen := enemy.status.is_frozen()
	# Ending freeze immediately removes the shell. Independent FeedbackVisual
	# owns either shatter or thaw, so early hits never finish an old growth tween.
	if frozen:
		freeze_coverage = minf(1.0, freeze_coverage + delta / definition.freeze_growth_duration)
	else:
		freeze_coverage = 0.0
	frost_amount = clampf(float(enemy.status.frost_stacks) / definition.frost_visual_stack_scale, 0.0, 1.0)
	visible = enemy.cosmetic_feedback_enabled
	_sync_sprite()
	queue_redraw()

func _sync_sprite() -> void:
	if _sprite_material == null: return
	_sprite_material.set_shader_parameter("freeze_coverage", freeze_coverage if visible else 0.0)
	_sprite_material.set_shader_parameter("frost_amount", frost_amount if visible else 0.0)
	_sprite_material.set_shader_parameter("frost_color", definition.ice_color)

func _draw() -> void:
	if actor == null or _sprite != null: return
	var enemy := actor.get_ref() as EnemyActor
	if enemy == null or enemy.is_dead or not enemy.cosmetic_feedback_enabled: return
	var r := enemy.radius + definition.shell_padding
	if frost_amount > 0.0:
		for i in range(definition.crystal_sides):
			var angle := TAU * float(i) / definition.crystal_sides
			var at := Vector2.from_angle(angle) * enemy.radius * 0.8
			draw_line(at, at + Vector2.UP * (3.0 + frost_amount * 4.0), Color(definition.ice_color, definition.frost_opacity + frost_amount * 0.4), 1.2, true)
	if freeze_coverage <= 0.0: return
	var polygon := PackedVector2Array()
	for i in range(definition.crystal_sides):
		polygon.append(Vector2.from_angle(float(i) * TAU / definition.crystal_sides - PI * 0.5) * r)
	# Clip crystal against a rising horizontal frost front, not scale the entire
	# shell. Small facets add a grainy leading edge with deterministic geometry.
	var front := r - 2.0 * r * freeze_coverage
	var clipped := _clip_above(polygon, front)
	if clipped.size() >= 3:
		draw_colored_polygon(clipped, Color(definition.ice_color, definition.ice_opacity))
		clipped.append(clipped[0])
		draw_polyline(clipped, Color(definition.ice_color, 0.85), 1.5, true)
		for i in range(definition.crystal_sides):
			var point := polygon[i]
			if point.y >= front:
				draw_line(Vector2(0, maxf(front, r * 0.1)), point, Color.WHITE * Color(1, 1, 1, 0.35), 1.0, true)

static func _clip_above(polygon: PackedVector2Array, front: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i in range(polygon.size()):
		var a := polygon[i]
		var b := polygon[(i + 1) % polygon.size()]
		if a.y >= front: result.append(a)
		if (a.y >= front) != (b.y >= front):
			result.append(a.lerp(b, (front - a.y) / (b.y - a.y)))
	return result
