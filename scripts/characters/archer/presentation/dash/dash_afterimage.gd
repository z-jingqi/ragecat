class_name ArcherDashAfterimage
extends Node2D
var lifetime := 0.12
var opacity := 0.12
var age := 0.0
var texture: Texture2D
var region := Rect2()
func capture(view: ArcherLayeredPoseView, settings: ArcherDashFeedbackDefinition) -> void:
	lifetime = maxf(settings.afterimage_lifetime, 0.001)
	opacity = clampf(settings.afterimage_opacity, 0.0, 0.3)
	texture = view._quad_texture
	material = view.material.duplicate()
	global_transform = view.global_transform
	region = Rect2(-view.appearance.upper.pivot * view.appearance.display_scale,
		Vector2(view.appearance.upper.canvas_size) * view.appearance.display_scale)
	modulate.a = opacity
	queue_redraw()
func _process(delta: float) -> void:
	age += maxf(0.0, delta)
	modulate.a = opacity * pow(maxf(0.0, 1.0 - age / lifetime), 2.0)
	if age >= lifetime: queue_free()
func _draw() -> void:
	if texture != null: draw_texture_rect(texture, region, false)
