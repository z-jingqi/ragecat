extends Node2D
const History = preload("res://effects/VFX-02_weapon_trail/trail_history.gd")
const View = preload("res://effects/VFX-02_weapon_trail/trail_view.gd")
var history := History.new()
var view: Node2D
var detail: Node2D
var paused := false
var stopped := false
var speed := 1.0
var direction := 1.0
var angle := -1.2
var motion_clock := 0.0
var root_world := Vector2.ZERO
var tip_world := Vector2.ZERO
var anchor := Vector2.ZERO
var camera_pan := false
var auto_demo := false
var auto_time := 0.0
var status: Label
var pause_button: Button
var stop_button: Button
var sliders := {}
var labels := {}
var fade_check: CheckButton
var palette: OptionButton
var stage := 0
var presets: Dictionary
var preset_picker: OptionButton

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("20262b"))
	Engine.max_fps = 60
	auto_demo = "--trail-auto" in OS.get_cmdline_user_args()
	presets = JSON.parse_string(FileAccess.get_file_as_string("res://effects/VFX-02_weapon_trail/presets.json"))["presets"]
	view = View.new()
	view.position = Vector2(76, 169)
	view.history = history
	add_child(view)
	detail = View.new()
	detail.position = Vector2(230, 169)
	detail.history = history
	detail.display_scale = 2.0
	add_child(detail)
	make_ui()
	reset_baseline()

func label_at(text: String, pos: Vector2, size: int = 12, color: Color = Color("dce3e7")) -> Label:
	var node := Label.new()
	node.text = text
	node.position = pos
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	add_child(node)
	return node

