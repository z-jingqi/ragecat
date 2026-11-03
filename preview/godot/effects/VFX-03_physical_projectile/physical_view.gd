extends Node2D
const PhysicalShader = preload("physical.gdshader")
var state: RefCounted
var anchor := Vector2.ZERO
var camera := Vector2.ZERO
var display_scale := 1.0
var bounds := Rect2()
var show_trail := true
func _ready() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = PhysicalShader
	material = mat
func sync() -> void:
	if state == null or material == null: return
	position = anchor + (state.world_position-camera).round()*display_scale
	var points: PackedVector4Array = state.render_points()
	var count := points.size()
	bounds = Rect2(Vector2.ZERO,Vector2.ZERO)
	for p in points: bounds=bounds.expand(Vector2(p.x,p.y))
	bounds=bounds.expand(-state.facing*22.0*state.body_scale).grow(maxf(state.trail_width,5.0*state.body_scale))
	bounds.position*=display_scale
	bounds.size*=display_scale
	points.resize(128)
	material.set_shader_parameter("path_points",points)
	material.set_shader_parameter("point_count",count if show_trail else 0)
	material.set_shader_parameter("body_visible",state.emitting)
	material.set_shader_parameter("display_scale",display_scale)
	for key in ["facing","body_kind","body_scale","trail_width","trail_length","taper","trail_color","trail_edge","metal_light","metal_dark","wood_color"]:
		material.set_shader_parameter(key,state.get(key))
	queue_redraw()
func _draw() -> void:
	if state != null and state.active: draw_rect(bounds,Color.WHITE)
