extends Node2D
## Purely visual persistent fire. The caller owns zone geometry, age and disposal.
## No process callbacks, timers, damage, physics, RNG or automatic freeing.
const MASK := preload("ground_burn.gdshader")
const MAX_FLAMES := 24
var age := 0.0
var duration := 1.0
var radius := 1.0
var done := true
var settings: Dictionary = {}
var body: ColorRect
var outline: ColorRect
var _started := false

static func number(value: Variant, low: float, high: float, fallback: float) -> float:
	if not (value is float or value is int): return fallback
	var result := float(value)
	return clampf(result, low, high) if is_finite(result) else fallback

static func sanitized(options: Dictionary) -> Dictionary:
	var result := {
		"pixel_size": number(options.get("pixel_size", 2.0), 0.5, 8.0, 2.0),
		"flame_height": number(options.get("flame_height", 14.0), 0.0, 40.0, 14.0),
		"flame_count": int(number(options.get("flame_count", 16), 0, MAX_FLAMES, 16)),
		"intensity": number(options.get("intensity", 0.8), 0.0, 1.0, 0.8),
		"ground_opacity": number(options.get("ground_opacity", 0.22), 0.0, 0.5, 0.22),
		"outline_width": number(options.get("outline_width", 2.0), 0.5, 6.0, 2.0),
		"seed": int(number(options.get("seed", 37), 0, 4095, 37)),
		"enter_time": number(options.get("enter_time", 0.10), 0.0, 1.0, 0.10),
		"exit_time": number(options.get("exit_time", 0.25), 0.0, 2.0, 0.25)
	}
	var colors := {"core_color": "ffe5a0", "body_color": "ffb34b", "flame_color": "e96632", "coal_color": "542d29", "outline_color": "ed9849"}
	for key in colors:
		var value: Variant = options.get(key, Color(colors[key]))
		var color: Color = value if value is Color else Color.from_string(str(value), Color(colors[key]))
		if not is_finite(color.r) or not is_finite(color.g) or not is_finite(color.b): color = Color(colors[key])
		result[key] = Color(clampf(color.r, 0, 1), clampf(color.g, 0, 1), clampf(color.b, 0, 1), 1)
	return result

func _ensure_surfaces() -> void:
	if body != null: return
	for layer in range(2):
		var surface := ColorRect.new()
		surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
		surface.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		surface.z_index = layer
		var material_instance := ShaderMaterial.new()
		material_instance.shader = MASK
		material_instance.set_shader_parameter("outline_pass", layer == 1)
		surface.material = material_instance
		add_child(surface)
		if layer == 0: body = surface
		else: outline = surface

func play(origin: Vector2, zone_radius: float, lifetime: float, options: Dictionary = {}) -> void:
	if not origin.is_finite() or not is_finite(zone_radius) or zone_radius <= 0.0 or not is_finite(lifetime) or lifetime <= 0.0:
		stop()
		return
	_ensure_surfaces()
	position = origin
	radius = zone_radius
	duration = lifetime
	settings = sanitized(options)
	# The circle keeps the caller's actual radius. Art-pixel bounds are rounded up,
	# never the geometry itself. Both passes use identical local coordinates.
	var extent: float = ceilf(radius / settings.pixel_size + 1.0) * settings.pixel_size
	for surface in [body, outline]:
		surface.position = Vector2.ONE * -extent
		surface.size = Vector2.ONE * extent * 2.0
		var material_instance := surface.material as ShaderMaterial
		for key in settings:
			material_instance.set_shader_parameter(key, settings[key])
		material_instance.set_shader_parameter("extent", extent)
		material_instance.set_shader_parameter("radius", radius)
		material_instance.set_shader_parameter("duration", duration)
	_started = true
	seek(0.0)

func seek(seconds: float) -> void:
	if not _started or not is_finite(seconds): return
	age = clampf(seconds, 0.0, duration)
	done = age >= duration
	visible = not done
	for surface in [body, outline]:
		(surface.material as ShaderMaterial).set_shader_parameter("age", age)

func advance(delta: float) -> void:
	if not done and is_finite(delta) and delta > 0.0: seek(age + delta)

func stop() -> void:
	_started = false
	done = true
	visible = false

func clear() -> void:
	stop()
