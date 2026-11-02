extends Control
## Thin visual adapter for the shared slash kernel, not the Unity runtime.
## All shape/palette edits are live. Timing edits restart the current cut.

const DEFAULTS := {
	"reach_px": 46.0, "thickness_px": 13.0, "sweep_degrees": 112.0,
	"curvature": 0.82, "direction_degrees": 0.0, "reverse": false,
	"start_seconds": 0.025, "burst_seconds": 0.065, "decay_seconds": 0.09,
	"edge_color": Color("fff4ce"), "body_color": Color("f5c56b"),
	"tail_color": Color("ba7637")
}
const PRESETS := [
	{"name": "01  ·  Clean cut", "values": {}},
	{"name": "02  ·  Reverse / 45°", "values": {"direction_degrees": 45.0, "reverse": true}},
	{"name": "03  ·  Flat / narrow", "values": {"curvature": 0.45, "sweep_degrees": 70.0, "reach_px": 50.0, "thickness_px": 10.0}},
	{"name": "04  ·  Heavy / wide", "values": {"sweep_degrees": 160.0, "thickness_px": 18.0, "start_seconds": 0.035, "burst_seconds": 0.08, "decay_seconds": 0.12}}
]
const INK := Color("eef0e8")
const MUTED := Color("858f91")
const ACCENT := Color("f5c56b")
const VIEW_ONE := Vector2(90, 112)
const VIEW_DETAIL := Vector2(250, 180)

var settings: Dictionary = DEFAULTS.duplicate()
var materials: Array[ShaderMaterial] = []
var inputs: Dictionary = {}
var age := 0.0
var cycle_age := 0.0
var paused := false
var slow := false
var looped := true
var syncing := false
var pause_button: Button
var preset_picker: OptionButton
var clock_label: Label
var phase_label: Label
var demo := false
var demo_time := 0.0
var demo_section := -1
var capture_dir := ""
var capture_frame := 0
var capture_pending := false

func _ready() -> void:
	_parse_args()
	_build_ui()
	_load_preset(0)

func _parse_args() -> void:
	var arguments := OS.get_cmdline_user_args()
	for i in range(arguments.size()):
		if arguments[i] == "--demo":
			demo = true
		elif arguments[i] == "--capture-dir" and i + 1 < arguments.size():
			capture_dir = arguments[i + 1]
		elif arguments[i].begins_with("--capture-dir="):
			capture_dir = arguments[i].trim_prefix("--capture-dir=")
	if not capture_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(capture_dir)

