extends RefCounted
## Original procedural crystal growth, fracture, ballistic chips and settled splinters.
## Stateless: every fragment is reconstructed from site seed and age, even on seek.

static func palette() -> Dictionary:
	return {"primary": Color("53bad9"), "highlight": Color("d6fbff"), "shadow": Color("275b95")}

static func label() -> String:
	return "ICE"

static func draw_spike(canvas: Node2D, spike: Dictionary, age: float, profile: Resource) -> void:
	var rise: float = maxf(float(profile.rise_time), 0.001)
	var fracture_start: float = rise + maxf(float(profile.hold_time), 0.0)
	var collapse: float = maxf(float(profile.fade_time), 0.001)
	var collapse_end: float = fracture_start + collapse
	var residue_life: float = maxf(float(profile.residue_lifetime), 0.0)
	if age < 0.0 or age >= collapse_end + residue_life:
		return
	var anchor: Vector2 = Vector2(spike.get("pos", Vector2.ZERO)).round()
	var height: float = maxf(float(spike.get("height", 28.0)), 4.0)
	var width: float = maxf(float(spike.get("width", 13.0)), 4.0)
	var lean: float = float(spike.get("lean", 0.0))
	var variant: float = clampf(float(spike.get("variant", 0.5)), 0.0, 1.0)
	var seed_value: int = int(spike.get("seed", 0))
	var primary: Color = profile.primary
	var highlight: Color = profile.highlight
	var shadow: Color = profile.shadow
	var impact: float = clampf(float(profile.impact_strength), 0.0, 3.0)
	var progress: float = clampf(age / rise, 0.0, 1.0)
	# Fast impulse with a restrained overshoot, settling exactly to full height.
	var back: float = 0.85 * minf(impact, 1.5)
	var growth: float = 1.0 + (back + 1.0) * pow(progress - 1.0, 3.0) + back * pow(progress - 1.0, 2.0)
	var broken: bool = age >= fracture_start
	var travel: float = clampf((age - fracture_start) / collapse, 0.0, 1.0)
	var residue_age: float = maxf(age - collapse_end, 0.0)
	var residue_alpha: float = 1.0 - smoothstep(residue_life * 0.75, maxf(residue_life, 0.001), residue_age)
	var ground_alpha: float = clampf(float(profile.ground_opacity), 0.0, 1.0)
	var direction: Vector2 = spike.get("direction", Vector2(0.0, 0.5))
	# Short broken frost lines belong to the eruption, not the residual layer.
	if age < collapse_end:
		for i in range(5):
			var side: float = -1.0 if i % 2 == 0 else 1.0
			var start: Vector2 = anchor + Vector2(side * 2.0, float(posmod(seed_value + i * 3, 5)) - 2.0)
			var reach: float = width * (0.32 + float(i) * 0.12) * minf(growth * 2.0, 1.0)
			var corner: Vector2 = start + Vector2(side * reach * 0.7, side)
			canvas.draw_polyline(PackedVector2Array([start.round(), corner.round(), (start + Vector2(side * reach, -1.0)).round()]), _alpha(primary, ground_alpha * (1.0 - travel) * 0.65), 1.0, false)
	var bases: Array[Vector2] = [anchor + Vector2(-width * 0.16, -1.0), anchor, anchor + Vector2(width * 0.18, 1.0)]
	var heights: Array[float] = [height * (0.60 + variant * 0.11), height, height * (0.42 + variant * 0.12)]
	var widths: Array[float] = [width * 0.43, width * 0.62, width * 0.38]
	var leans: Array[float] = [-0.39 + lean, lean + (variant - 0.5) * 0.12, 0.42 + lean]
	var colors: Array[Color] = [primary, primary, shadow, primary, highlight]
	for branch in range(3):
		var h: float = heights[branch] * (1.0 if broken else growth)
		if h < 1.0:
			continue
		var origin: Vector2 = bases[branch]
		var w: float = widths[branch]
		var slant: float = leans[branch]
		var outline := PackedVector2Array([
			origin + Vector2(h * slant, -h),
			origin + Vector2(-w * 0.5 + h * slant * 0.17, -h * 0.22),
			origin + Vector2(-w * 0.33, 0.0),
			origin + Vector2(w * 0.33, 0.0),
			origin + Vector2(w * 0.45 + h * slant * 0.23, -h * 0.30)])
		var ridge: Vector2 = origin + Vector2(h * slant * 0.34, -h * 0.34)
		for face in range(5):
			var triangle := PackedVector2Array([outline[face], outline[(face + 1) % 5], ridge])
			if not broken:
				_polygon(canvas, triangle, _alpha(colors[face], 0.48 if face == 4 else 0.85))
			else:
				_fragment(canvas, triangle, anchor, direction, width, height, seed_value, branch * 5 + face, travel, residue_alpha, profile, colors[face], highlight)
		if not broken:
			canvas.draw_line(outline[1].round(), outline[0].round(), _alpha(highlight, 0.95), 1.0, false)
			canvas.draw_line(outline[0].round(), ridge.round(), _alpha(highlight, 0.80), 1.0, false)
	# Optional temporary chips have their own density, independent of settled shards.
	var chips: int = clampi(int(round(float(profile.debris_density) * 4.0)), 0, 12)
	if age < collapse_end:
		for i in range(chips):
			var r: float = _random(seed_value, i + 70)
			var side: float = -1.0 if i % 2 == 0 else 1.0
			var t: float = travel if broken else clampf(age / maxf(fracture_start, 0.001), 0.0, 1.0)
			var point: Vector2 = anchor + Vector2(side * width * (0.25 + t * (0.45 + r) * impact), -sin(t * PI) * height * (0.15 + r * 0.25))
			var opacity: float = sin(t * PI) * 0.9
			_polygon(canvas, PackedVector2Array([point + Vector2(0, -2), point + Vector2(2, 0), point + Vector2(-1, 1)]), _alpha(highlight, opacity))

