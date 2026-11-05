extends RefCounted
## Original code-drawn ice: three asymmetric, faceted crystals and broken frost.
## Stateless: all animation is evaluated from individual spawn age, including seeks.

static func palette() -> Dictionary:
	return {"primary": Color("53bad9"), "highlight": Color("d6fbff"), "shadow": Color("275b95")}

static func label() -> String:
	return "ICE"

static func draw_spike(canvas: Node2D, spike: Dictionary, age: float, profile: Resource) -> void:
	var rise_time: float = maxf(float(profile.rise_time), 0.001)
	var hold_time: float = maxf(float(profile.hold_time), 0.0)
	var fade_time: float = maxf(float(profile.fade_time), 0.001)
	var life: float = rise_time + hold_time + fade_time
	if age < 0.0 or age >= life:
		return
	var growth: float = clampf(age / rise_time, 0.0, 1.0)
	growth = 1.0 - pow(1.0 - growth, 3.0)
	var melt: float = clampf((age - rise_time - hold_time) / fade_time, 0.0, 1.0)
	var visibility: float = 1.0 - melt
	var anchor: Vector2 = spike.get("pos", Vector2.ZERO)
	anchor = anchor.round()
	var height: float = maxf(float(spike.get("height", 28.0)), 4.0)
	var width: float = maxf(float(spike.get("width", 13.0)), 4.0)
	var lean: float = float(spike.get("lean", 0.0))
	var variant: float = clampf(float(spike.get("variant", 0.5)), 0.0, 1.0)
	var seed_value: int = int(spike.get("seed", 0))
	var primary: Color = profile.primary
	var highlight: Color = profile.highlight
	var shadow: Color = profile.shadow
	var ground_alpha: float = clampf(float(profile.ground_opacity), 0.0, 1.0) * visibility
	var ground_scale: float = minf(growth * 2.0, 1.0)
	# Broken ground splinters, never a disc, halo, or full impact ring.
	for i in range(5):
		var direction: float = -1.0 if i % 2 == 0 else 1.0
		var reach: float = width * (0.32 + float(i) * 0.12) * ground_scale
		var y: float = -2.0 + float((i * 3 + seed_value) % 5)
		var start: Vector2 = anchor + Vector2(direction * 2.0, y)
		var corner: Vector2 = anchor + Vector2(direction * reach * 0.7, y + direction)
		var end: Vector2 = anchor + Vector2(direction * reach, y - 1.0)
		canvas.draw_polyline(PackedVector2Array([start.round(), corner.round(), end.round()]), _alpha(primary, ground_alpha * 0.65), 1.0, false)
		if i % 2 == 0:
			canvas.draw_line(corner.round(), (corner + Vector2(direction * 2.0, 2.0)).round(), _alpha(highlight, ground_alpha * 0.45), 1.0, false)
	# Rear branch, tall central prism, then the short front branch.
	var fade_height: float = 1.0 - melt * 0.12
	_crystal(canvas, anchor + Vector2(-width * 0.16, -1.0), height * (0.60 + variant * 0.11) * growth * fade_height, width * 0.43, -0.39 + lean, primary, highlight, shadow, visibility * 0.86)
	_crystal(canvas, anchor, height * growth * fade_height, width * 0.62, lean + (variant - 0.5) * 0.12, primary, highlight, shadow, visibility)
	var branch_growth: float = clampf((growth - 0.10) / 0.90, 0.0, 1.0)
	_crystal(canvas, anchor + Vector2(width * 0.18, 1.0), height * (0.42 + variant * 0.12) * branch_growth * fade_height, width * 0.38, 0.42 + lean, primary, highlight, shadow, visibility * 0.94)
	# Chipped ice travels only a few pixels. Sparse deterministic crystal flecks.
	var debris_count: int = clampi(int(round(float(profile.debris_density) * 3.0)), 0, 8)
	for i in range(debris_count):
		var salt: float = float(seed_value % 997 + i * 31)
		var phase: float = fposmod(sin(salt * 1.713) * 213.43, 1.0)
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var travel: float = clampf(age / (rise_time + 0.22), 0.0, 1.0)
		var shard_alpha: float = visibility * (1.0 - travel) * 0.85
		if melt > 0.0:
			travel = melt
			shard_alpha = sin(melt * PI) * 0.60
		var origin: Vector2 = anchor + Vector2(side * width * (0.25 + phase * 0.35), -height * (0.12 + phase * 0.45) * growth)
		var point: Vector2 = (origin + Vector2(side * travel * 5.0, -sin(travel * PI) * 4.0 + melt * 6.0)).round()
		canvas.draw_colored_polygon(PackedVector2Array([point + Vector2(0, -2), point + Vector2(1, 0), point + Vector2(0, 2), point + Vector2(-1, 0)]), _alpha(highlight, shard_alpha))

static func _crystal(canvas: Node2D, origin: Vector2, height: float, width: float, lean: float, primary: Color, highlight: Color, shadow: Color, opacity: float) -> void:
	if height < 1.0 or opacity <= 0.0:
		return
	var tip: Vector2 = (origin + Vector2(height * lean, -height)).round()
	var left: Vector2 = (origin + Vector2(-width * 0.5 + height * lean * 0.17, -height * 0.22)).round()
	var right: Vector2 = (origin + Vector2(width * 0.45 + height * lean * 0.23, -height * 0.30)).round()
	var foot_left: Vector2 = (origin + Vector2(-width * 0.33, 0)).round()
	var foot_right: Vector2 = (origin + Vector2(width * 0.33, 0)).round()
	var ridge: Vector2 = (origin + Vector2(height * lean * 0.34, -height * 0.34)).round()
	var foot: Vector2 = origin.round()
	canvas.draw_colored_polygon(PackedVector2Array([tip, left, foot_left, foot, ridge]), _alpha(primary, opacity * 0.80))
	canvas.draw_colored_polygon(PackedVector2Array([tip, ridge, foot, foot_right, right]), _alpha(shadow, opacity * 0.75))
	canvas.draw_colored_polygon(PackedVector2Array([tip, ridge, right]), _alpha(primary, opacity * 0.76))
	canvas.draw_colored_polygon(PackedVector2Array([left, ridge, foot]), _alpha(highlight, opacity * 0.27))
	canvas.draw_line(left, tip, _alpha(highlight, opacity * 0.95), 1.0, false)
	canvas.draw_line(tip, ridge, _alpha(highlight, opacity * 0.76), 1.0, false)
	canvas.draw_line(ridge, foot, _alpha(primary, opacity * 0.75), 1.0, false)
	# Deliberate interrupted refraction ticks instead of a uniformly white outline.
	if height > 12.0:
		var tick: Vector2 = tip.lerp(ridge, 0.49).round()
		canvas.draw_line(tick, tick + Vector2(1, 2), _alpha(highlight, opacity * 0.90), 1.0, false)
		canvas.draw_rect(Rect2(foot_left + Vector2(1, -2), Vector2(2, 1)), _alpha(highlight, opacity * 0.70))

static func _alpha(color: Color, opacity: float) -> Color:
	return Color(color.r, color.g, color.b, color.a * clampf(opacity, 0.0, 1.0))
