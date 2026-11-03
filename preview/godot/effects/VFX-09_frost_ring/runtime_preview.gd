extends Node2D
## Standalone native review; no combat dependency. Source effect owns no clock.
const Frost := preload("frost_ring.gd")
var pulses: Array[Node2D] = []
var samples: Array[Node2D] = []
var elapsed := 0.0
var cycle := -1
var paused := false
var slow := false
var alternate_bg := false
var radius_offset := 0.0
var status: Label

func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	get_window().content_scale_size = Vector2i(1280, 720)
	label("RAGECAT / FROST RING", Vector2(48, 27), 28, Color("83d5e7"))
	label("Pure pixel pulse · 180 ms · exact 100 / 120 / 140 world-unit circles · no slow / freeze", Vector2(48, 70), 18, Color("acc2cc"))
	for i in range(3):
		var center := Vector2(220 + i * 420, 290)
		label(["LEVEL 1 / 100", "LEVEL 2 / 120", "LEVEL 3 / 140"][i], center + Vector2(-88, -174), 20, Color("e5fbff"))
		var effect := Frost.new()
		add_child(effect)
		pulses.append(effect)
	for i in range(4):
		var effect := Frost.new()
		add_child(effect)
		effect.play(Vector2(170 + i * 310, 555), 54.0, {"pixel_size": 1.0})
		effect.seek([0.02, 0.075, 0.12, 0.16][i])
		samples.append(effect)
		label(["20 ms / expand", "75 ms / full reach", "120 ms / fracture", "160 ms / clear"][i], Vector2(100 + i * 310, 626), 16, Color("9cb6c5"))
	status = label("", Vector2(48, 680), 17, Color("96afbf"))
	_restart()

func label(text: String, point: Vector2, size: int, tint: Color) -> Label:
	var node := Label.new()
	node.text = text
	node.position = point
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", tint)
	add_child(node)
	return node

func _restart() -> void:
	elapsed = 0.0
	cycle = -1
	for i in range(pulses.size()):
		pulses[i].play(Vector2(220 + i * 420, 290), 100.0 + i * 20.0 + radius_offset)

func _physics_process(delta: float) -> void:
	if not paused:
		var dt := delta * (0.25 if slow else 1.0)
		elapsed += dt
		var next := int(elapsed / 0.72)
		if next != cycle:
			cycle = next
			for i in range(pulses.size()):
				pulses[i].play(Vector2(220 + i * 420, 290), 100.0 + i * 20.0 + radius_offset)
		for effect in pulses: effect.advance(dt)
	status.text = "SPACE pause  ·  R restart  ·  T ¼ speed  ·  +/- radius  ·  B background    %s / %s / radius %+d" % ["PAUSED" if paused else "PLAY", "¼ SPEED" if slow else "1× SPEED", int(radius_offset)]
	queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo: return
	match event.keycode:
		KEY_SPACE: paused = not paused
		KEY_R: _restart()
		KEY_T: slow = not slow
		KEY_B: alternate_bg = not alternate_bg
		KEY_EQUAL, KEY_KP_ADD:
			radius_offset = minf(20.0, radius_offset + 10.0)
			_restart()
		KEY_MINUS, KEY_KP_SUBTRACT:
			radius_offset = maxf(-60.0, radius_offset - 10.0)
			_restart()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("253039") if alternate_bg else Color("10202a"))
	for x in range(0, 1280, 24): draw_line(Vector2(x, 110), Vector2(x, 455), Color("192e38"))
	for y in range(110, 456, 24): draw_line(Vector2(0, y), Vector2(1280, y), Color("192e38"))
	for i in range(3):
		var center := Vector2(220 + i * 420, 290)
		# Four witness ticks at the true bound, outside the rendered visual.
		for dir in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			var bound: Vector2 = center + dir * (100.0 + i * 20.0 + radius_offset)
			draw_line(bound + dir * 5, bound + dir * 10, Color("435d6b"), 1)
		draw_rect(Rect2(center - Vector2(6, 9), Vector2(12, 18)), Color("688b9c"))
		draw_rect(Rect2(center + Vector2(-4, -13), Vector2(8, 5)), Color("b9cbd1"))
	draw_line(Vector2(48, 466), Vector2(1232, 466), Color("304852"))
