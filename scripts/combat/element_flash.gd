class_name ElementFlash
extends Node2D
## Actual gameplay endpoints are supplied by proc dispatch. Cosmetic geometry
## never selects a target, changes blast radius, or recursively creates damage.
var definition: ElementVisualDefinition = preload("res://resources/feedback/element_visuals.tres")
var radius: float = 60.0
var kind: String = "blast"
var points := PackedVector2Array()
var color: Color = Color("ff9958")
var duration: float = 0.25
var remaining: float = 0.25
var lightning: LightningRibbon

func _ready() -> void:
	definition = definition.validated_copy()

func _prepare_lightning() -> void:
	if lightning == null and points.size() > 1:
		lightning = LightningRibbon.new()
		lightning.build(points, definition)
		var additive := CanvasItemMaterial.new()
		additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = additive

func _process(delta: float) -> void:
	if not is_finite(delta) or delta < 0.0: return
	remaining = maxf(0.0, remaining - delta)
	modulate.a = 1.0 if lightning != null else remaining / maxf(0.001, duration)
	queue_redraw()
	if remaining <= 0.0: queue_free()

func _draw() -> void:
	var progress := clampf(1.0 - remaining / maxf(0.001, duration), 0.0, 1.0)
	if points.size() > 1:
		_draw_chain(progress)
		return
	if kind == "chain": return
	var expansion := sin(minf(1.0, progress * 2.0) * PI * 0.5)
	var edge := radius * expansion
	draw_circle(Vector2.ZERO, edge, Color(color, definition.blast_fill_opacity * (1.0 - progress)))
	draw_circle(Vector2.ZERO, edge * 0.32 * (1.0 - progress), Color(definition.fire_core_color, 0.65))
	draw_arc(Vector2.ZERO, edge, 0, TAU, 48, Color(color, 0.85), 2.5, true)
	for i in range(definition.fire_sparks):
		var direction := Vector2.from_angle(float(i) * TAU / definition.fire_sparks + sin(float(i * 7)) * 0.2)
		var tip := direction * edge * (0.8 + sin(float(i * 11)) * 0.15)
		var width := radius * 0.035 * (1.0 - progress)
		draw_colored_polygon(PackedVector2Array([tip * 0.65 - direction.orthogonal() * width, tip, tip * 0.65 + direction.orthogonal() * width]), Color(color, 0.75))
		draw_line(tip * 0.72, tip * 0.9, Color(definition.fire_core_color, 0.85), 1.8, true)

func _draw_chain(progress: float) -> void:
	# Presentation saturation never suppresses a combat proc: damage has already
	# resolved independently. Prefer recent chains and omit overlapping old arcs.
	var recent_index := presentation_priority()
	if recent_index >= definition.lightning_visual_limit: return
	_prepare_lightning()
	if lightning != null: lightning.draw(self, progress, definition, recent_index < definition.lightning_detail_limit)

func presentation_priority() -> int:
	return get_parent().get_child_count() - get_index() - 1 if get_parent() != null else 0
