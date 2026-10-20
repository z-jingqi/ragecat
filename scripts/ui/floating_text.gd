class_name FloatingText
extends Node2D
var label := Label.new()
var life := 0.65
func setup(value: String, color: Color) -> void:
	label.text = value
	label.add_theme_color_override("font_color",color)
	label.add_theme_color_override("font_shadow_color",Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x",1)
	label.add_theme_constant_override("shadow_offset_y",2)
	label.add_theme_font_size_override("font_size",18)
	label.position=Vector2(-15,-20)
	add_child(label)
func _process(delta: float) -> void:
	life -= delta
	position.y -= delta*32
	modulate.a = minf(1.0,life*3)
	if life<=0: queue_free()
