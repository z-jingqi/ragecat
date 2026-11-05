extends RefCounted
## Original directional discharge, not an exact Sprite Fusion port.
## Stable endpoints and seeded elbows preserve a channel across its re-strike.
## All geometry is a pure function of site, profile and age; no frame RNG/state.
## Method references: Sprite Fusion Lightning (Strike/Chain), Hugo Duprez, MIT;
## PixelFX lightning-strike.js / chain-lightning.js at a84159688af3ca37a4be05a0d422b94451b2e24e.
## Original small-scale geometry; upstream notices retained in ../licenses/.

static func palette() -> Dictionary:
	return {"primary": Color("7974f5"), "highlight": Color("fffbd9"), "shadow": Color("42317d")}

static func label() -> String:
	return "LIGHTNING"

static func draw_spike(c: Node2D, s: Dictionary, age: float, p: Resource) -> void:
	var rise: float = maxf(float(p.rise_time), 0.001)
	var hold: float = maxf(float(p.hold_time), 0.0)
	var fade: float = maxf(float(p.fade_time), 0.001)
	var life: float = rise + hold + fade
	if not is_finite(age) or age < 0.0 or age >= life:
		return
	var seed_value: int = int(s.get("seed", 0))
	var base: Vector2 = s.get("pos", Vector2.ZERO)
	var width: float = maxf(float(s.get("width", 12.0)), 2.0)
	var height: float = maxf(float(s.get("height", 25.0)), 2.0)
	var strength: float = clampf(float(s.get("strength", 1.0 if posmod(seed_value, 4) == 0 else 0.22)), 0.0, 1.0)
	var direction: Vector2 = s.get("direction", Vector2.RIGHT)
	if not direction.is_finite() or direction.length_squared() < 0.001:
		direction = Vector2.RIGHT
	direction = direction.normalized()
	var mode: int = int(p.lightning_direction_mode)
	if mode == 1:
		direction = -direction
	var primary: Color = p.primary
	var highlight: Color = p.highlight
	var shadow: Color = p.shadow
	var ground: float = clampf(float(p.ground_opacity), 0.0, 1.0)
	var impact: float = clampf(float(p.impact_strength), 0.0, 2.0)
	var phase: float = age / life
	# Weak sites never grow a trunk or white core: most of the area stays quiet.
	if strength < 0.6:
		if ground <= 0.0 or _noise(seed_value, 89) < 0.5 or phase > 0.40:
			return
		var weak: float = strength * ground * (1.0 - phase / 0.40)
		var end: Vector2 = base + direction * width * 0.45
		_bolt(c, _channel(base, end, seed_value, width * 0.10), primary, highlight, shadow, weak, false)
		return

	# The footprint's ground vector, not an upright cone, defines travel.
	# A low airborne hump lifts ground links; the destination remains fixed.
	var reach: float = height * (1.25 + strength * 0.30)
	var start: Vector2 = base - direction * reach
	if mode == 2:
		start = base + Vector2(float(s.get("lean", 0.0)) * height, -height)
	var path: PackedVector2Array = _channel(start, base, seed_value, minf(width * 0.24, reach * 0.10), 0.0 if mode == 2 else height * 0.17)
	# Fast leader, first hot stroke, real dark gap, weaker anchored re-strike.
	# Ratios track the user's full lifetime rather than adding an unbounded loop.
	var attack: float = minf(rise * 0.25, life * 0.09)
	var energy: float = 0.0
	var leader: float = clampf(age / maxf(attack, 0.001), 0.0, 1.0)
	if age < attack:
		energy = 0.30
	elif phase < 0.30:
		energy = lerpf(1.0, 0.62, clampf((phase - 0.09) / 0.21, 0.0, 1.0))
	elif phase >= 0.42 and phase < 0.62:
		energy = 0.72 * (1.0 - (phase - 0.42) / 0.28)
	energy *= strength * impact
	if energy > 0.0:
		_bolt(c, _prefix(path, leader), primary, highlight, shadow, energy, age >= attack)
		# One deliberately subordinate branch follows the trunk's direction.
		# No secondary branch tree, no equally bright repeated tridents.
		if leader >= 1.0 and energy > 0.35:
			var root: Vector2 = path[3]
			var tangent: Vector2 = (base - start).normalized()
			var side: Vector2 = Vector2(-tangent.y, tangent.x)
			var sign_value: float = -1.0 if posmod(seed_value, 2) == 0 else 1.0
			var tip: Vector2 = root + tangent * reach * 0.19 + side * sign_value * width * 0.48
			_bolt(c, _channel(root, tip, seed_value + 19, width * 0.08), primary, highlight, shadow, energy * 0.32, false)
	# Dotted residual channel cools, without leaving a broad persistent line.
	if phase >= 0.62:
		var ghost: float = (1.0 - phase) / 0.38 * strength * 0.25
		for j in range(1, path.size() - 1, 2):
			c.draw_rect(Rect2(path[j].round(), Vector2.ONE), _alpha(primary, ghost), true)
	if leader < 1.0:
		return
	# Arrival flash and small crawlers are local to this channel's landing.
	# A second, smaller burst marks its re-strike, never a whole-screen flash.
	var arrival: float = maxf(0.0, 1.0 - (age - attack) / (life * 0.22))
	if phase >= 0.42:
		arrival = maxf(0.0, 0.60 * (1.0 - (phase - 0.42) / 0.15))
	arrival *= strength * impact
	if ground > 0.0 and arrival > 0.0:
		c.draw_rect(Rect2(base.round() - Vector2(3, 1), Vector2(6, 2)), _alpha(primary, arrival * ground), true)
		c.draw_rect(Rect2(base.round() - Vector2.ONE, Vector2(2, 2)), _alpha(highlight, arrival * ground), true)
		for k in range(2):
			var side: float = -1.0 if k == 0 else 1.0
			var tip: Vector2 = base + Vector2(side * width * 0.55, -2.0 - _noise(seed_value, k + 40) * 2.0)
			_bolt(c, _channel(base, tip, seed_value + k, 1.5), primary, highlight, shadow, arrival * ground * 0.38, false)
	# Sparks leave only the landing, not arbitrary points all along every bolt.
	var count: int = clampi(roundi(float(p.debris_density) * 2.0), 0, 4)
	if arrival > 0.0:
		for k in range(count):
			var heading: Vector2 = Vector2(-1.0 if k % 2 == 0 else 1.0, -0.6 - _noise(seed_value, k + 65)).normalized()
			var q: Vector2 = base + heading * (3.0 + (1.0 - minf(arrival, 1.0)) * width * 0.7)
			c.draw_line(q.round(), (q + heading * 2.0).round(), _alpha(highlight, arrival * 0.7), 1.0, false)

