extends Control
const Config = preload("res://scripts/vfx/cel/shield_hit_config.gd")
const Effect = preload("res://scripts/vfx/cel/shield_hit.gd")
const Demo = preload("res://scripts/vfx_lab/cel/shield_hit_demo.gd")
@export var settings: Config = Config.new()
var effect: Effect
var demo: Demo
var clock := 0.0
var playing := true
var looping := true
var speed := 1.0
var status: Label
var pass_label: Label
var settings_panel: PanelContainer
var param_controls: Dictionary = {}
var color_controls: Dictionary = {}
var arc_toggle: CheckBox
var demo_toggle: CheckBox
var capture_dir := ""
var capture_frame := 0
var capture_busy := false
const CAPTURE_FRAMES := 600
const PARAMS := [
	["size","Size",0.25,3.0,0.05],
	["direction_degrees","Incoming angle °",-180.0,180.0,5.0],
	["duration_scale","Duration ×",0.4,2.0,0.05],
	["flash_seconds","Flash / seconds",0.025,0.12,0.005],
	["spark_count","Spark count",0.0,12.0,1.0],
	["spark_length","Spark length ×",0.25,2.0,0.05],
	["scatter","Spread ×",0.25,1.5,0.05],
	["travel","Spark travel ×",0.4,2.0,0.05],
	["seed_value","Random seed",0.0,9999.0,1.0],
]

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("101b28"))
	demo = Demo.new()
	add_child(demo)
	effect = Effect.new()
	effect.configure(settings)
	add_child(effect)
	_label("RAGE CAT   /   CEL EFFECT STUDIES",Vector2(48,28),16,Color("94aabd"))
	_label("01   SHIELD IMPACT",Vector2(48,60),34,Color("f4f0e3"))
	_label("SOLID SHAPES  ·  SHARP GOLD SPARKS  ·  NO PIXEL GRID",Vector2(48,112),15,Color("94aabd"))
	pass_label = _label("ARROW → SHIELD    /    REAL-TIME GODOT",Vector2(66,182),13,Color("a8bac9"))
	status = _label("",Vector2(48,630),16,Color("f1e8ce"))
	_button("Replay [R]",48,680,replay)
	_button("Pause [Space]",221,680,func(): playing = not playing)
	_button("Slow ¼ / 1× [S]",394,680,func(): speed = 0.25 if speed == 1.0 else 1.0)
	_button("Backdrop [B]",567,680,func(): demo.bright = not demo.bright)
	_button("Loop [L]",740,680,func(): looping = not looping)
	_button("Parameters [P]",1046,66,func(): settings_panel.visible = not settings_panel.visible)
	_button("Reset defaults",1046,680,reset_defaults)
	_label("R replay   ·   → frame step   ·   E effect only   ·   Esc close parameters",Vector2(48,750),14,Color("8195a6"))
	_build_parameters()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
	if not capture_dir.is_empty():
		if DisplayServer.get_name() == "headless":
			push_error("Cel capture needs a real rendering display, not headless dummy.")
			get_tree().quit(1)
			return
		DirAccess.make_dir_recursive_absolute(capture_dir)
		playing = false
	_update_art()

func duration() -> float:
	return maxf(Demo.CYCLE,Demo.CONTACT+effect.config.duration()+0.3)

func replay() -> void:
	clock = 0.0
	playing = true

func _process(delta: float) -> void:
	if effect == null or capture_busy: return
	if not capture_dir.is_empty():
		if capture_frame >= CAPTURE_FRAMES: return
		if capture_frame < 240:
			clock = fposmod(capture_frame/60.0,2.0)
			demo.bright = false
			speed = 1.0
			pass_label.text = "ARROW → SHIELD    /    NORMAL SPEED · TWO REPLAYS"
		elif capture_frame < 480:
			clock = (capture_frame-240)/120.0
			demo.bright = true
			speed = 0.5
			pass_label.text = "ARROW → SHIELD    /    ½ SPEED · LIGHT BACKDROP"
		else:
			clock = (capture_frame-480)/120.0+0.25
			demo.bright = false
			demo.show_props = false
			speed = 0.5
			pass_label.text = "ISOLATED EFFECT    /    ½ SPEED · NO DEMO PROPS"
	elif playing:
		clock += maxf(delta,0)*speed
		if clock >= duration():
			if looping: clock = fposmod(clock,duration())
			else: clock = duration(); playing = false
	_update_art()
	if not capture_dir.is_empty(): _capture()

func _update_art() -> void:
	demo.time = clock
	demo.direction_degrees = effect.config.direction_degrees
	demo.origin = Vector2(562,386) if settings_panel.visible else (Vector2(640,386) if not demo.show_props else Vector2(790,386))
	demo.queue_redraw()
	effect.position = demo.origin
	effect.seek(clock-Demo.CONTACT)
	var phase := "APPROACH" if clock < Demo.CONTACT else ("IMPACT" if clock < Demo.CONTACT+effect.config.flash_seconds*effect.config.duration_scale else ("SPARKS" if clock < Demo.CONTACT+effect.config.duration() else "SETTLED"))
	status.text = "%s    %.3f s     /     %.2f×     /     %s     /     LOOP %s" % [phase,clock,speed,"PLAY" if playing else "PAUSED","ON" if looping else "OFF"]
	if not capture_dir.is_empty(): status.text = "%s    %.3f s     /     %.2f×     /     GODOT VIEWPORT CAPTURE" % [phase,clock,speed]
	pass_label.modulate = Color("415565") if demo.bright else Color.WHITE

