class_name ArcherLayeredPoseView
extends Node2D
## Displays two independently sampled pose layers. It never advances combat or animation.
const LAYER_SHADER: Shader = preload("res://shaders/characters/archer/layered_pose.gdshader")
var appearance: ArcherAppearanceDefinition
var _pose_material: ShaderMaterial
var _drawable := false
var _quad_texture: Texture2D

func configure(value: ArcherAppearanceDefinition) -> void:
	appearance = value
	_pose_material = ShaderMaterial.new()
	_pose_material.shader = LAYER_SHADER
	material = _pose_material
	_drawable = false
	queue_redraw()

func show_pose(upper_clip: StringName, upper_phase: float, lower_clip: StringName,
		lower_phase: float, lower_looped: bool = false, shared_bob: Vector2 = Vector2.ZERO) -> bool:
	if appearance == null or appearance.upper == null or appearance.lower == null:
		return _hide_invalid()
	if appearance.upper.canvas_size != appearance.lower.canvas_size or appearance.upper.pivot != appearance.lower.pivot:
		return _hide_invalid()
	var upper_sample := appearance.upper.sample(upper_clip, upper_phase)
	var lower_sample := appearance.lower.sample(lower_clip, lower_phase, lower_looped)
	if not _set_layer("upper", upper_sample) or not _set_layer("lower", lower_sample):
		return _hide_invalid()
	# This transform is presentation-only. Parent actor position is untouched.
	_quad_texture = upper_sample.color.texture
	position = shared_bob
	_drawable = true
	queue_redraw()
	return true

func _set_layer(prefix: String, sample: Dictionary) -> bool:
	if sample.is_empty(): return false
	var color: Dictionary = sample.get("color", {})
	var depth: Dictionary = sample.get("depth", {})
	if color.is_empty() or depth.is_empty(): return false
	_pose_material.set_shader_parameter(prefix + "_packed_depth", sample.get("packed_depth", false))
	_pose_material.set_shader_parameter(prefix + "_color", color.texture)
	_pose_material.set_shader_parameter(prefix + "_depth", depth.texture)
	_pose_material.set_shader_parameter(prefix + "_region", color.region)
	_pose_material.set_shader_parameter(prefix + "_depth_region", depth.region)
	return true

func _hide_invalid() -> bool:
	_drawable = false
	queue_redraw()
	return false

func _draw() -> void:
	if not _drawable: return
	var size := Vector2(appearance.upper.canvas_size) * appearance.display_scale
	var origin := -appearance.upper.pivot * appearance.display_scale
	# A texture-backed rectangle supplies normalized UVs to the layer shader.
	draw_texture_rect(_quad_texture, Rect2(origin, size), false)

func has_pose() -> bool:
	return _drawable

func clear_pose() -> void:
	position = Vector2.ZERO
	_hide_invalid()
