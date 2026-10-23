class_name ElementGeometry
extends RefCounted
## Deterministic visual noise avoids consuming combat RNG or jittering endpoints.
static func bolt(start: Vector2, end: Vector2, settings: ElementVisualDefinition, salt: int) -> PackedVector2Array:
	var points := PackedVector2Array([start])
	var delta := end - start
	var normal := delta.normalized().orthogonal()
	# Unevenly spaced bends, correlated broad displacement and smaller sharp kinks.
	# Pure arithmetic noise: never advances either combat or global random state.
	for i in range(1, settings.bolt_segments):
		var unit := float(i) / settings.bolt_segments
		var fraction := unit + sin(float(i * 19 + salt * 13)) * 0.24 / settings.bolt_segments
		var noise := sin(float(i * 7 + salt * 31)) * 0.65 + sin(unit * 11.0 + salt) * 0.55
		points.append(start.lerp(end, fraction) + normal * noise * minf(settings.bolt_jitter, delta.length() * 0.18) * sin(fraction * PI))
	points.append(end)
	return points

static func draw_burn(canvas: Node2D, center: Vector2, radius: float, age: float, color: Color, settings: ElementVisualDefinition) -> void:
	var size := Vector2.ONE * (radius * 2.0 + settings.burn_height)
	if VfxAtlasRenderer.draw_clip(canvas, &"fire_loop", age, Rect2(center - size * 0.5 + Vector2(0, -radius * 0.55), size)): return
	for i in range(settings.burn_flames):
		var phase := float(i) / settings.burn_flames
		var x := (phase * 2.0 - 1.0) * radius * 0.8
		var base := center + Vector2(x, radius * 0.4)
		var height := settings.burn_height * (0.75 + 0.25 * sin(age * settings.burn_flicker_speed + i * 2.3))
		var tip := base + Vector2(sin(age * 4.0 + i) * 3.0, -height)
		canvas.draw_colored_polygon(PackedVector2Array([base + Vector2(-3, 0), tip, base + Vector2(3, 0)]), Color(color, 0.75))
		canvas.draw_line(base, base.lerp(tip, 0.55), Color(settings.fire_core_color, 0.9), 1.6, true)