func _capture() -> void:
	capture_busy = true
	await RenderingServer.frame_post_draw
	var picture := get_viewport().get_texture().get_image()
	var error := picture.save_png(capture_dir.path_join("frame_%04d.png" % capture_frame))
	if error != OK:
		push_error("Cel capture failed: %s" % error)
		get_tree().quit(1)
		return
	capture_frame += 1
	capture_busy = false
	if capture_frame >= CAPTURE_FRAMES: get_tree().quit()

func _label(text: String, position_value: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = position_value
	label.add_theme_font_override("font",ThemeDB.fallback_font)
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	add_child(label)
	return label

func _button(text: String, x: float, y: float, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.position = Vector2(x,y)
	button.size = Vector2(156,38)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font",ThemeDB.fallback_font)
	button.add_theme_font_size_override("font_size",14)
	button.pressed.connect(func(): _release_focus(); action.call())
	add_child(button)

func _build_parameters() -> void:
	settings_panel = PanelContainer.new()
	settings_panel.position = Vector2(883,174)
	settings_panel.size = Vector2(337,425)
	add_child(settings_panel)
	var box := StyleBoxFlat.new()
	box.bg_color = Color("152333")
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	settings_panel.add_theme_stylebox_override("panel",box)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(309,400)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	settings_panel.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	var heading := Label.new()
	heading.text = "LIVE CEL PARAMETERS"
	rows.add_child(heading)
	for spec in PARAMS:
		var row := HBoxContainer.new()
		rows.add_child(row)
		var label := Label.new()
		label.text = spec[1]
		label.custom_minimum_size.x = 174
		row.add_child(label)
		var spin := SpinBox.new()
		spin.min_value = spec[2]
		spin.max_value = spec[3]
		spin.step = spec[4]
		spin.custom_minimum_size.x = 110
		row.add_child(spin)
		param_controls[spec[0]] = spin
		spin.value_changed.connect(func(value: float): set_parameter(spec[0],value))
	for spec in [["core_color","Ivory core"],["body_color","Gold sparks"],["shade_color","Cel shadow"],["arc_color","Pressure crescent"]]:
		var row := HBoxContainer.new()
		rows.add_child(row)
		var label := Label.new()
		label.text = spec[1]
		label.custom_minimum_size.x = 174
		row.add_child(label)
		var picker := ColorPickerButton.new()
		picker.edit_alpha = false
		picker.custom_minimum_size = Vector2(108,28)
		row.add_child(picker)
		color_controls[spec[0]] = picker
		picker.color_changed.connect(func(value: Color): effect.config.set(spec[0],value); effect.config.sanitize(); replay())
	arc_toggle = CheckBox.new()
	arc_toggle.text = "Subtle pressure crescent"
	arc_toggle.toggled.connect(func(value: bool): effect.config.show_arc = value; replay())
	rows.add_child(arc_toggle)
	demo_toggle = CheckBox.new()
	demo_toggle.text = "Arrow + shield demonstration"
	demo_toggle.toggled.connect(func(value: bool): demo.show_props = value; replay())
	rows.add_child(demo_toggle)
	_sync_controls()
	settings_panel.hide()

func set_parameter(name: String, value: float) -> void:
	if not param_controls.has(name): return
	effect.config.set(name,value)
	effect.config.sanitize()
	_sync_controls()
	replay()

func _sync_controls() -> void:
	for name in param_controls: param_controls[name].set_value_no_signal(effect.config.get(name))
	for name in color_controls: color_controls[name].color = effect.config.get(name)
	arc_toggle.set_pressed_no_signal(effect.config.show_arc)
	demo_toggle.set_pressed_no_signal(demo.show_props)

func reset_defaults() -> void:
	effect.configure(Config.new())
	demo.show_props = true
	_sync_controls()
	replay()

func _release_focus() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null: focused.release_focus()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.is_pressed() or event.is_echo(): return
	match event.keycode:
		KEY_R: replay()
		KEY_SPACE: playing = not playing
		KEY_S: speed = 0.25 if speed == 1.0 else 1.0
		KEY_L: looping = not looping
		KEY_B: demo.bright = not demo.bright
		KEY_E: demo.show_props = not demo.show_props; _sync_controls()
		KEY_P: settings_panel.visible = not settings_panel.visible
		KEY_RIGHT: playing = false; clock = minf(clock+1.0/60.0,duration())

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and event.keycode == KEY_ESCAPE and settings_panel.visible:
		_release_focus()
		settings_panel.hide()
		get_viewport().set_input_as_handled()
