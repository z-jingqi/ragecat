extends Node2D
const BoltState = preload("res://effects/VFX-03_projectile/projectile_state.gd")
const BoltView = preload("res://effects/VFX-03_projectile/projectile_view.gd")
const STEP := 1.0 / 120.0
var bolt := BoltState.new()
var actual: Node2D
var detail: Node2D
var preset_data: Dictionary
var sliders := {}
var value_labels := {}
var speed := 180.0
var desired_angle := 0.0
var heading := 0.0
var position_world := Vector2.ZERO
var paused := false
var loop := true
var tracking := false
var turning := false
var stopped := false
var accumulator := 0.0
var cycle_time := 0.0
var demo_time := 0.0
var auto_demo := false
var auto_stage := -1
var status: Label
var section: Label
var pause_button: Button
var tracking_button: Button
var stop_button: Button
var preset_picker: OptionButton
var background_index := 0

func _ready() -> void:
	preset_data = JSON.parse_string(FileAccess.get_file_as_string("res://effects/VFX-03_projectile/presets.json"))
	auto_demo = "--projectile-auto" in OS.get_cmdline_user_args()
	RenderingServer.set_default_clear_color(Color("20262b"))
	actual = BoltView.new()
	actual.state = bolt
	actual.anchor = Vector2(170, 140)
	add_clipped_view(actual, Rect2(20, 106, 310, 76))
	detail = BoltView.new()
	detail.state = bolt
	detail.anchor = Vector2(205, 270)
	detail.display_scale = 4.0
	add_clipped_view(detail, Rect2(20, 214, 310, 114))
	make_ui()
	apply_preset(0)
	restart()

func add_clipped_view(view: Node2D, rect: Rect2) -> void:
	var clip := Control.new()
	clip.position = rect.position
	clip.size = rect.size
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.anchor -= rect.position
	add_child(clip)
	clip.add_child(view)

func label_at(text: String, p: Vector2, size: int = 12, color: Color = Color("dce3e7")) -> Label:
	var n := Label.new()
	n.text = text
	n.position = p
	n.add_theme_font_size_override("font_size", size)
	n.add_theme_color_override("font_color", color)
	n.set_meta("base_color", color)
	add_child(n)
	return n
