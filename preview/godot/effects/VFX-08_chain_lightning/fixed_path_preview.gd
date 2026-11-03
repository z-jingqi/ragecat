extends Node2D
const FixedPath := preload("fixed_path.gd")
const Fixture := preload("enemy.gd")
var snapshot_path := PackedVector2Array([Vector2(10, 65), Vector2(43, 61), Vector2(76, 29), Vector2(100, 70), Vector2(132, 35), Vector2(164, 63)])
var fx: Node2D
var viewport: SubViewport
var paused := false
var slow := false
var dark := true
var seed := 31
var timer := 0.0
var elapsed := 0.0
var auto_demo := false
var status: Label
var pause_button: Button
var speed_button: Button

func label(text: String, at: Vector2, font_size: int = 11) -> Label:
	var item := Label.new()
	item.text = text
	item.position = at
	item.add_theme_font_size_override("font_size", font_size)
	add_child(item)
	return item

func button(text: String, at: Vector2, width: float, action: Callable) -> Button:
	var item := Button.new()
	item.text = text
	item.position = at
	item.size = Vector2(width, 26)
	item.add_theme_font_size_override("font_size", 11)
	item.pressed.connect(action)
	add_child(item)
	return item

func _ready() -> void:
	auto_demo = "--fixed-path-auto" in OS.get_cmdline_user_args()
	viewport = SubViewport.new()
	viewport.size = Vector2i(190, 96)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	for i in range(1, snapshot_path.size()):
		var fixture := Fixture.new()
		fixture.position = snapshot_path[i]
		fixture.order = i - 1
		viewport.add_child(fixture)
	fx = FixedPath.new()
	viewport.add_child(fx)
	for item in [{"position": Vector2(18, 127), "scale": 1}, {"position": Vector2(238, 80), "scale": 2}]:
		var texture := TextureRect.new()
		texture.position = item.position
		texture.size = Vector2(190, 96) * item.scale
		texture.texture = viewport.get_texture()
		texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(texture)
	label("08 / FIXED-PATH THUNDER", Vector2(18, 10), 18)
	label("Caller snapshots / canonical pixel arc / no target selection or hit callbacks", Vector2(18, 38))
	label("ACTUAL / 1x", Vector2(18, 102))
	label("2x NEAREST", Vector2(238, 58))
	label("Numbers show caller-supplied point order", Vector2(18, 245), 10)
	pause_button = button("Pause", Vector2(18, 280), 65, toggle_pause)
	button("Replay", Vector2(90, 280), 65, trigger)
	button("Reset", Vector2(162, 280), 65, reset_all)
	button("+Frame", Vector2(234, 280), 65, step)
	speed_button = button("Slow x4", Vector2(306, 280), 80, toggle_speed)
	button("Seed+", Vector2(393, 280), 65, func(): seed += 1; trigger())
	button("Clear", Vector2(465, 280), 65, func(): fx.reset(); paused = true; pause_button.text = "Play")
	button("BG", Vector2(537, 280), 65, func(): dark = not dark; set_bg())
	status = label("", Vector2(18, 321), 12)
	set_bg()
	trigger()

func set_bg() -> void:
	RenderingServer.set_default_clear_color(Color("202b35") if dark else Color("e1e5dd"))
	for item in get_children():
		if item is Label: item.add_theme_color_override("font_color", Color("e0e7e8") if dark else Color("26323a"))

func trigger() -> void:
	fx.play_path(snapshot_path, {"duration": 0.72 if slow else 0.18, "seed": seed})
	fx.paused = paused
	timer = 0.0

func toggle_pause() -> void:
	paused = not paused
	fx.paused = paused
	pause_button.text = "Play" if paused else "Pause"

func toggle_speed() -> void:
	slow = not slow
	speed_button.text = "Actual speed" if slow else "Slow x4"
	trigger()

func reset_all() -> void:
	paused = false
	slow = false
	seed = 31
	pause_button.text = "Pause"
	speed_button.text = "Slow x4"
	trigger()

func step() -> void:
	paused = true
	pause_button.text = "Play"
	fx.paused = false
	if fx.done: trigger(); fx.paused = false
	fx.advance(1.0 / 60)
	fx.paused = true

func _process(delta: float) -> void:
	elapsed += delta
	if auto_demo and elapsed >= 4.0 and not slow: toggle_speed()
	if not paused:
		timer += delta
		fx.advance(delta)
		if timer >= (1.6 if slow else 1.0): trigger()
	status.text = "%s  /  %03d ms  /  fixed snapshot: 5 links  /  external clock" % ["SLOW REVIEW x4" if slow else "GAME FEEDBACK", roundi(fx.age * 1000)]
