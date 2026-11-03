extends Node2D
## HD native preview. Movie capture needs a 1280x720 initial project viewport.
const Burn := preload("ground_burn.gd")
var effects: Array[Node2D] = []
var elapsed := 0.0
var paused := false
var slow := false
var light := false
var radius := 36.0
var intensity := 0.8
var height := 14.0
var lifetime := 4.0
var clock_label: Label
var pause_button: Button
var cycle := 0
func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	get_window().content_scale_size = Vector2i(1280, 720)
	label("RAGECAT  /  SOLAR GROUND FIRE", Vector2(48, 32), 28, Color("ffcd80"))
	label("Procedural pixel flames · game-owned radius and clock · no damage or collision", Vector2(48, 76), 18, Color("bdcace"))
	label("01 / ACTUAL SIZE", Vector2(82, 144), 18, Color("e9d1af"))
	label("02 / 2× NEAREST DETAIL", Vector2(358, 144), 18, Color("e9d1af"))
	label("03 / OVERLAPPING ZONES", Vector2(804, 144), 18, Color("e9d1af"))
	label("36-world-unit radius", Vector2(76, 414), 17, Color("9aabae"))
	label("Same seed and exact same time", Vector2(337, 414), 17, Color("9aabae"))
	label("Each full outline remains visible", Vector2(790, 414), 17, Color("9aabae"))
	var detail := Node2D.new()
	detail.position = Vector2(490, 294)
	detail.scale = Vector2(2, 2)
	add_child(detail)
	var overlap := Node2D.new()
	overlap.position = Vector2(960, 294)
	overlap.scale = Vector2(2, 2)
	add_child(overlap)
	for container in [self, detail, overlap, overlap]:
		var fx := Burn.new()
		container.add_child(fx)
		effects.append(fx)
	clock_label = label("", Vector2(48, 485), 20, Color("edc58d"))
	pause_button = button("Pause", Vector2(48, 536), func(): paused = not paused; pause_button.text = "Resume" if paused else "Pause")
	button("+1 frame", Vector2(168, 536), func(): paused = true; pause_button.text = "Resume"; tick(1.0 / 60.0))
	button("Replay", Vector2(288, 536), replay)
	button("0.25× / 1×", Vector2(408, 536), func(): slow = not slow)
	button("Background", Vector2(528, 536), func(): light = not light; queue_redraw())
	button("Clear", Vector2(648, 536), func(): paused = true; pause_button.text = "Resume"; clear_effects())
	slider("Radius", 16, 90, radius, Vector2(48, 600), func(v: float): radius = v; replay())
	slider("Flame height", 0, 30, height, Vector2(444, 600), func(v: float): height = v; replay())
	slider("Intensity", 0, 1, intensity, Vector2(840, 600), func(v: float): intensity = v; replay())
	label("Bounded to 24 tongues / two surfaces per zone. Pause and expiry are controlled by the caller.", Vector2(48, 675), 16, Color("91a4aa"))
	replay()

func replay() -> void:
	elapsed = 0.0
	var positions := [Vector2(168,294),Vector2.ZERO,Vector2(-23,8),Vector2(23,-7)]
	for i in range(effects.size()):
		effects[i].play(positions[i], radius * (1.3 if i == 3 else 1.0), lifetime, {"seed": 37 if i < 3 else 71, "intensity": intensity, "flame_height": height, "pixel_size": 2.0})
	update_clock()

func clear_effects() -> void:
	for fx in effects: fx.clear()
	clock_label.text = "CLEARED / no lingering flames, outlines or timers"

func _process(delta: float) -> void:
	if not paused: tick(delta * (0.25 if slow else 1.0))

func tick(delta: float) -> void:
	elapsed += delta
	if elapsed >= lifetime + 0.65:
		cycle += 1
		replay()
	else:
		for fx in effects: fx.seek(elapsed)
	update_clock()

func update_clock() -> void:
	clock_label.text = "GAME CLOCK  %.2fs / %.1fs   ·   %s   ·   %s" % [minf(elapsed,lifetime), lifetime, "EXPIRED / CLEAR" if elapsed >= lifetime else "BURNING", "0.25×" if slow else "1×"]

func label(text: String, at: Vector2, font_size: int, color: Color) -> Label:
	var node := Label.new()
	node.text = text; node.position = at
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	add_child(node)
	return node

func button(text: String, at: Vector2, callback: Callable) -> Button:
	var node := Button.new()
	node.text = text; node.position = at; node.size = Vector2(112,34)
	node.add_theme_font_size_override("font_size", 17)
	node.pressed.connect(callback); add_child(node)
	return node

func slider(title: String, low: float, high: float, value: float, at: Vector2, callback: Callable) -> void:
	var caption := label("%s  %.2f" % [title,value],at,18,Color("d8c5a8"))
	var node := HSlider.new()
	node.min_value = low; node.max_value = high; node.step = 0.01 if high <= 1 else 1.0
	node.value = value; node.position = at + Vector2(0,31); node.size = Vector2(330,24)
	node.value_changed.connect(func(v: float): caption.text = "%s  %.2f" % [title,v]; callback.call(v))
	add_child(node)

func _draw() -> void:
	draw_rect(Rect2(0,0,1280,720),Color("17262c"))
	draw_rect(Rect2(36,192,1208,200),Color("a4aaa1") if light else Color("263d3e"))
	for x in range(36,1244,24): draw_line(Vector2(x,192),Vector2(x,392),Color("8d958a") if light else Color("2d4646"))
	for y in range(192,392,24): draw_line(Vector2(36,y),Vector2(1244,y),Color("8d958a") if light else Color("2d4646"))
