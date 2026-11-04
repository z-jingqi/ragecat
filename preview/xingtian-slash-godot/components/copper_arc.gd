extends "timed_component.gd"
const ARC_SHADER = preload("copper_arc.gdshader")
var surface: Polygon2D

func _rebuild() -> void:
	if surface == null:
		surface = Polygon2D.new()
		surface.polygon = PackedVector2Array([Vector2(-112,-112),Vector2(112,-112),Vector2(112,112),Vector2(-112,112)])
		var material_copy := ShaderMaterial.new()
		material_copy.shader = ARC_SHADER
		surface.material = material_copy
		add_child(surface)
	for key in ["facing_left","thread_duration","echo_enabled","thread_enabled","glint_enabled","glow_strength","highlight_color","tail_color","dark_color","radius","thickness","squash","roughness","pixel_size","duration","onset","hold","intensity","shape_seed","edge_color","body_color","inner_color","shade_color"]:
		surface.material.set_shader_parameter(key,profile.get(key))
	surface.material.set_shader_parameter("sweep",deg_to_rad(profile.sweep_degrees))
	surface.material.set_shader_parameter("sweep_center",deg_to_rad(profile.sweep_center_degrees))
	surface.material.set_shader_parameter("direction",deg_to_rad(profile.direction_degrees))
	surface.material.set_shader_parameter("reverse",profile.reverse)

func _refresh() -> void:
	super._refresh()
	if surface != null: surface.material.set_shader_parameter("age",elapsed)

func lifetime() -> float:
	return profile.duration+profile.thread_duration