func button_at(text: String, x: float, y: float, width: float, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = Vector2(x, y)
	button.size = Vector2(width, 26)
	button.add_theme_font_size_override("font_size", 12)
	button.pressed.connect(action)
	add_child(button)
	return button

func slider_at(key: String, title: String, y: float, lo: float, hi: float, step: float, initial: float, action: Callable) -> void:
	var text := label_at(title, Vector2(350, y), 11)
	labels[key] = text
	var slider := HSlider.new()
	slider.position = Vector2(470, y + 1)
	slider.size = Vector2(148, 16)
	slider.min_value = lo
	slider.max_value = hi
	slider.step = step
	slider.value = initial
	slider.value_changed.connect(func(v: float):
		action.call(v)
		text.text = "%s  %s" % [title, str(snappedf(v, step))])
	add_child(slider)
	sliders[key] = slider
	text.text = "%s  %s" % [title, str(initial)]

func make_ui() -> void:
	label_at("02 / WEAPON TRAIL", Vector2(20, 12), 20, Color("fff4ce"))
	label_at("Real base + tip history. No sprite sheet.", Vector2(20, 40), 12, Color("aab7be"))
	label_at("GAME SIZE  /  1x", Vector2(26, 97), 11, Color("91a1ab"))
	label_at("PIXEL DETAIL  /  2x", Vector2(172, 70), 11, Color("91a1ab"))
	label_at("Thin history → full blade width", Vector2(20, 282), 12, Color("c4c8bb"))
	label_at("Stop: no new ink. Teleport: no bridge.", Vector2(20, 302), 11, Color("91a1ab"))
	label_at("LIVE PARAMETERS", Vector2(350, 66), 13, Color("fff4ce"))
	preset_picker = OptionButton.new()
	preset_picker.position = Vector2(492, 62)
	preset_picker.size = Vector2(130, 24)
	preset_picker.add_theme_font_size_override("font_size", 11)
	for title in ["Clean blade", "Short jade", "Soft exit"]:
		preset_picker.add_item(title)
	preset_picker.item_selected.connect(func(i): apply_preset(["clean_blade", "short_cool", "soft_exit"][i]))
	add_child(preset_picker)
	pause_button = button_at("Pause", 350, 14, 64, toggle_pause)
	button_at("+ Frame", 420, 14, 74, step_frame)
	button_at("Reset", 500, 14, 58, reset_baseline)
	button_at("Turn", 564, 14, 58, turn)
	slider_at("speed", "Speed", 94, 0.2, 2.5, 0.05, 1.0, func(v): speed = v)
	slider_at("life", "Life / s", 120, 0.02, 0.6, 0.01, 0.16, func(v): history.lifetime = v)
	slider_at("width", "Blade width", 146, 0.05, 1.0, 0.01, 0.68, func(v): view.width_fraction = v; detail.width_fraction = v)
	slider_at("taper", "Taper", 172, 0.25, 4.0, 0.05, 1.35, func(v): view.taper_power = v; detail.taper_power = v)
	slider_at("sample", "Spacing / u", 198, 0.005, 0.5, 0.005, 0.045, func(v): history.min_sample_distance = v)
	slider_at("samples", "Sample cap", 224, 2, 64, 1, 32, func(v): history.max_samples = int(v))
	slider_at("opacity", "Opacity", 250, 0, 1, 0.05, 1, func(v): view.opacity = v; detail.opacity = v)
	stop_button = button_at("Stop", 350, 280, 62, toggle_stop)
	button_at("Teleport", 418, 280, 80, teleport)
	button_at("Pan", 504, 280, 54, func(): camera_pan = not camera_pan)
	palette = OptionButton.new()
	palette.position = Vector2(564, 280)
	palette.size = Vector2(58, 26)
	palette.add_theme_font_size_override("font_size", 11)
	palette.add_item("Gold")
	palette.add_item("Jade")
	palette.item_selected.connect(set_palette)
	add_child(palette)
	fade_check = CheckButton.new()
	fade_check.text = "Stepped alpha exit"
	fade_check.position = Vector2(350, 314)
	fade_check.add_theme_font_size_override("font_size", 11)
	fade_check.toggled.connect(func(v): view.stepped_fade = v; detail.stepped_fade = v)
	add_child(fade_check)
	status = label_at("", Vector2(20, 334), 11, Color("aab7be"))

func reset_baseline() -> void:
	history.begin_trail()
	history.clock = 0.0
	history.teleport_resets = 0
	paused = false
	stopped = false
	direction = 1.0
	angle = -1.2
	motion_clock = 0.0
	anchor = Vector2.ZERO
	camera_pan = false
	pause_button.text = "Pause"
	stop_button.text = "Stop"
	for pair in [["speed", 1.0], ["life", 0.16], ["width", 0.68], ["taper", 1.35], ["sample", 0.045], ["samples", 32], ["opacity", 1.0]]:
		sliders[pair[0]].value = pair[1]
	speed = 1.0
	history.lifetime = 0.16
	history.min_sample_distance = 0.045
	history.max_samples = 32
	for v in [view, detail]:
		v.width_fraction = 0.68
		v.taper_power = 1.35
		v.opacity = 1.0
		v.stepped_fade = false
		v.camera_world = Vector2.ZERO
	fade_check.set_pressed_no_signal(false)
	palette.select(0)
	preset_picker.select(0)
	apply_preset("clean_blade")
	update_pose()
	history.submit_pose(root_world, tip_world)
	sync_views()

func apply_preset(name: String) -> void:
	var config: Dictionary = presets[name]
	var mapping := {"life": "lifetime", "width": "width_fraction", "taper": "taper_power", "sample": "min_sample_distance", "samples": "max_samples", "opacity": "opacity"}
	for key in mapping:
		sliders[key].value = config[mapping[key]]
	history.teleport_distance = float(config["teleport_distance"])
	for v in [view, detail]:
		v.pixels_per_unit = float(config["pixels_per_unit"])
		v.core = Color(config["core"])
		v.body = Color(config["body"])
		v.edge = Color(config["edge"])
		v.stepped_fade = config["fade_mode"] == "stepped"
	fade_check.set_pressed_no_signal(config["fade_mode"] == "stepped")
	palette.select(1 if name == "short_cool" else 0)

func set_palette(index: int) -> void:
	for v in [view, detail]:
		v.core = Color("fff4ce") if index == 0 else Color("e6fff9")
		v.body = Color("edbb61") if index == 0 else Color("77d7ce")
		v.edge = Color("ac6f35") if index == 0 else Color("378e96")

func toggle_pause() -> void:
	paused = not paused
	pause_button.text = "Play" if paused else "Pause"

func step_frame() -> void:
	paused = true
	pause_button.text = "Play"
	simulate(1.0 / 60.0)

func toggle_stop() -> void:
	stopped = not stopped
	stop_button.text = "Move" if stopped else "Stop"

func turn() -> void:
	direction *= -1.0

func teleport() -> void:
	anchor = Vector2(4.1, 0.0) if anchor.x == 0.0 else Vector2.ZERO
	view.camera_world = anchor
	detail.camera_world = anchor
	update_pose()
	history.submit_pose(root_world, tip_world)
	sync_views()

func update_pose() -> void:
	# The demo supplies an actual rotating/translating weapon; the effect never reads angle.
	var pivot := anchor + Vector2(sin(motion_clock * 1.6) * 0.25, cos(motion_clock * 1.1) * 0.15)
	var axis := Vector2(cos(angle), sin(angle))
	root_world = pivot + axis * 0.55
	tip_world = pivot + axis * 2.25

func simulate(dt: float) -> void:
	history.advance(dt)
	if not stopped:
		motion_clock += dt * speed
		angle += dt * 7.4 * speed * direction
		update_pose()
	history.submit_pose(root_world, tip_world)
	if camera_pan:
		var pan := Vector2(sin(history.clock) * 0.45, cos(history.clock) * 0.2)
		view.camera_world = anchor + pan
		detail.camera_world = anchor + pan
	else:
		view.camera_world = anchor
		detail.camera_world = anchor
	sync_views()

func sync_views() -> void:
	view.sync()
	detail.sync()
	status.text = "%s  |  %02d / %02d poses  |  breaks %d" % ["PAUSED" if paused else ("STILL / DECAY" if stopped else "REALTIME"), history.count, history.max_samples, history.teleport_resets]
	queue_redraw()

func _process(dt: float) -> void:
	if auto_demo:
		auto_time += dt
		var next := int(auto_time / 2.0)
		if next != stage:
			stage = next
			match stage:
				1: sliders["speed"].value = 1.7
				2: turn()
				3: toggle_stop()
				4: toggle_stop(); teleport()
				5: reset_baseline()
	if not paused:
		simulate(dt)
	else:
		sync_views()

func _draw() -> void:
	draw_line(Vector2(334, 68), Vector2(334, 338), Color("39434b"), 1.0)
	for v in [view, detail]:
		if v == null:
			continue
		var a: Vector2 = v.position + v.to_canvas(root_world)
		var b: Vector2 = v.position + v.to_canvas(tip_world)
		# Minimal untextured demonstration blade; no character art dependency.
		draw_line(a.round(), b.round(), Color("c2c9c7"), v.display_scale, false)
		var pivot: Vector2 = v.position + v.to_canvas(anchor)
		draw_rect(Rect2(pivot.round() - Vector2.ONE * 2.0 * v.display_scale, Vector2.ONE * 4.0 * v.display_scale), Color("73818a"))