func button_at(text: String, x: float, y: float, width: float, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.position = Vector2(x, y)
	b.size = Vector2(width, 25)
	b.add_theme_font_size_override("font_size", 11)
	b.pressed.connect(action)
	add_child(b)
	return b
func slider_at(key: String, title: String, y: float, low: float, high: float, step: float, value: float) -> void:
	value_labels[key] = label_at(title, Vector2(350, y), 11)
	var slider := HSlider.new()
	slider.position = Vector2(475, y + 1)
	slider.size = Vector2(143, 18)
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.value = value
	slider.value_changed.connect(func(v: float):
		if key == "speed": speed = v
		else: bolt.configure({key: v})
		update_labels())
	add_child(slider)
	sliders[key] = slider
func make_ui() -> void:
	label_at("03 / ENERGY BOLT", Vector2(20, 12), 20, Color("e5fff3"))
	label_at("Rounded head. Short live tail. No sprite sheet.", Vector2(20, 40), 11, Color("aab7be"))
	section = label_at("ACTUAL SIZE / 1x / FREE FLIGHT", Vector2(20, 77), 11, Color("91a1ab"))
	label_at("TRACKING CAMERA / 4x NEAREST", Vector2(20, 194), 11, Color("91a1ab"))
	label_at("LIVE PARAMETERS", Vector2(350, 65), 12, Color("e5fff3"))
	pause_button = button_at("Pause", 350, 14, 60, toggle_pause)
	button_at("+ Frame", 416, 14, 70, step_frame)
	button_at("Reset", 492, 14, 60, reset_all)
	button_at("Replay", 558, 14, 62, restart)
	slider_at("speed", "Speed", 94, 0, 360, 10, 180)
	slider_at("head_radius", "Head radius", 120, 2, 8, 0.5, 4.5)
	slider_at("tail_min", "Tail min", 146, 0, 30, 1, 9)
	slider_at("tail_max", "Tail max", 172, 0, 42, 1, 27)
	slider_at("speed_response", "Response / s", 198, 0.01, 0.3, 0.005, 0.055)
	slider_at("flow_strength", "Inner flow", 224, 0, 1, 0.05, 0.8)
	slider_at("lifetime", "Lifetime / s", 250, 0.1, 3, 0.1, 1.6)
	tracking_button = button_at("Track", 350, 280, 60, func(): tracking = not tracking; sync_views())
	button_at("Turn", 416, 280, 60, func(): turning = not turning)
	stop_button = button_at("Stop", 482, 280, 60, func(): stopped = true; bolt.stop())
	button_at("Teleport", 548, 280, 72, teleport)
	preset_picker = OptionButton.new()
	preset_picker.position = Vector2(350, 311)
	preset_picker.size = Vector2(139, 26)
	preset_picker.add_theme_font_size_override("font_size", 11)
	for preset in preset_data.presets:
		preset_picker.add_item(preset.label)
	preset_picker.item_selected.connect(apply_preset)
	add_child(preset_picker)
	button_at("BG", 495, 311, 40, cycle_background)
	button_at("Loop", 541, 311, 79, func(): loop = not loop)
	status = label_at("", Vector2(20, 334), 10, Color("aab7be"))

func update_labels() -> void:
	var names := {"speed": "Speed / px/s", "head_radius": "Head / px", "tail_min": "Tail min / px", "tail_max": "Tail max / px", "speed_response": "Response / s", "flow_strength": "Inner flow", "lifetime": "Lifetime / s"}
	for key in sliders:
		var value: float = speed if key == "speed" else bolt.get(key)
		value_labels[key].text = "%s  %s" % [names[key], str(snappedf(value, 0.005))]
		sliders[key].set_value_no_signal(value)
func apply_preset(index: int) -> void:
	var values: Dictionary = preset_data.defaults.duplicate()
	values.merge(preset_data.presets[index].overrides, true)
	bolt.configure(values)
	update_labels()
func restart() -> void:
	heading = 0.0
	cycle_time = 0.0
	position_world = Vector2(-124.0, 0.0)
	bolt.reset(position_world, Vector2(speed, 0))
	stopped = false
	bolt.paused = paused
	sync_views()
func reset_all() -> void:
	background_index = 0
	set_background()
	paused = false
	loop = true
	tracking = false
	turning = false
	speed = 180.0
	pause_button.text = "Pause"
	preset_picker.select(0)
	apply_preset(0)
	restart()
func toggle_pause() -> void:
	paused = not paused
	bolt.paused = paused
	pause_button.text = "Play" if paused else "Pause"
func step_frame() -> void:
	paused = true
	bolt.paused = false
	simulate(1.0 / 60.0)
	bolt.paused = true
	pause_button.text = "Play"
func teleport() -> void:
	position_world += Vector2(130.0, -20.0)
	bolt.tick(STEP, position_world, Vector2.from_angle(heading) * speed)
	sync_views()
func cycle_background() -> void:
	background_index = (background_index + 1) % 3
	set_background()
func set_background() -> void:
	for child in get_children():
		if child is Label:
			child.add_theme_color_override("font_color", Color("273840") if background_index == 2 else child.get_meta("base_color", Color("dce3e7")))
	RenderingServer.set_default_clear_color([Color("20262b"), Color("090d12"), Color("eeeeec")][background_index])
func _process(delta: float) -> void:
	if not paused:
		accumulator += minf(delta, 0.1)
		while accumulator >= STEP:
			accumulator -= STEP
			simulate(STEP)
	sync_views()
func simulate(delta: float) -> void:
	demo_time += delta
	if auto_demo:
		update_auto()
	cycle_time += delta
	if not stopped and bolt.active and not bolt.exiting:
		desired_angle = sin(cycle_time * 4.0) * 0.68 if turning else 0.0
		heading = rotate_toward(heading, desired_angle, 1.6 * delta)
		position_world += Vector2.from_angle(heading) * speed * delta
	bolt.tick(delta, position_world, Vector2.from_angle(heading) * speed if not stopped else Vector2.ZERO)
	if not bolt.active and loop and not stopped and cycle_time > bolt.lifetime + 0.20:
		restart()
func update_auto() -> void:
	var stage := 0 if demo_time < 2.0 else (1 if demo_time < 4.0 else (2 if demo_time < 6.0 else (3 if demo_time < 8.0 else (4 if demo_time < 10.0 else 5))))
	if stage != auto_stage:
		auto_stage = stage
		tracking = stage > 0
		turning = stage == 4
		speed = [180.0, 180.0, 60.0, 320.0, 180.0, 180.0][stage]
		if stage == 5:
			stopped = true
			bolt.stop()
		else:
			restart()
		update_labels()
	if demo_time >= 10.6 and "--projectile-quit" in OS.get_cmdline_user_args():
		get_tree().quit()
func sync_views() -> void:
	actual.camera = bolt.world_position if tracking else Vector2.ZERO
	detail.camera = bolt.world_position
	actual.sync()
	detail.sync()
	if section != null:
		var mode := "TURNING" if turning else ("TRACKED" if tracking else "FREE FLIGHT")
		section.text = "ACTUAL SIZE / 1x / %s" % mode
		tracking_button.text = "Untrack" if tracking else "Track"
		status.text = "%d px/s  |  tail %.1f px  |  %s  |  %s" % [int(bolt.velocity.length()), bolt.tail_length, "PAUSED" if paused else ("STOPPED" if stopped else "LIVE"), "LOOP" if loop else "ONCE"]