func _build_ui() -> void:
	var theme := Theme.new()
	theme.default_font_size = 11
	self.theme = theme
	_rect(Rect2(0, 0, 640, 360), Color("151c20"))
	_rect(Rect2(420, 0, 220, 360), Color("20292d"))
	_rect(Rect2(419, 0, 1, 360), Color("354044"))
	_label("VFX—01  /  SLASH", Vector2(20, 14), 18, INK)
	_label("Code-first  ·  hard pixels  ·  three tones", Vector2(20, 39), 11, MUTED)
	_label("GAME SIZE · 1×", Vector2(25, 69), 10, MUTED)
	_label("DETAIL · 2× NEAREST", Vector2(216, 69), 10, MUTED)
	# Pivot marks are scale references, never part of the delivered effect.
	_pivot(VIEW_ONE, 1)
	_pivot(VIEW_DETAIL, 2)
	var shader := load("res://slash.gdshader") as Shader
	for view in [{"center": VIEW_ONE, "scale": 1.0}, {"center": VIEW_DETAIL, "scale": 2.0}]:
		var canvas := ColorRect.new()
		canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("center_px", view.center)
		material.set_shader_parameter("display_scale", view.scale)
		canvas.material = material
		add_child(canvas)
		materials.append(material)
	clock_label = _label("", Vector2(20, 291), 12, INK)
	phase_label = _label("", Vector2(20, 310), 11, MUTED)
	_label("Pivot only · no glow, particles or baked frames", Vector2(20, 337), 10, MUTED)
	# The opaque panel is drawn after effects to keep controls readable.
	_rect(Rect2(420, 0, 220, 360), Color("20292d"))
	_label("LIVE PARAMETERS", Vector2(432, 15), 12, ACCENT)
	preset_picker = OptionButton.new()
	preset_picker.position = Vector2(430, 39)
	preset_picker.size = Vector2(200, 24)
	for preset in PRESETS:
		preset_picker.add_item(preset.name)
	preset_picker.item_selected.connect(_load_preset)
	add_child(preset_picker)
	_slider("Direction", "direction_degrees", 0, 360, 1, 73, "°")
	_slider("Reach", "reach_px", 16, 80, 1, 94, "px")
	_slider("Width", "thickness_px", 2, 28, 1, 115, "px")
	_slider("Sweep", "sweep_degrees", 30, 220, 1, 136, "°")
	_slider("Curve", "curvature", 0.35, 1, 0.01, 157, "")
	_slider("Start", "start_seconds", 0.005, 0.08, 0.001, 178, "ms")
	_slider("Burst", "burst_seconds", 0.015, 0.16, 0.001, 199, "ms")
	_slider("Decay", "decay_seconds", 0.025, 0.25, 0.001, 220, "ms")
	var reverse := CheckButton.new()
	reverse.text = "Reverse"
	reverse.position = Vector2(426, 241)
	reverse.size = Vector2(100, 25)
	reverse.toggled.connect(func(value: bool):
		if not syncing:
			settings.reverse = value
			_touch_parameter())
	add_child(reverse)
	inputs["reverse"] = reverse
	for index in range(3):
		var key: String = ["edge_color", "body_color", "tail_color"][index]
		var color := ColorPickerButton.new()
		color.position = Vector2(536 + index * 31, 244)
		color.size = Vector2(25, 18)
		color.edit_alpha = false
		color.tooltip_text = ["Ivory edge", "Gold body", "Amber tail"][index]
		color.color_changed.connect(func(value: Color):
			if not syncing:
				settings[key] = Color(value.r, value.g, value.b, 1.0)
				_touch_parameter())
		add_child(color)
		inputs[key] = color
	pause_button = _button("Pause", Rect2(430, 275, 61, 25), _toggle_pause)
	_button("+1 frame", Rect2(498, 275, 65, 25), _step)
	_button("Replay", Rect2(570, 275, 60, 25), _replay)
	var slow_box := CheckButton.new()
	slow_box.text = "0.25×"
	slow_box.position = Vector2(426, 304)
	slow_box.size = Vector2(96, 24)
	slow_box.toggled.connect(func(value: bool): slow = value)
	add_child(slow_box)
	var loop_box := CheckButton.new()
	loop_box.text = "Loop"
	loop_box.button_pressed = true
	loop_box.position = Vector2(526, 304)
	loop_box.size = Vector2(100, 24)
	loop_box.toggled.connect(func(value: bool): looped = value)
	add_child(loop_box)
	_button("Reset defaults", Rect2(430, 334, 200, 21), func(): _load_preset(0))

func _rect(bounds: Rect2, color: Color) -> ColorRect:
	var result := ColorRect.new()
	result.position = bounds.position
	result.size = bounds.size
	result.color = color
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(result)
	return result

func _label(text: String, at: Vector2, font_size: int, color: Color) -> Label:
	var result := Label.new()
	result.text = text
	result.position = at
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(result)
	return result

func _pivot(at: Vector2, zoom: int) -> void:
	_rect(Rect2(at - Vector2(5, 6) * zoom, Vector2(10, 12) * zoom), Color("42535a"))
	_rect(Rect2(at - Vector2(3, 4) * zoom, Vector2(6, 3) * zoom), Color("62757c"))
	_rect(Rect2(at - Vector2(1, 1) * zoom, Vector2(2, 2) * zoom), Color("c1c5ae"))

func _button(text: String, bounds: Rect2, callback: Callable) -> Button:
	var result := Button.new()
	result.text = text
	result.position = bounds.position
	result.size = bounds.size
	result.pressed.connect(callback)
	add_child(result)
	return result

