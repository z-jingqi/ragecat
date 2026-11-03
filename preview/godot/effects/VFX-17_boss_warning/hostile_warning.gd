extends Node2D
## Pure locked warning. Coordinates are in this node's local space (leave its
## transform identity to pass parent-local coordinates). Caller owns all timing.
## No gameplay activation signal, target lookup, texture bounds or auto expiry.
const BOUNDARY := Color("ff8760")
const PROGRESS := Color("ffbc83")
const FILL := Color(1.0, 0.27, 0.13, 0.16)
var active := false
var shape := "circle"
var origin := Vector2.ZERO
var endpoint := Vector2.ZERO
var radius := 0.0
var progress := 0.0

func play(kind: String, from: Vector2, to: Vector2, half_width: float) -> void:
	stop()
	if kind not in ["circle", "capsule", "line"]: return
	if not from.is_finite() or not to.is_finite(): return
	if not is_finite(half_width) or half_width <= 0: return
	shape = kind
	origin = from
	endpoint = to
	radius = half_width
	active = true
	queue_redraw()

func seek(amount: float) -> void:
	if not active or not is_finite(amount): return
	progress = clampf(amount, 0, 1)
	queue_redraw()

func stop() -> void:
	active = false
	progress = 0
	queue_redraw()

func cancel() -> void:
	stop()

func boundary_points(inset: float = 0.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	if not active: return points
	var r := maxf(0, radius - maxf(0, inset))
	# Multiple of four retains cardinal extrema. Bounded geometry cost, no raster
	# allocation proportional to arbitrary caller dimensions.
	var segments := int(clampf(ceil(sqrt(radius) * 12), 48, 512))
	segments = int(ceil(segments / 4.0)) * 4
	if shape == "circle" or origin == endpoint:
		for i in range(segments):
			points.append(endpoint + Vector2.from_angle(TAU * i / segments) * r)
	else:
		var angle := (endpoint - origin).angle()
		var half := segments / 2
		for i in range(half + 1):
			points.append(endpoint + Vector2.from_angle(angle - PI / 2 + PI * i / half) * r)
		for i in range(half + 1):
			points.append(origin + Vector2.from_angle(angle + PI / 2 + PI * i / half) * r)
	points.append(points[0])
	return points

func _draw() -> void:
	if not active: return
	var outline := boundary_points()
	draw_colored_polygon(outline.slice(0, outline.size() - 1), FILL)
	# Stroke sits inside the authoritative edge. Raster pixel-center rounding is
	# at most one output pixel; there is no soft glow beyond the warning.
	var stroke := minf(2.0, radius)
	draw_polyline(boundary_points(stroke * 0.5), BOUNDARY, stroke, false)
	if shape == "circle" or origin == endpoint:
		var progress_radius := maxf(0, radius * progress - stroke * 0.5)
		if progress_radius > stroke:
			draw_arc(endpoint, progress_radius, 0, TAU, outline.size(), PROGRESS, stroke, false)
	elif progress > 0:
		# The fixed full boundary stays readable while this interior bar advances.
		draw_line(origin, origin.lerp(endpoint, progress), PROGRESS, minf(3, radius), false)
