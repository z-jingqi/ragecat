extends RefCounted
## Original short radial fire eruption. No simulation state or retained particles.
## Method references: Sprite Fusion Fire (nested pixel tongues and cooling licks),
## PixelFX fireball (separate advected heat and sparks). See licenses/.
## This is not an exact port: timing, outward impulse, splits and geometry are new.

static func palette() -> Dictionary:
	return {"primary": Color("ff812b"), "highlight": Color("fff1b5"), "shadow": Color("861f20")}

static func label() -> String:
	return "FIRE"

static func draw_spike(c: Node2D, s: Dictionary, age: float, p: Resource) -> void:
	var rise: float = maxf(float(p.rise_time), 0.001)
	var hold: float = maxf(float(p.hold_time), 0.0)
	var fade: float = maxf(float(p.fade_time), 0.001)
	if not is_finite(age) or age < 0.0 or age >= rise + hold + fade:
		return
	var growth: float = 1.0 - pow(1.0 - clampf(age / rise, 0.0, 1.0), 4.0)
	var decay: float = clampf((age - rise - hold) / fade, 0.0, 1.0)
	var opacity: float = (1.0 - smoothstep(0.58, 1.0, decay)) * growth
	var seed_value: int = int(s.get("seed", 0))
	var direction: Vector2 = s.get("direction", Vector2.RIGHT)
	var strength: float = clampf(float(s.get("strength", 1.0)), 0.2, 1.0)
	var impact: float = clampf(float(p.impact_strength), 0.0, 3.0)
	var impulse: float = strength * impact
	var base: Vector2 = s.get("pos", Vector2.ZERO)
	var h: float = maxf(float(s.get("height", 28.0)), 2.0) * (0.83 + 0.17 * strength)
	var w: float = maxf(float(s.get("width", 14.0)), 2.0)
	var lean: float = float(s.get("lean", 0.0))
	var primary: Color = p.primary
	var highlight: Color = p.highlight
	var shadow: Color = p.shadow
	# Local jets streak away from the cast centre, never joining neighboring sites.
	var kick: float = (1.0 - exp(-age * 22.0)) * (3.0 + w * 0.23) * impulse
	var root: Vector2 = base + direction * kick
	var ground: float = float(p.ground_opacity) * opacity * (1.0 - smoothstep(0.0, 0.45, decay))
	for j in range(3):
		var q: Vector2 = base + direction * (kick + j * 2.0) + Vector2((j - 1) * w * 0.28, j % 2)
		c.draw_rect(Rect2(q.round(), Vector2(maxf(1.0, w * 0.22), 1.0)), _alpha(primary, ground * 0.65))
	# Draw separate irregular lobes, not one triangular solid. They shed their roots
	# at different ages; each shrinking hot patch rises away from the ground.
	for j in [0, 2, 1]:
		var n: float = _noise(seed_value, j * 13 + 3)
		var side: float = float(j - 1)
		var detach: float = smoothstep(0.10 + n * 0.18, 0.72, decay)
		var lobe_h: float = h * growth * (0.64 + n * 0.24 + (0.22 if j == 1 else 0.0))
		lobe_h *= (1.0 - decay * 0.62)
		var lobe_w: float = w * (0.30 + n * 0.07) * (1.0 - decay * 0.64)
		var origin: Vector2 = root + Vector2(side * w * (0.25 + detach * 0.24), -detach * h * (0.30 + n * 0.16))
		var bend: float = direction.x * h * 0.25 * impulse + lean * h * 0.35 + side * w * 0.34
		bend += sin(age * 29.0 + n * TAU) * w * 0.16
		_tongue(c, origin, lobe_h, lobe_w, bend, age, decay, n, primary, highlight, shadow, opacity)
	# Finite seeded sparks: a fast launch, outward drift, then red cooling pixels.
	var count: int = clampi(int(round(float(p.debris_density) * 5.0)), 0, 24)
	for j in range(count):
		var n: float = _noise(seed_value, j * 7 + 51)
		var launch: float = rise * (0.30 + n * 0.55)
		var t: float = age - launch
		if t < 0.0:
			continue
		var life: float = rise + hold + fade - launch
		var u: float = t / maxf(life, 0.001)
		var side: float = -1.0 if j % 2 == 0 else 1.0
		var q: Vector2 = base + direction * (w * 0.2 + t * (28.0 + n * 35.0) * impulse)
		q += Vector2(side * (w * 0.12 + t * (8.0 + n * 18.0)), -h * 0.25 - (65.0 + n * 65.0) * t + 110.0 * t * t)
		var col: Color = highlight if u < 0.22 else (primary if u < 0.60 else shadow)
		var size: Vector2 = Vector2(1, 2) if u < 0.45 and j % 3 == 0 else Vector2.ONE
		c.draw_rect(Rect2(q.round(), size), _alpha(col, (1.0 - smoothstep(0.65, 1.0, u)) * opacity))
	# One understated cooling wisp only on selected sites, no persistent smoke.
	if decay > 0.40 and _noise(seed_value, 91) > 0.68:
		var q: Vector2 = root + Vector2(direction.x * decay * 5.0, -h * (0.63 + decay * 0.22))
		c.draw_rect(Rect2(q.round(), Vector2(3, 2)), _alpha(shadow, opacity * 0.14 * sin(decay * PI)))

static func _tongue(c: Node2D, root: Vector2, h: float, w: float, bend: float, age: float, decay: float, phase: float, primary: Color, highlight: Color, shadow: Color, opacity: float) -> void:
	if h < 1.0 or w < 0.45 or opacity <= 0.0:
		return
	# Raster rows retain one-pixel steps at 1x. Pinching varies along the body,
	# and eroded rows open actual transparent gaps when the upper lick tears off.
	var rows: int = maxi(1, int(ceil(h)))
	for row in range(rows):
		var u: float = float(row) / float(rows)
		if decay > 0.22 and absf(u - (0.42 + phase * 0.12)) < 0.035 + decay * 0.035:
			continue
		var belly: float = pow(1.0 - u, 0.65) * (0.65 + 0.48 * sin(u * PI))
		var ripple: float = sin(u * 13.0 - age * 36.0 + phase * 9.0) * 0.55
		var half: float = maxf(0.45, w * belly + ripple)
		var x: float = root.x + bend * u * u + sin(u * 8.0 - age * 24.0 + phase * TAU) * u * 1.8
		var y: float = roundf(root.y - row)
		_row(c, x, y, half, _alpha(shadow, opacity))
		if u < 0.88 and decay < 0.87:
			_row(c, x - 0.35, y, half * 0.73, _alpha(primary, opacity * (1.0 - smoothstep(0.48, 0.9, decay))))
		if u < 0.48 * (1.0 - decay) and decay < 0.5:
			_row(c, x - 0.6, y, half * 0.38, _alpha(highlight, opacity * (1.0 - smoothstep(0.04, 0.48, decay))))

static func _row(c: Node2D, x: float, y: float, half: float, col: Color) -> void:
	var left: float = roundf(x - half)
	var right: float = roundf(x + half)
	c.draw_rect(Rect2(Vector2(left, y), Vector2(maxf(1.0, right - left), 1.0)), col)

static func _alpha(col: Color, opacity: float) -> Color:
	return Color(col.r, col.g, col.b, col.a * clampf(opacity, 0.0, 1.0))

static func _noise(seed_value: int, salt: int) -> float:
	return fposmod(sin(float(seed_value % 65521 + salt * 31) * 1.713) * 21343.43, 1.0)