static func _fragment(canvas: Node2D, triangle: PackedVector2Array, anchor: Vector2, direction: Vector2, width: float, height: float, seed_value: int, index: int, travel: float, residue_alpha: float, profile: Resource, color: Color, highlight: Color) -> void:
	var r: float = _random(seed_value, index + 1)
	var r2: float = _random(seed_value, index + 31)
	var impact: float = clampf(float(profile.impact_strength), 0.0, 3.0)
	var density: float = clampf(float(profile.residue_density), 0.0, 3.0)
	# Stable subset of the actual falling fragments survives as residue.
	var retained: bool = r2 < minf(density * 0.62, 1.0)
	if travel >= 1.0 and not retained:
		return
	var center: Vector2 = (triangle[0] + triangle[1] + triangle[2]) / 3.0
	var side: float = -1.0 if index % 2 == 0 else 1.0
	var target: Vector2 = anchor + Vector2(side * width * (0.20 + r * 0.85) * impact, (r2 - 0.5) * width * 0.42) + direction * width * 0.24 * impact
	# Primary flight ends at 76%; one shallow bounce then a motionless ground pose.
	var flight: float = clampf(travel / 0.76, 0.0, 1.0)
	var location: Vector2 = center.lerp(target, flight)
	location.y -= sin(flight * PI) * height * (0.14 + r * 0.12) * impact
	if travel > 0.76:
		location.y -= sin((travel - 0.76) / 0.24 * PI) * (0.6 + r * 1.0) * minf(impact, 1.5)
	var settle: float = smoothstep(0.0, 1.0, flight)
	var size: float = clampf(float(profile.residue_size), 0.0, 3.0)
	var scale_x: float = lerpf(1.0, 0.48 * size, settle)
	var scale_y: float = lerpf(1.0, 0.16 * size, settle)
	var rotation: float = side * (0.30 + r * 0.75) * settle
	var points := PackedVector2Array()
	for vertex in triangle:
		var local: Vector2 = (vertex - center).rotated(rotation)
		points.append((location + Vector2(local.x * scale_x, local.y * scale_y)).round())
	var opacity: float = 0.9
	if retained:
		opacity *= lerpf(1.0, clampf(float(profile.ground_opacity), 0.0, 1.0) * residue_alpha, smoothstep(0.76, 1.0, travel))
	else:
		opacity *= 1.0 - smoothstep(0.72, 1.0, travel)
	_polygon(canvas, points, _alpha(color, opacity))
	# A bright broken edge keeps the fragments crystalline at native pixel scale.
	canvas.draw_line(points[0], points[1], _alpha(highlight, opacity * 0.86), 1.0, false)

static func _polygon(canvas: Node2D, points: PackedVector2Array, color: Color) -> void:
	var rounded := PackedVector2Array()
	for point in points:
		rounded.append(point.round())
	# Pixel rounding can collapse tiny triangles; never submit degenerate polygons.
	if absf((rounded[1] - rounded[0]).cross(rounded[2] - rounded[0])) >= 0.5:
		canvas.draw_colored_polygon(rounded, color)

static func _random(seed_value: int, salt: int) -> float:
	return fposmod(sin(float(posmod(seed_value, 997) + salt * 31) * 1.713) * 213.43, 1.0)

static func _alpha(color: Color, opacity: float) -> Color:
	return Color(color.r, color.g, color.b, color.a * clampf(opacity, 0.0, 1.0))
