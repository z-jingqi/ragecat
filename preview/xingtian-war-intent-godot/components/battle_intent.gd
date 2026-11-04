extends Node2D
## Original ground design informed by Patch-gg Rage's seeded crack construction
## and Sprite Fusion Power Up's low ground / character-layer separation.
## MIT upstream notices are retained in THIRD_PARTY_NOTICES.md. No upstream assets.
const Profile = preload("intent_profile.gd")
const Canvas = preload("pixel_canvas.gd")
const SIZE = Vector2i(160, 144)
const ANCHOR = Vector2(80, 90)
var profile = Profile.new()
var momentum: float = 0.0
var elapsed: float = 0.0
var active: bool = false
var layers := {"ring": true, "cracks": true}
var _texture: ImageTexture
var _image: Image

func play(origin: Vector2 = Vector2.ZERO, configuration: Resource = null) -> void:
	if not origin.is_finite(): clear(); return
	position = origin
	profile = (configuration if configuration is Profile else Profile.new()).sanitized()
	elapsed = 0.0
	momentum = 0.0
	active = true
	_render()

func set_momentum(value: float) -> void:
	momentum = clampf(value, 0.0, 1.0) if is_finite(value) else 0.0
	_render()

func seek(seconds: float) -> void:
	if not active: return
	elapsed = maxf(0.0, seconds) if is_finite(seconds) else 0.0
	_render()

func advance(delta: float) -> void:
	if active and is_finite(delta) and delta > 0.0: seek(elapsed + delta)

func set_layer_enabled(layer: String, enabled: bool) -> void:
	if layers.has(layer): layers[layer] = enabled; _render()

func clear() -> void:
	active = false
	momentum = 0.0
	_render()

func stop() -> void:
	clear()

func get_frame() -> Image:
	if _image == null: _render()
	return _image.duplicate()

func _render() -> void:
	var p = Canvas.new(SIZE, ANCHOR)
	if active and momentum > 0.001:
		var breath: float = 1.0 - profile.breathing + profile.breathing * sin(elapsed * TAU / 1.8)
		var alpha: float = profile.opacity * pow(momentum, 0.65) * breath
		if layers.ring: _ring(p, alpha)
		if layers.cracks: _cracks(p, alpha)
	_image = p.image
	if _texture == null: _texture = ImageTexture.create_from_image(_image)
	else: _texture.update(_image)
	queue_redraw()

func _ring(p, alpha: float) -> void:
	for i in range(profile.ring_segments):
		# Distributed thresholds grow pieces around the feet, not a HUD progress sweep.
		var order: float = Canvas.noise(i * 3, profile.shape_seed)
		var reveal: float = clampf((momentum - order * 0.72) / 0.28, 0.0, 1.0)
		if reveal <= 0.0: continue
		var angle: float = float(i) * TAU / profile.ring_segments
		var span: float = TAU / profile.ring_segments * (0.64 + order * 0.2) * reveal
		var rad: float = profile.radius + (Canvas.noise(i + 99, profile.shape_seed) - 0.5) * 2.0
		p.arc(rad + 1.0, profile.perspective, angle, angle + span, profile.dark, alpha * 0.7, 0.6)
		p.arc(rad, profile.perspective, angle, angle + span, profile.red, alpha * (0.72 if sin(angle) < 0 else 1.0), 0.6)
		if momentum > 0.75 and i % 4 == 0:
			p.pixel(p.point_on_ground(angle + span * 0.8, rad, profile.perspective), profile.edge, alpha * 0.55)

func _cracks(p, alpha: float) -> void:
	for i in range(profile.crack_count):
		var rand: float = Canvas.noise(i + 251, profile.shape_seed)
		var reveal: float = clampf((momentum - rand * 0.55) / 0.45, 0.0, 1.0)
		if reveal <= 0.0: continue
		var angle: float = float(i) / profile.crack_count * TAU + (rand - 0.5) * 0.24
		var previous: Vector2 = p.point_on_ground(angle, profile.radius * (0.18 + rand * 0.20), profile.perspective)
		for j in range(1, 7):
			var growth: float = clampf(reveal * 6.0 - (j - 1), 0.0, 1.0)
			if growth <= 0.0: break
			var r: float = profile.radius * (0.25 + float(j) / 6.0 * (0.9 + rand * 0.25))
			var a: float = angle + (Canvas.noise(i * 10 + j, profile.shape_seed) - 0.5) * 0.31
			var next: Vector2 = previous.lerp(p.point_on_ground(a, r, profile.perspective), growth)
			p.line(previous + Vector2.DOWN, next + Vector2.DOWN, profile.dark, alpha * 0.8)
			p.line(previous, next, profile.red, alpha * (0.88 - float(j) * 0.07))
			if j == 3 or (j == 5 and i % 2 == 0):
				var fork: Vector2 = p.point_on_ground(a + (0.22 if i % 2 == 0 else -0.23), r * 1.16, profile.perspective)
				p.line(next, fork, profile.red, alpha * 0.38)
			previous = next

func _draw() -> void:
	if _texture != null: draw_texture(_texture, -ANCHOR)
