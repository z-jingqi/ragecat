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
var size_factor: float = 1.0
var critical: bool = false

func _process(delta: float) -> void:
	remaining = maxf(0.0, remaining - delta)
	modulate.a = 1.0 if VfxAtlasRenderer.available(_atlas_key()) else remaining / maxf(0.001, duration)
	queue_redraw()
	if remaining <= 0.0: queue_free()

func _atlas_key() -> StringName:
	match kind:
		"death": return &"death_smoke"
		"shield_break": return &"shield_break"
		"shatter": return &"ice_shatter"
		"thaw": return &"ice_thaw"
		"shock": return &"lightning_impact"
	return &""

func _draw() -> void:
	var progress := 1.0 - remaining / maxf(0.001, duration)
	var atlas_radius := radius + definition.shell_padding if kind in ["shatter", "thaw"] else radius + travel
	if kind in ["death", "shield_break"]: atlas_radius = radius * size_factor
	var tint := color if kind in ["death", "shield_break"] else Color.WHITE
	if VfxAtlasRenderer.draw_clip(self, _atlas_key(), progress, Rect2(Vector2.ONE * -atlas_radius, Vector2.ONE * atlas_radius * 2.0), tint, false, true): return
	if kind == "death":
		# Asset-unavailable fallback remains smoke, never actor fragments.
		for i in range(5):
			var axis := Vector2.from_angle(float(i) * 2.4)
			var center := axis * radius * progress * 0.8 + Vector2.UP * radius * progress * 0.4
			for layer in range(4, 0, -1):
				draw_circle(center, radius * (0.25 + progress * 0.3) * float(layer) / 4.0, Color(color, 0.035))
		return
	elif kind == "shield_break":
		for i in range(7):
			var axis := Vector2.from_angle(float(i) * TAU / 7.0)
			var center := axis * radius * (0.65 + progress * 0.7)
			draw_line(center, center + axis.orthogonal() * 3.0, Color(color, 0.6), 1.0, true)
		return
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
		# Brief disconnected ion wisps, not a misleading circular hit area.
		for side in [-1.0, 1.0]:
			var origin := Vector2(side * (radius + 2.0), -radius * 0.45)
			var path := PackedVector2Array([origin + Vector2(0, -5), origin + Vector2(side * 3, 0), origin + Vector2(-side * 1.5, 4), origin + Vector2(side * 2, 9)])
			draw_polyline(path, Color(color, 0.75), 1.0, true)
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

