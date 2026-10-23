class_name ElementGeometry
extends RefCounted
## Deterministic visual noise avoids consuming combat RNG or jittering endpoints.
static func bolt(start: Vector2, end: Vector2, settings: ElementVisualDefinition, salt: int) -> PackedVector2Array:
	var points := PackedVector2Array([start])
	var normal := (end - start).normalized().orthogonal()
	for i in range(1, settings.bolt_segments):
		var fraction := float(i) / settings.bolt_segments
		var noise := (-1.0 if i % 2 == 0 else 1.0) * (0.6 + 0.4 * absf(sin(float(i * 31 + salt * 17))))
		points.append(start.lerp(end, fraction) + normal * noise * settings.bolt_jitter * sin(fraction * PI))
	points.append(end)
	return points

static func draw_burn(canvas: Node2D, center: Vector2, radius: float, age: float, color: Color, settings: ElementVisualDefinition) -> void:
	for i in range(settings.burn_flames):
		var phase := float(i) / settings.burn_flames
		var x := (phase * 2.0 - 1.0) * radius * 0.8
		var base := center + Vector2(x, radius * 0.4)
		var height := settings.burn_height * (0.75 + 0.25 * sin(age * settings.burn_flicker_speed + i * 2.3))
		var tip := base + Vector2(sin(age * 4.0 + i) * 3.0, -height)
		canvas.draw_colored_polygon(PackedVector2Array([base + Vector2(-3, 0), tip, base + Vector2(3, 0)]), Color(color, 0.75))
		canvas.draw_line(base, base.lerp(tip, 0.55), Color(settings.fire_core_color, 0.9), 1.6, true)
