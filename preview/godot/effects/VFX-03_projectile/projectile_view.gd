extends Node2D
const BoltShader = preload("res://effects/VFX-03_projectile/projectile.gdshader")
var state: RefCounted
var display_scale := 1.0
var anchor := Vector2.ZERO
var camera := Vector2.ZERO
var bounds := Rect2()
func _ready() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = BoltShader
	material = mat
func sync() -> void:
	if state == null or material == null:
		return
	position = anchor + ((state.world_position - camera).round() * display_scale)
	var points: PackedVector4Array = state.path_points()
	var count := points.size()
	bounds = Rect2(Vector2.ZERO, Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(Vector2(point.x, point.y))
	bounds = bounds.grow(state.head_radius + 2.0)
	bounds.position *= display_scale
	bounds.size *= display_scale
	points.resize(96)
	material.set_shader_parameter("path_points", points)
	material.set_shader_parameter("point_count", count)
	for key in ["head_radius", "flow_time", "flow_strength", "core_color", "body_color", "edge_color", "facing"]:
		material.set_shader_parameter(key, state.get(key))
	material.set_shader_parameter("tail_length", state.tail_length * state.envelope())
	material.set_shader_parameter("envelope", state.envelope())
	material.set_shader_parameter("display_scale", display_scale)
	queue_redraw()
func _draw() -> void:
	if state != null and state.active:
		draw_rect(bounds, Color.WHITE)
