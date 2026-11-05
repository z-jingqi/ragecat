extends Node2D
## Original analytic rim attachments. Methods informed by Sprite Fusion / PixelFX.
## MIT reference copyright (c) 2026 Hugo Duprez and (c) 2026 Patch.
## Full notices: ../LICENSE and ../ELEMENTS.md. No stock art or gameplay.
const Profile = preload("element_profile.gd")
const Arc = preload("elemental_arc.gd")
var profile = Profile.new()
var arc = Arc.new()
var elapsed := 0.0
var started := false
var enabled := true
var arc_enabled := true
var attachment_enabled := true
var debris_enabled := true

func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(arc)

func play(origin := Vector2.ZERO, configuration: Resource = null) -> void:
	if not origin.is_finite(): clear(); return
	profile = (configuration if configuration is Profile else Profile.new()).sanitized()
	position = origin; elapsed = 0.; started = true
	arc.play(Vector2.ZERO, profile)
	_refresh()

func seek(seconds: float) -> void:
	if not started or not is_finite(seconds): return
	elapsed = maxf(0., seconds); arc.seek(elapsed); _refresh()

func advance(delta: float) -> void:
	if is_finite(delta) and delta >= 0.: seek(elapsed + delta)

func lifetime() -> float: return maxf(profile.duration + profile.thread_duration, profile.duration + profile.debris_lifetime)
func is_running() -> bool: return started and elapsed < lifetime()
func clear() -> void:
	started = false; elapsed = 0.; arc.clear(); _refresh()
func stop() -> void: clear()
func set_enabled(value: bool) -> void:
	enabled = value; _refresh()
func set_layer_enabled(layer: String, value: bool) -> void:
	match layer:
		"arc": arc_enabled = value
		"attachment": attachment_enabled = value
		"debris": debris_enabled = value
	_refresh()
func _refresh() -> void:
	visible = started and enabled and elapsed > 0. and elapsed < lifetime() and profile.intensity > 0.
	arc.set_enabled(arc_enabled)
	queue_redraw()

func _hash(i: float) -> float: return fposmod(sin(i * 127.1 + profile.shape_seed * 9.31) * 43758.5453, 1.)
func _point(u: float, radius_offset := 0.) -> Vector2:
	var angle := deg_to_rad(profile.sweep_center_degrees - profile.sweep_degrees * .5 + profile.sweep_degrees * u)
	var q: Vector2 = Vector2(cos(angle), sin(angle) * profile.squash) * (profile.radius + radius_offset)
	if profile.reverse: q.y = -q.y
	q = q.rotated(deg_to_rad(profile.direction_degrees))
	if profile.facing_left: q.x = -q.x
	return q
func _normal(u: float) -> Vector2: return (_point(u, 1.) - _point(u)).normalized()
func _tangent(u: float) -> Vector2: return (_point(u + .005) - _point(u - .005)).normalized()
func _snap(v: Vector2) -> Vector2:
	return (v / profile.pixel_size).floor() * profile.pixel_size + Vector2.ONE * profile.pixel_size * .5
func _color(c: Color) -> Color: return Color(minf(c.r * profile.intensity, 1), minf(c.g * profile.intensity, 1), minf(c.b * profile.intensity, 1), 1)
func _line(a: Vector2, b: Vector2, c: Color, width := 1.) -> void:
	draw_line(_snap(a), _snap(b), _color(c), width * profile.pixel_size, false)
func _polygon(points: Array, color: Color) -> void:
	var polygon := PackedVector2Array()
	for p in points:
		var q := _snap(p)
		if polygon.is_empty() or not polygon[-1].is_equal_approx(q): polygon.append(q)
	if polygon.size() > 2 and polygon[0].is_equal_approx(polygon[-1]): polygon.remove_at(polygon.size() - 1)
	if polygon.size() >= 3 and not Geometry2D.triangulate_polygon(polygon).is_empty(): draw_colored_polygon(polygon, _color(color))

func _draw() -> void:
	if not visible: return
	var head := 1. if elapsed >= profile.onset else 1. - pow(2., -10. * elapsed / profile.onset)
	var tail := smoothstep(profile.onset + profile.hold, profile.duration, elapsed)
	if profile.attachment_enabled and attachment_enabled and profile.attachment_strength > 0. and elapsed < profile.duration:
		for i in profile.attachment_count:
			var u := lerpf(.26 if profile.element == 1 else .5, .955, pow(float(i) / maxf(1., profile.attachment_count - 1), .72)) + (_hash(i + 7) - .5) * .048
			if u > head or u < tail: continue
			var envelope := minf(1., (head - u) * 18.) * minf(1., (u - tail) * 10.)
			var reach: float = profile.edge_reach * (.38 + .78 * _hash(i + 21)) * envelope * profile.attachment_strength
			if profile.element == 2:
				reach = profile.edge_reach * [0.55, 0.38, 0.86, 0.57, 1.18, 0.55][i % 6] * envelope * profile.attachment_strength
			if reach < 1.: continue
			match profile.element:
				0: _flame(u, reach, i)
				1: _electric(u, reach, i)
				2: _crystal(_point(u, -.8), _normal(u), _tangent(u), reach, reach * .76, i)
	if profile.debris_enabled and debris_enabled and profile.attachment_strength > 0.: _debris()

