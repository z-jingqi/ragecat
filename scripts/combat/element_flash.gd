class_name ElementFlash
extends Node2D
## Cosmetic only: no damage callback and no child projectile generation.
var radius: float = 0.0
var kind: String = "blast"
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
		draw_circle(Vector2.ZERO, radius, Color(color, 0.055))
		draw_arc(Vector2.ZERO, radius * (1.0 - remaining / maxf(0.001, duration) * 0.65), 0, TAU, 48, color, 3.0, true)
	if points.size() > 1:
		# Ordered travel is presentation only; damage already resolved atomically.
		var progress := clampf((duration - remaining) / maxf(0.001, duration * 0.4), 0.0, 1.0)
		var path := PackedVector2Array([points[0]])
		var hops := progress * float(points.size() - 1)
		for i in range(1, points.size()):
			if hops >= float(i): path.append(points[i])
			else:
				path.append(points[i - 1].lerp(points[i], clampf(hops - float(i - 1), 0.0, 1.0)))
				break
		if path.size() > 1: draw_polyline(path, color, 2.0, true)
		for i in range(1, path.size()):
			var tip := path[i]
			draw_polyline(PackedVector2Array([tip + Vector2(-5,-5), tip + Vector2(3,-2), tip + Vector2(-2,5)]), Color(color, 0.7), 1.0, true)

