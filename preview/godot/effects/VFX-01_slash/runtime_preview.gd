extends Node2D
## Runtime adapter preview: isolated slash at actual Mountains and Seas world scale.
const Slash := preload("slash_effect.gd")
var effects: Array[Node2D] = []
var elapsed := 0.0
var cycle := -1
var captions: Array[Label] = []
func _ready() -> void:
	get_window().size = Vector2i(1280,720)
	get_window().content_scale_size = Vector2i(1280,720)
	label("RAGECAT / REUSABLE PIXEL SLASH",Vector2(48,35),28,Color("f5c56b"))
	label("Native Godot render · 115 world-unit reach · 2 world units / art pixel · 180 ms",Vector2(48,78),19,Color("b7c5c8"))
	for i in range(3):
		var x := 230 + i * 410
		label(["BASE / 97°", "WIDE / 143°", "RETURN / REVERSED"][i],Vector2(x-120,167),22,Color("eef0e8"))
		label("Actual game size",Vector2(x-80,502),18,Color("8eaaaa"))
	label("One clean crescent. No character animation, lab geometry, hitbox, or damage callback.",Vector2(48,620),20,Color("b7c5c8"))
	label("Direction rotates each cut. Runtime local coordinates follow the scene/camera transform.",Vector2(48,652),18,Color("8eaaaa"))
func label(text: String, point: Vector2, size: int, tint: Color) -> void:
	var node := Label.new()
	node.text = text; node.position = point
	node.add_theme_font_size_override("font_size",size)
	node.add_theme_color_override("font_color",tint)
	add_child(node)
func _physics_process(delta: float) -> void:
	elapsed += delta
	for i in range(effects.size()-1,-1,-1):
		effects[i].advance(delta)
		if effects[i].done:
			effects[i].queue_free(); effects.remove_at(i)
	var current := int(elapsed / .65)
	if current != cycle:
		cycle = current
		for i in range(3):
			var fx := Slash.new()
			add_child(fx)
			var angle := float(current % 8) * TAU / 8.0
			fx.play(Vector2(230+i*410,350),Vector2.from_angle(angle),115.0,1.25 if i == 1 else .85,{"pixel_size":2.0,"curvature":1.0,"reverse":i==2})
			effects.append(fx)
	queue_redraw()
func _draw() -> void:
	draw_rect(Rect2(0,0,1280,720),Color("10202a"))
	for x in range(0,1280,32): draw_line(Vector2(x,125),Vector2(x,575),Color("172b34"))
	for y in range(125,576,32): draw_line(Vector2(0,y),Vector2(1280,y),Color("172b34"))
	for i in range(3):
		var center := Vector2(230+i*410,350)
		draw_circle(center,18,Color("385c65"))
		draw_rect(Rect2(center-Vector2(6,10),Vector2(12,20)),Color("9fc2ca"))
