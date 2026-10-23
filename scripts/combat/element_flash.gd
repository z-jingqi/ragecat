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

func _ready() -> void:
	definition = definition.validated_copy()

func _process(delta: float) -> void:
	if not is_finite(delta) or delta < 0.0: return
	remaining = maxf(0.0, remaining - delta)
	modulate.a = remaining / maxf(0.001, duration)
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
	var visible_segments := clampf(progress / maxf(0.05, definition.chain_reveal_fraction), 0.0, 1.0) * (points.size() - 1)
	for i in range(points.size() - 1):
		var fraction := clampf(visible_segments - i, 0.0, 1.0)
		if fraction <= 0.0: break
		var end := points[i].lerp(points[i + 1], fraction)
		var path := ElementGeometry.bolt(points[i], end, definition, i)
		draw_polyline(path, Color(color, 0.4), definition.bolt_outline_width, true)
		draw_polyline(path, Color("fff9df"), definition.bolt_core_width, true)
		if fraction >= 1.0:
			draw_circle(end, definition.bolt_endpoint_radius, Color(color, 0.55))
			draw_circle(end, definition.bolt_endpoint_radius * 0.4, Color.WHITE)
