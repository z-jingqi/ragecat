class_name FeedbackVisual
extends Node2D
## Pure cosmetic geometry. No actor, collision, status, target or damage callbacks.
var definition: ElementVisualDefinition = preload("res://resources/feedback/element_visuals.tres")
var kind: String = "impact"
var color := Color.WHITE
var duration: float = 0.1
var remaining: float = 0.1
var directions := PackedVector2Array()
var travel: float = 22.0
var radius: float = 16.0
var actor_style: String = "mob"
var variant: int = 0
var critical: bool = false

func _process(delta: float) -> void:
	remaining = maxf(0.0, remaining - delta)
	modulate.a = remaining / maxf(0.001, duration)
	queue_redraw()
	if remaining <= 0.0: queue_free()

func _draw() -> void:
	var progress := 1.0 - remaining / maxf(0.001, duration)
	if kind == "death":
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * (1.0 - progress * 0.65))
		_draw_snapshot()
		draw_set_transform(Vector2.ZERO)
	elif kind == "mark" or (kind == "shatter" and progress < 0.25):
		var size := radius + 5.0 + progress * (12.0 if kind == "shatter" else 5.0)
		var points := PackedVector2Array()
		for i in range(6): points.append(Vector2.from_angle(i * TAU / 6.0 - PI * 0.5) * size)
		points.append(points[0])
		draw_polyline(points, Color(color, 0.8), 1.5, true)
		if kind == "shatter":
			for i in range(3):
				var tip := Vector2.from_angle(i * TAU / 3.0) * size
				draw_polyline(PackedVector2Array([Vector2.ZERO, tip * 0.35 + tip.orthogonal() * 0.12, tip]), color, 1.5, true)
	elif kind == "shock":
		draw_arc(Vector2.ZERO, radius + 5, progress * TAU, progress * TAU + PI, 12, color, 1.5, true)
	# Sparks travel directionally; a tiny center cross, never a filled screen disk.
	for axis in directions:
		var start := axis * (3.0 + progress * travel)
		var end := start + axis * (4.0 * (1.0 - progress) + 1.0)
		if kind in ["thaw", "mark_expire"]:
			draw_circle(start + Vector2(0, progress * 5.0), 1.3 * (1.0 - progress), Color(color, 0.5))
		elif kind == "shatter":
			var shard := axis.normalized()
			var center := axis * (radius * 0.65 + progress * travel) + Vector2(0, progress * progress * 10.0)
			var size := 4.0 * (1.0 - progress * 0.5)
			draw_colored_polygon(PackedVector2Array([center - shard * size, center + shard.orthogonal() * size * 0.7, center + shard * size, center - shard.orthogonal() * size * 0.4]), Color(color, 0.85))
			draw_line(center - shard * size, center + shard * size, Color.WHITE, 1.0, true)
		elif kind in ["freeze", "mark"]:
			draw_colored_polygon(PackedVector2Array([start, end + axis.orthogonal() * 2.0, end + axis * 3.0, end - axis.orthogonal() * 2.0]), color)
		else:
			draw_line(start, end, color, 2.2 if critical else 1.4, true)

func _draw_snapshot() -> void:
	# Captured silhouette data, not a duplicate enemy with live AI or signals.
	if actor_style == "ranged":
		draw_colored_polygon(PackedVector2Array([Vector2(0,-radius*1.4),Vector2(radius,0),Vector2(0,radius),Vector2(-radius,0)]), color)
		draw_circle(Vector2.ZERO, radius * 0.35, Color("192d3e"))
	elif actor_style == "boss":
		draw_circle(Vector2(0, 4), 31, color.darkened(0.18))
		draw_circle(Vector2(0, -8), 29, color)
		for side in [-1.0, 1.0]:
			draw_circle(Vector2(side * 16, 25), 11, color)
			draw_colored_polygon(PackedVector2Array([Vector2(side*28,-14),Vector2(side*24,-44),Vector2(side*7,-28)]),color)
			draw_circle(Vector2(side * 12,-12),5,Color("ffe6a4"))
	else:
		if variant % 2 == 0:
			for side in [-1.0, 1.0]:
				draw_colored_polygon(PackedVector2Array([Vector2(side*6,-5),Vector2(side*27,-16),Vector2(side*24,8),Vector2(side*10,5)]),color.darkened(0.25))
				draw_colored_polygon(PackedVector2Array([Vector2(side*10,-6),Vector2(side*8,-20),Vector2(side,-10)]),color)
			draw_circle(Vector2.ZERO, radius * 0.78, color)
		else: draw_circle(Vector2.ZERO, radius, color)
		for side in [-1.0, 1.0]: draw_circle(Vector2(side*5,-2),3.5,Color("191c35"))
