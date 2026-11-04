extends "component.gd"
const ShaderSource = preload("lava_surface.gdshader")
var surface: ColorRect

func _build() -> void:
	if surface == null:
		surface = ColorRect.new()
		surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
		surface.material = ShaderMaterial.new()
		surface.material.shader = ShaderSource
		add_child(surface)
	var extent: float = ceilf(profile.radius * 1.25 + 8.0)
	surface.position = -Vector2.ONE * extent
	surface.size = Vector2.ONE * extent * 2.0
	for key in ["radius", "perspective", "pixel_size", "shape_seed", "opening_time", "hold_time", "cooling_time", "fade_time", "flow_speed", "channel_width", "crust_scale", "lava_opacity", "lava_dark", "lava_red", "lava_orange", "crust_color"]:
		surface.material.set_shader_parameter(key, profile.get(key))
	surface.material.set_shader_parameter("extent", extent)

func _changed() -> void:
	if surface != null: surface.material.set_shader_parameter("age", age)