func _slider(title: String, key: String, minimum: float, maximum: float, increment: float, y: float, suffix: String) -> void:
	_label(title, Vector2(432, y), 11, MUTED)
	var slider := HSlider.new()
	slider.position = Vector2(490, y + 1)
	slider.size = Vector2(91, 16)
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = increment
	slider.focus_mode = Control.FOCUS_NONE
	var value_label := _label("", Vector2(586, y), 10, INK)
	slider.value_changed.connect(func(value: float):
		value_label.text = _format_value(value, suffix)
		if not syncing:
			settings[key] = value
			if key == "reach_px" or key == "thickness_px":
				settings.thickness_px = minf(settings.thickness_px, settings.reach_px * 0.65)
				var width_slider: HSlider = inputs["thickness_px"].slider
				width_slider.set_value_no_signal(settings.thickness_px)
				inputs["thickness_px"].label.text = _format_value(settings.thickness_px, "px")
			if key.ends_with("_seconds"):
				_replay()
			_touch_parameter())
	add_child(slider)
	inputs[key] = {"slider": slider, "label": value_label, "suffix": suffix}

func _format_value(value: float, suffix: String) -> String:
	if suffix == "ms":
		return "%dms" % roundi(value * 1000.0)
	if suffix.is_empty():
		return "%.2f" % value
	return "%d%s" % [roundi(value), suffix]

func _load_preset(index: int) -> void:
	syncing = true
	settings = DEFAULTS.duplicate()
	settings.merge(PRESETS[index].values, true)
	for key in inputs:
		if key == "reverse":
			inputs[key].set_pressed_no_signal(settings[key])
		elif key.ends_with("_color"):
			inputs[key].color = settings[key]
		else:
			inputs[key].slider.set_value_no_signal(settings[key])
			inputs[key].label.text = _format_value(settings[key], inputs[key].suffix)
	preset_picker.select(index)
	syncing = false
	_replay()

func _touch_parameter() -> void:
	if not paused and age >= _duration():
		_replay()
	_apply_uniforms()

func _duration() -> float:
	return settings.start_seconds + settings.burst_seconds + settings.decay_seconds

func _replay() -> void:
	age = 0.0
	cycle_age = 0.0
	_apply_uniforms()

func _toggle_pause() -> void:
	paused = not paused
	pause_button.text = "Play" if paused else "Pause"

func _step() -> void:
	paused = true
	pause_button.text = "Play"
	age = minf(age + 1.0 / 60.0, _duration())
	cycle_age = age
	_apply_uniforms()

func _process(delta: float) -> void:
	if demo:
		demo_time += delta
		var section := mini(int(demo_time / 3.0), 3)
		if section != demo_section:
			demo_section = section
			_load_preset(section)
		if demo_time >= 12.0 and not capture_pending:
			get_tree().quit()
			return
	if not paused:
		cycle_age += delta * (0.25 if slow else 1.0)
		if looped and cycle_age >= _duration() + 0.45:
			cycle_age = fmod(cycle_age, _duration() + 0.45)
		age = minf(cycle_age, _duration())
	_apply_uniforms()
	if not capture_dir.is_empty() and not capture_pending:
		_capture_frame()

func _apply_uniforms() -> void:
	for material in materials:
		for key in ["reach_px", "thickness_px", "curvature", "start_seconds", "burst_seconds", "decay_seconds", "edge_color", "body_color", "tail_color"]:
			material.set_shader_parameter(key, settings[key])
		material.set_shader_parameter("age", age)
		material.set_shader_parameter("direction_radians", deg_to_rad(settings.direction_degrees))
		material.set_shader_parameter("sweep_radians", deg_to_rad(settings.sweep_degrees))
		material.set_shader_parameter("reverse_sign", -1.0 if settings.reverse else 1.0)
	if clock_label:
		clock_label.text = "%03d / %03d ms  ·  %s" % [roundi(age * 1000), roundi(_duration() * 1000), "PAUSED" if paused else ("0.25×" if slow else "REAL TIME")]
		var phase := "START / thin"
		if age >= _duration():
			phase = "CLEAR / no lingering pixels"
		elif age >= settings.start_seconds + settings.burst_seconds:
			phase = "DECAY / retract"
		elif age >= settings.start_seconds:
			phase = "BURST / broad"
		phase_label.text = phase

func _capture_frame() -> void:
	capture_pending = true
	await RenderingServer.frame_post_draw
	var snapshot := get_viewport().get_texture().get_image()
	var result := snapshot.save_png(capture_dir.path_join("frame_%05d.png" % capture_frame))
	if result != OK:
		push_error("Preview capture failed: %s" % error_string(result))
		capture_dir = ""
	capture_frame += 1
	capture_pending = false