static func _channel(start: Vector2, finish: Vector2, seed_value: int, jag: float, lift: float = 0.0) -> PackedVector2Array:
	var path: PackedVector2Array = PackedVector2Array([start])
	var delta: Vector2 = finish - start
	var side: Vector2 = Vector2(-delta.y, delta.x).normalized()
	for j in range(1, 7):
		var t: float = float(j) / 7.0
		var kink: float = (_noise(seed_value, j * 17) * 2.0 - 1.0) * jag
		path.append(start + delta * t + side * kink + Vector2(0.0, -sin(t * PI) * lift))
	path.append(finish)
	return path

static func _prefix(path: PackedVector2Array, progress: float) -> PackedVector2Array:
	if progress >= 1.0:
		return path
	var cursor: float = maxf(progress, 0.001) * float(path.size() - 1)
	var index: int = mini(int(cursor), path.size() - 2)
	var result: PackedVector2Array = path.slice(0, index + 1)
	result.append(path[index].lerp(path[index + 1], cursor - float(index)))
	return result

static func _bolt(c: Node2D, points: PackedVector2Array, primary: Color, highlight: Color, shadow: Color, opacity: float, main: bool) -> void:
	if opacity <= 0.0:
		return
	var snapped: PackedVector2Array = PackedVector2Array()
	for point in points:
		snapped.append(point.round())
	if main:
		c.draw_polyline(snapped, _alpha(shadow, opacity * 0.50), 4.0, false)
		c.draw_polyline(snapped, _alpha(primary, opacity * 0.90), 3.0, false)
		c.draw_polyline(snapped, _alpha(highlight, opacity), 1.0, false)
	else:
		c.draw_polyline(snapped, _alpha(primary, opacity), 1.0, false)

static func _noise(seed_value: int, salt: int) -> float:
	return fposmod(sin(float(posmod(seed_value, 65521)) * 0.173 + float(salt) * 1.719) * 43758.5453, 1.0)

static func _alpha(color: Color, opacity: float) -> Color:
	return Color(color.r, color.g, color.b, color.a * clampf(opacity, 0.0, 1.0))
