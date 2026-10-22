class_name ElementFlash
extends Node2D
## Cosmetic only: no damage callback and no child projectile generation.
var radius: float = 0.0
var points: PackedVector2Array = []
var color: Color = Color.WHITE
var duration: float = 0.25
var remaining: float = 0.25
func _process(delta: float) -> void:
	remaining -= delta
	modulate.a = maxf(0, remaining / maxf(0.01, duration))
	queue_redraw()
	if remaining <= 0: queue_free()
func _draw() -> void:
	if radius > 0:
		draw_circle(Vector2.ZERO, radius, Color(color, 0.12))
		draw_arc(Vector2.ZERO, radius * (1.0 - remaining / duration * 0.2), 0, TAU, 48, color, 3.0, true)
	if points.size() > 1: draw_polyline(points, color, 3.0, true)
