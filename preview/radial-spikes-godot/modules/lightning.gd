extends RefCounted
## Original ground-born electrical eruptions, not a solid spike or a sky strike.
## Age/seed-only stepped paths make seek, pause and replay exactly repeatable.

static func palette() -> Dictionary:
	return {"primary": Color("7974f5"), "highlight": Color("fffbd9"), "shadow": Color("42317d")}

static func label() -> String:
	return "LIGHTNING"

static func draw_spike(c: Node2D, s: Dictionary, age: float, p: Resource) -> void:
	var rise: float = maxf(float(p.rise_time), 0.001)
	var hold: float = maxf(float(p.hold_time), 0.0)
	var fade: float = maxf(float(p.fade_time), 0.001)
	if not is_finite(age) or age < 0.0 or age >= rise + hold + fade:
		return
	var seed_value: int = int(s.get("seed", 0))
	var variant: float = float(s.get("variant", 0.5))
	var base: Vector2 = s.get("pos", Vector2.ZERO)
	var width: float = maxf(float(s.get("width", 12.0)), 2.0)
	var height: float = maxf(float(s.get("height", 25.0)), 2.0)
	var lean: float = float(s.get("lean", 0.0))
	var growth: float = 1.0 - pow(1.0 - clampf(age / rise, 0.0, 1.0), 2.0)
	var decay: float = 1.0 - clampf((age - rise - hold) / fade, 0.0, 1.0)
	# Each site has its own short pulse and dark gap. No fence persists in hold.
	var period: float = 0.22 + _noise(seed_value, 7) * 0.12
	var phase: float = fposmod(age, period) / period
	var pulse: float = 1.0 - smoothstep(0.23, 0.59, phase)
	if pulse <= 0.0:
		return
	var frame: int = int(floor(age / 0.042))
	var energy: float = pulse * decay * minf(growth * 3.0, 1.0)
	var h: float = height * growth * (0.74 + _noise(seed_value, frame * 13 + 1) * 0.26)
	var primary: Color = p.primary
	var highlight: Color = p.highlight
	var shadow: Color = p.shadow
	# Broken ground crawlers extend away from this anchor, never between sites.
	var ground: float = clampf(float(p.ground_opacity), 0.0, 1.0)
	if ground > 0.0:
		for branch in range(2):
			var side: float = -1.0 if branch == 0 else 1.0
			var reach: float = width * (0.65 + _noise(seed_value, frame * 17 + branch) * 0.45) * growth
			var dy: float = (_noise(seed_value, branch + 59) - 0.5) * 8.0
			var ground_path: PackedVector2Array = PackedVector2Array([
				base, base + Vector2(side * reach * 0.33, dy * 0.2 - 1.0),
				base + Vector2(side * reach * 0.48, dy * 0.5 + 2.0),
				base + Vector2(side * reach * 0.76, dy * 0.65),
				base + Vector2(side * reach, dy)])
			_bolt(c, ground_path, primary, highlight, shadow, energy * ground * 0.75, false)
	# The narrow rising channel has abrupt alternating elbows, not filled faces.
	if h >= 2.0:
		var path: PackedVector2Array = PackedVector2Array([base])
		for j in range(1, 6):
			var t: float = float(j) / 5.0
			var side: float = -1.0 if (j + seed_value) % 2 == 0 else 1.0
			var kink: float = side * width * (0.10 + _noise(seed_value, frame * 37 + j) * 0.22)
			path.append(base + Vector2(lean * h * t + kink, -h * t))
		_bolt(c, path, primary, highlight, shadow, energy, true)
		# One asymmetrical fork; occasional second fork prevents identical tridents.
		var fork_count: int = 2 if _noise(seed_value, frame + 73) > 0.64 else 1
		for k in range(fork_count):
			var root: Vector2 = path[2 + k]
			var side: float = -1.0 if (seed_value + k) % 2 == 0 else 1.0
			var reach: float = width * (0.34 + variant * 0.16)
			var fork: PackedVector2Array = PackedVector2Array([root,
				root + Vector2(side * reach * 0.60, -h * 0.12),
				root + Vector2(side * reach * 0.30, -h * 0.20),
				root + Vector2(side * reach, -h * 0.33)])
			_bolt(c, fork, primary, highlight, shadow, energy * 0.78, false)
	# Free sparks are explicitly disabled at debris_density=0. They are electrical
	# two-pixel dashes, never floating shards or a second particle system.
	var count: int = clampi(roundi(float(p.debris_density) * 3.0), 0, 6)
	for k in range(count):
		if _noise(seed_value, frame * 11 + k + 101) < 0.46:
			continue
		var side: float = -1.0 if k % 2 == 0 else 1.0
		var q: Vector2 = base + Vector2(side * width * (0.40 + _noise(seed_value, k + frame * 3) * 0.40), -h * _noise(seed_value, k + frame * 5 + 31))
		c.draw_line(q.round(), (q + Vector2(side * 2.0, -1.0)).round(), _alpha(highlight, energy * 0.85), 1.0, false)

static func _bolt(c: Node2D, points: PackedVector2Array, primary: Color, highlight: Color, shadow: Color, opacity: float, main: bool) -> void:
	if opacity <= 0.0:
		return
	var snapped: PackedVector2Array = PackedVector2Array()
	for point in points:
		snapped.append(point.round())
	if main:
		c.draw_polyline(snapped, _alpha(shadow, opacity * 0.55), 4.0, false)
	c.draw_polyline(snapped, _alpha(primary, opacity * 0.85), 3.0 if main else 2.0, false)
	c.draw_polyline(snapped, _alpha(highlight, opacity), 1.0, false)

static func _noise(seed_value: int, salt: int) -> float:
	# Bounded inputs avoid precision loss for scheduler-generated 32-bit seeds.
	return fposmod(sin(float(posmod(seed_value, 65521)) * 0.173 + float(salt) * 1.719) * 43758.5453, 1.0)

static func _alpha(color: Color, opacity: float) -> Color:
	return Color(color.r, color.g, color.b, color.a * clampf(opacity, 0.0, 1.0))
