extends Node2D
## Pure Ragecat slash. The caller owns combat, spawning, clock and disposal.
## Coordinates/radius are in parent world units; direction follows Godot (+Y down).
const SHADER := preload("slash_runtime.gdshader")
var age := 0.0
var duration := 0.18
var done := true
var material_instance: ShaderMaterial
var surface: ColorRect

func play(origin: Vector2, direction: Vector2, radius: float, half_angle: float, options: Dictionary = {}) -> void:
	if surface == null:
		surface = ColorRect.new()
		surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
		surface.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		material_instance = ShaderMaterial.new()
		material_instance.shader = SHADER
		surface.material = material_instance
		add_child(surface)
	position = origin
	var pixel_size := clampf(float(options.get("pixel_size",1.0)),0.25,8.0)
	var reach := maxf(1.0,radius) / pixel_size
	var extent := ceilf(reach + 2.0) * 2.0
	surface.position = Vector2.ONE * -extent * pixel_size * 0.5
	surface.size = Vector2.ONE * extent * pixel_size
	var start := clampf(float(options.get("start_seconds",0.025)),0.005,0.08)
	var burst := clampf(float(options.get("burst_seconds",0.065)),0.015,0.16)
	var decay := clampf(float(options.get("decay_seconds",0.09)),0.025,0.25)
	duration = start + burst + decay
	var parameters := {
		"age":0.0, "art_extent":extent, "reach_px":reach,
		"thickness_px":clampf(float(options.get("thickness_ratio",13.0/46.0)),0.02,0.65)*reach,
		"sweep_radians":clampf(half_angle*2.0,deg_to_rad(1.0),deg_to_rad(220.0)),
		"curvature":clampf(float(options.get("curvature",0.82)),0.35,1.0),
		"direction_radians":-direction.angle() if direction.length_squared() > 0.0 else 0.0,
		"reverse_sign":-1.0 if options.get("reverse",false) else 1.0,
		"start_seconds":start, "burst_seconds":burst, "decay_seconds":decay,
		"edge_color":options.get("edge_color",Color("fff4ce")),
		"body_color":options.get("body_color",Color("f5c56b")),
		"tail_color":options.get("tail_color",Color("ba7637"))
	}
	for key in parameters: material_instance.set_shader_parameter(key,parameters[key])
	age = 0.0
	done = false
	visible = true

func advance(delta: float) -> void:
	if done: return
	age = minf(duration,age + maxf(0.0,delta))
	material_instance.set_shader_parameter("age",age)
	if age >= duration: stop()

func stop() -> void:
	done = true
	visible = false