func _flame(u: float, length: float, index: int) -> void:
	var root := _point(u, -2.)
	var n := _normal(u); var t := _tangent(u)
	var sway := sin(elapsed * 37. + index * 2.3) * 1.8
	var width := length * .36
	# One curling tongue, warm base, hooked orange tip and a thin hot interior.
	var a := root - t * width
	var b := root + t * width
	var mid := root + n * length * .55 - t * length * .13
	var tip := root + n * length - t * (length * .5 + sway)
	_polygon([a, mid - t * width * .5, tip - n * length * .1 - t * 2., tip, mid + t * width * .55, b], profile.shade_color)
	_polygon([a + t, mid - t * width * .25, tip, mid + t * width * .35 + n, b - t], profile.inner_color)
	_polygon([root - t * width * .5, mid - n * length * .09, tip - n * length * .24 + t, mid + t * width * .35, root + t * width * .65], profile.body_color)
	_polygon([root - t * width * .2, mid - n * length * .15 + t, root + t * width * .4], profile.highlight_color)

func _electric(u: float, reach: float, index: int) -> void:
	var root := _point(u, -1.)
	var n := _normal(u); var tangent := _tangent(u)
	var epoch := floorf(elapsed * 30.)
	var points: Array[Vector2] = [root]
	for j in range(1, 6):
		var distance := float(j) / 5.
		points.append(root + n * reach * distance + tangent * ((_hash(index * 71 + j * 11 + epoch * 3) - .5) * reach * .65 - reach * distance * .2))
	var branches: Array = [points]
	var fork_start: Vector2 = points[3]
	branches.append([fork_start, fork_start + tangent * reach * .36 + n * reach * .13, fork_start + tangent * reach * .68 + n * reach * .05])
	# Small arc follows the rim, keeping the white core continuous at native size.
	if index % 2 == 0:
		branches.append([root, _point(u + .04, reach * .18), _point(u + .08, reach * .08), _point(minf(.99, u + .11), -1.)])
	for width in [3., 2., 1.]:
		var color: Color = profile.shade_color if width == 3. else (profile.body_color if width == 2. else profile.edge_color)
		for path in branches:
			for j in range(1, path.size()): _line(path[j - 1], path[j], color, width)

func _crystal(root: Vector2, n: Vector2, tangent: Vector2, length: float, width: float, index: int) -> void:
	var tip := root + n * length - tangent * length * (.20 + _hash(index + 83) * .25)
	var left := root - tangent * width * .5
	var right := root + tangent * width * .5
	var ridge := root - tangent * width * .12 + n * length * .18
	_polygon([left, tip, right], profile.shade_color)
	_polygon([left, tip, ridge], profile.body_color)
	_polygon([ridge, tip, right], profile.inner_color)
	_line(left, tip, profile.highlight_color)
	_line(ridge, tip, profile.edge_color)
	_line(root - tangent * width * .42 + n * length * .2, root + n * length * .48, profile.highlight_color)

func _debris() -> void:
	for i in profile.debris_count:
		var u := .24 + _hash(i + 113) * .72
		# Shed as the chasing tail reaches each root; sparks are in air, never a ground wave.
		var born: float = profile.onset * (.65 + .24 * u) if i % 3 == 0 else profile.onset + profile.hold + (profile.duration - profile.onset - profile.hold) * (.08 + .54 * u)
		var age := elapsed - born
		var life: float = profile.debris_lifetime * (.65 + .35 * _hash(i + 157))
		if age <= 0. or age >= life: continue
		var fade := 1. - age / life
		var n := _normal(u); var tangent := _tangent(u)
		var velocity := n * (24. + _hash(i + 171) * 42.) + tangent * 21.
		var at := _point(u, profile.edge_reach * .25) + velocity * age
		if profile.element == 0:
			at += Vector2(0, -21. * age)
			_line(at - velocity.normalized() * 3. * fade, at, profile.inner_color)
			_line(at - velocity.normalized() * fade, at, profile.highlight_color if fade > .45 else profile.body_color)
		elif profile.element == 1:
			if fade > .5:
				_line(at - tangent * 2., at, profile.body_color)
				_line(at, at + n * 2., profile.edge_color)
		else:
			at += Vector2(0, 55. * age * age)
			_crystal(at, n.rotated(age * 4.), tangent.rotated(age * 4.), (2. + _hash(i + 191) * 3.) * fade, 3. * fade, i)
