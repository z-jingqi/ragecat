extends Node2D
const History = preload("res://effects/VFX-02_weapon_trail/trail_history.gd")
const TrailShader = preload("res://effects/VFX-02_weapon_trail/trail.gdshader")
var history: History
var pixels_per_unit := 16.0
var display_scale := 1.0
var camera_world := Vector2.ZERO
var width_fraction := 0.68
var taper_power := 1.35
var opacity := 1.0
var stepped_fade := false
var core := Color("fff4ce")
var body := Color("edbb61")
var edge := Color("ac6f35")
var points := PackedVector4Array()
var lives := PackedFloat32Array()
var bounds := Rect2()

func _ready() -> void:
	points.resize(64)
	lives.resize(64)
	var mat := ShaderMaterial.new()
	mat.shader = TrailShader
	material = mat

func to_canvas(p: Vector2) -> Vector2:
	var q := (p - camera_world) * pixels_per_unit * display_scale
	return Vector2(q.x, -q.y)

func safe(value: float, fallback: float, lo: float, hi: float) -> float:
	return clampf(value if is_finite(value) else fallback, lo, hi)

func sync() -> void:
	if history == null or not is_instance_valid(material):
		return
	pixels_per_unit = safe(pixels_per_unit, 16.0, 1.0, 128.0)
	width_fraction = safe(width_fraction, 0.68, 0.05, 1.0)
	taper_power = safe(taper_power, 1.35, 0.25, 4.0)
	opacity = safe(opacity, 1.0, 0.0, 1.0)
	display_scale = safe(display_scale, 1.0, 1.0, 8.0)
	if not camera_world.is_finite():
		camera_world = Vector2.ZERO
	for i in range(history.count):
		var n := history.index(i)
		var a := history.roots[n] * pixels_per_unit
		var b := history.tips[n] * pixels_per_unit
		points[i] = Vector4(a.x, a.y, b.x, b.y)
		lives[i] = history.remaining(i)
		if i == 0:
			bounds = Rect2(to_canvas(history.roots[n]), Vector2.ZERO)
		bounds = bounds.expand(to_canvas(history.roots[n])).expand(to_canvas(history.tips[n]))
	var mat := material as ShaderMaterial
	mat.set_shader_parameter("trail_points", points)
	mat.set_shader_parameter("trail_life", lives)
	mat.set_shader_parameter("trail_count", history.count)
	mat.set_shader_parameter("width_fraction", width_fraction)
	mat.set_shader_parameter("taper_power", taper_power)
	mat.set_shader_parameter("opacity", opacity)
	mat.set_shader_parameter("stepped_fade", stepped_fade)
	mat.set_shader_parameter("display_scale", display_scale)
	mat.set_shader_parameter("camera_pixels", camera_world * pixels_per_unit)
	mat.set_shader_parameter("core_color", core)
	mat.set_shader_parameter("body_color", body)
	mat.set_shader_parameter("edge_color", edge)
	queue_redraw()

func _draw() -> void:
	if history != null and history.count >= 2:
		draw_rect(bounds.grow(display_scale * 2.0), Color.WHITE)
