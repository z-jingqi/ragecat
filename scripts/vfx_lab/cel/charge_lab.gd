extends Control
## Standalone composition, timeline and controls. Neither effect depends on this lab.
const Lines = preload("res://scripts/vfx/cel/gathering_lines.gd")
const Orb = preload("res://scripts/vfx/cel/pulsing_orb.gd")
const LinesConfig = preload("res://scripts/vfx/cel/gathering_lines_config.gd")
const OrbConfig = preload("res://scripts/vfx/cel/pulsing_orb_config.gd")
const CAPTURE_FRAMES := 720
const LINE_PARAMS := [
	["size","Size ×",0.25,2.5,0.05],
	["line_count","Line count",1.0,96.0,1.0],
	["density","Density ×",0.1,2.0,0.1],
	["speed","Inward speed ×",0.25,3.0,0.05],
	["length_min","Length min",4.0,80.0,1.0],
	["length_max","Length max",4.0,150.0,1.0],
	["width_min","Width min",0.5,12.0,0.5],
	["width_max","Width max",0.5,20.0,0.5],
	["spawn_radius_min","Spawn radius min",20.0,500.0,5.0],
	["spawn_radius_max","Spawn radius max",20.0,600.0,5.0],
	["end_radius","Arrival radius",0.0,200.0,1.0],
	["lifetime_min","Life min / sec",0.08,1.5,0.01],
	["lifetime_max","Life max / sec",0.08,1.5,0.01],
	["seed","Seed",0.0,999999.0,1.0],
	["dissipate_seconds","Dissipate / sec",0.05,1.0,0.01],
]
const ORB_PARAMS := [
	["size","Size ×",0.25,2.5,0.05],
	["radius","Radius",12.0,200.0,1.0],
	["pulse_amplitude","Pulse amplitude",0.0,0.15,0.005],
	["pulse_rate","Pulse / second",0.1,12.0,0.1],
	["accent_strength","Surface accents",0.0,1.5,0.05],
	["dissipate_seconds","Dissipate / sec",0.05,1.0,0.01],
]
@export var line_settings: LinesConfig = LinesConfig.new()
@export var orb_settings: OrbConfig = OrbConfig.new()
var lines: Lines
var orb: Orb
var clock := 0.0
var stop_at := -1.0
var playing := true
var speed := 1.0
var lines_enabled := true
var orb_enabled := true
var teal := false
var settings_panel: PanelContainer
var tabs: TabContainer
var status: Label
var pass_label: Label
var play_button: Button
var lines_toggle: CheckBox
var orb_toggle: CheckBox
var param_controls: Dictionary = {"lines":{},"orb":{}}
var color_controls: Dictionary = {"lines":{},"orb":{}}
var capture_dir := ""
var capture_frame := 0
var capture_busy := false
var capture_palette := -1

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("101b28"))
	lines = Lines.new()
	lines.configure(line_settings)
	add_child(lines)
	orb = Orb.new()
	orb.configure(orb_settings)
	add_child(orb)
	_label("RAGE CAT   /   CEL EFFECT STUDIES",Vector2(48,27),16,Color("94aabd"))
	_label("03   GATHER & PULSE",Vector2(48,59),34,Color("f4f0e3"))
	_label("STRAIGHT INWARD MOTION   ·   SOLID CEL COLOR   ·   TWO INDEPENDENT COMPONENTS",Vector2(48,110),14,Color("94aabd"))
	pass_label = _label("GATHERING LINES + PULSING ORB    /    REAL-TIME GODOT",Vector2(66,173),13,Color("a8bac9"))
	status = _label("",Vector2(48,655),15,Color("f1e8ce"))
	lines_toggle = _toggle("Gathering Lines [1]",Vector2(48,610),func(value: bool): set_enabled("lines",value))
	orb_toggle = _toggle("Pulsing Orb [2]",Vector2(274,610),func(value: bool): set_enabled("orb",value))
	_button("Replay [R]",48,694,replay)
	play_button = _button("Pause [Space]",221,694,toggle_play)
	_button("Dissipate [D]",394,694,dissipate)
	_button("Slow ¼ / 1× [S]",567,694,toggle_speed)
	_button("Gold / Teal [C]",740,694,func(): set_palette(not teal))
	_button("Reset defaults",1046,694,reset_defaults)
	_button("Parameters [P]",1046,64,toggle_parameters)
	_label("R replay   ·   → single frame   ·   1 / 2 mix components   ·   P parameters   ·   Esc close panel",Vector2(48,753),14,Color("8195a6"))
	_build_parameters()
	_sync_controls()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
	if not capture_dir.is_empty():
		if DisplayServer.get_name() == "headless":
			push_error("Cel charge capture needs a real rendering display, not headless dummy.")
			get_tree().quit(1)
			return
		var error := DirAccess.make_dir_recursive_absolute(capture_dir)
		if error != OK:
			push_error("Cannot create cel charge capture directory: %s" % error)
			get_tree().quit(1)
			return
		playing = false
	_update_art()

func _draw() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("293747")
	box.set_corner_radius_all(12)
	draw_style_box(box,Rect2(48,153,1184,446))

func replay() -> void:
	clock = 0.0
	stop_at = -1.0
	playing = true

func dissipate() -> void:
	if stop_at >= 0.0: return
	stop_at = clock
	playing = true

func finished() -> bool:
	return stop_at >= 0.0 and clock >= stop_at+maxf(lines.config.dissipate_seconds,orb.config.dissipate_seconds)

func toggle_play() -> void:
	if finished(): replay()
	else: playing = not playing

func toggle_speed() -> void:
	speed = 0.25 if speed == 1.0 else 1.0

func _process(delta: float) -> void:
	if lines == null or capture_busy: return
	if not capture_dir.is_empty():
		if capture_frame >= CAPTURE_FRAMES: return
		var sample := capture_sample(capture_frame)
		clock = sample.time
		stop_at = sample.stop_at
		lines_enabled = sample.lines
		orb_enabled = sample.orb
		settings_panel.visible = sample.panel
		tabs.current_tab = 1
		pass_label.text = sample.label
		var palette_index: int = 1 if sample.teal else 0
		if capture_palette != palette_index:
			capture_palette = palette_index
			set_palette(sample.teal,false)
		_sync_toggles()
	elif playing and is_finite(delta):
		clock += maxf(delta,0.0)*speed
		if finished(): playing = false
	_update_art()
	if not capture_dir.is_empty(): _capture()

static func capture_sample(frame: int) -> Dictionary:
	var result := {"time":frame/60.0,"stop_at":-1.0,"lines":true,"orb":true,"teal":false,"panel":false,"label":"COMPOSITE    /    GATHERING LINES + PULSING ORB · NORMAL SPEED"}
	if frame >= 180 and frame < 300:
		result.orb = false
		result.time = (frame-180)/60.0
		result.label = "GATHERING LINES    /    ISOLATED · STRAIGHT INWARD · NO SPIRAL"
	elif frame >= 300 and frame < 420:
		result.lines = false
		result.time = (frame-300)/60.0
		result.label = "PULSING ORB    /    ISOLATED · SMALL, FAST PULSE · SOLID COLOR PLANES"
	elif frame >= 420 and frame < 600:
		result.teal = true
		result.time = (frame-420)/60.0
		result.label = "TEAL VARIATION    /    SAME TWO COMPONENTS · INDEPENDENT PALETTES"
	elif frame >= 600:
		result.panel = true
		result.time = (frame-600)/60.0
		result.stop_at = 1.55
		result.label = "LIVE PARAMETERS    /    MIX, TUNE & DISSIPATE · NO AUTO-LAUNCH"
	return result

func _update_art() -> void:
	var center := Vector2(468,376) if settings_panel.visible else Vector2(640,376)
	# The lab owns a fixed display scale; size / radius still visibly change the effect.
	var zoom := 0.58 if settings_panel.visible else 0.64
	for effect in [lines,orb]:
		effect.position = center
		effect.scale = Vector2.ONE*zoom
		effect.seek(clock,stop_at)
	lines.visible = lines_enabled
	orb.visible = orb_enabled
	var phase := "HOLD"
	if stop_at >= 0.0 and clock >= stop_at: phase = "CLEAR" if finished() else "DISSIPATE"
	status.text = "%s    %.2f s    /    %.2f×    /    %s" % [phase,clock,speed,"PLAYING" if playing else "PAUSED"]
	if not capture_dir.is_empty(): status.text = "%s    %.2f s    /    NORMAL SPEED    /    GODOT VIEWPORT CAPTURE" % [phase,clock]
	play_button.text = "Play [Space]" if not playing else "Pause [Space]"
	queue_redraw()

func _effect(component: String) -> Node2D:
	return lines if component == "lines" else (orb if component == "orb" else null)

func set_parameter(component: String, name: String, value: float) -> void:
	if not param_controls.has(component) or not param_controls[component].has(name): return
	var effect := _effect(component)
	if name == "line_count" or name == "seed": effect.config.set(name,int(value) if is_finite(value) else 0)
	else: effect.config.set(name,value)
	effect.configure(effect.config)
	_sync_controls()
	replay()

func set_color(component: String, name: String, value: Color) -> void:
	if not color_controls.has(component) or not color_controls[component].has(name): return
	var effect := _effect(component)
	effect.config.set(name,value)
	effect.configure(effect.config)
	_sync_controls()
	replay()

func set_enabled(component: String, enabled: bool) -> void:
	if component == "lines": lines_enabled = enabled
	elif component == "orb": orb_enabled = enabled
	else: return
	_sync_toggles()
	_update_art()

func set_palette(use_teal: bool, restart: bool = true) -> void:
	teal = use_teal
	for component in ["lines","orb"]:
		var effect := _effect(component)
		var defaults: Resource = LinesConfig.new() if component == "lines" else OrbConfig.new()
		for spec in [["core_color",Color("effff1")],["body_color",Color("83efca")],["shade_color",Color("26a995")]]:
			effect.config.set(spec[0],spec[1] if teal else defaults.get(spec[0]))
		effect.configure(effect.config)
	_sync_controls()
	if restart: replay()

func reset_defaults() -> void:
	lines.configure(LinesConfig.new())
	orb.configure(OrbConfig.new())
	lines_enabled = true
	orb_enabled = true
	teal = false
	speed = 1.0
	_sync_controls()
	replay()

func toggle_parameters() -> void:
	settings_panel.visible = not settings_panel.visible
	_release_focus()
	_update_art()

func _sync_toggles() -> void:
	lines_toggle.set_pressed_no_signal(lines_enabled)
	orb_toggle.set_pressed_no_signal(orb_enabled)

func _sync_controls() -> void:
	for component in ["lines","orb"]:
		var effect := _effect(component)
		for name in param_controls[component]: param_controls[component][name].set_value_no_signal(effect.config.get(name))
		for name in color_controls[component]: color_controls[component][name].color = effect.config.get(name)
	_sync_toggles()

func _build_parameters() -> void:
	settings_panel = PanelContainer.new()
	settings_panel.position = Vector2(884,195)
	settings_panel.size = Vector2(334,390)
	add_child(settings_panel)
	var box := StyleBoxFlat.new()
	box.bg_color = Color("152333")
	box.set_corner_radius_all(8)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	settings_panel.add_theme_stylebox_override("panel",box)
	tabs = TabContainer.new()
	tabs.custom_minimum_size = Vector2(314,374)
	settings_panel.add_child(tabs)
	for component in ["lines","orb"]:
		var scroll := ScrollContainer.new()
		scroll.name = "Gathering Lines" if component == "lines" else "Pulsing Orb"
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		tabs.add_child(scroll)
		var rows := VBoxContainer.new()
		rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rows.add_theme_constant_override("separation",7)
		scroll.add_child(rows)
		for spec in [["core_color","Ivory highlight"],["body_color","Body color"],["shade_color","Cel shadow"]]:
			var row := _parameter_row(rows,spec[1])
			var picker := ColorPickerButton.new()
			picker.edit_alpha = false
			picker.custom_minimum_size = Vector2(104,26)
			row.add_child(picker)
			color_controls[component][spec[0]] = picker
			picker.color_changed.connect(func(value: Color): set_color(component,spec[0],value))
		var divider := HSeparator.new()
		rows.add_child(divider)
		for spec in LINE_PARAMS if component == "lines" else ORB_PARAMS:
			var row := _parameter_row(rows,spec[1])
			var spin := SpinBox.new()
			spin.min_value = spec[2]
			spin.max_value = spec[3]
			spin.step = spec[4]
			spin.custom_minimum_size.x = 104
			row.add_child(spin)
			param_controls[component][spec[0]] = spin
			spin.value_changed.connect(func(value: float): set_parameter(component,spec[0],value))
	settings_panel.hide()

func _parameter_row(rows: VBoxContainer, caption: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	rows.add_child(row)
	var label := Label.new()
	label.text = caption
	label.custom_minimum_size.x = 172
	label.add_theme_font_override("font",ThemeDB.fallback_font)
	label.add_theme_font_size_override("font_size",13)
	row.add_child(label)
	return row

func _label(text: String, at: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_override("font",ThemeDB.fallback_font)
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	add_child(label)
	return label

func _button(text: String, x: float, y: float, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = Vector2(x,y)
	button.size = Vector2(156,38)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font",ThemeDB.fallback_font)
	button.add_theme_font_size_override("font_size",14)
	button.pressed.connect(func(): _release_focus(); action.call())
	add_child(button)
	return button

func _toggle(text: String, at: Vector2, action: Callable) -> CheckBox:
	var toggle := CheckBox.new()
	toggle.text = text
	toggle.position = at
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.add_theme_font_override("font",ThemeDB.fallback_font)
	toggle.add_theme_font_size_override("font_size",16)
	toggle.toggled.connect(action)
	add_child(toggle)
	return toggle

func _release_focus() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null: focused.release_focus()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.is_pressed() or event.is_echo(): return
	match event.keycode:
		KEY_R: replay()
		KEY_SPACE: toggle_play()
		KEY_D: dissipate()
		KEY_S: toggle_speed()
		KEY_C: set_palette(not teal)
		KEY_P: toggle_parameters()
		KEY_1: set_enabled("lines",not lines_enabled)
		KEY_2: set_enabled("orb",not orb_enabled)
		KEY_RIGHT: playing = false; clock += 1.0/60.0

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo() and event.keycode == KEY_ESCAPE and settings_panel.visible:
		for component in color_controls:
			for name in color_controls[component]: color_controls[component][name].get_popup().hide()
		_release_focus()
		settings_panel.hide()
		get_viewport().set_input_as_handled()

func _capture() -> void:
	capture_busy = true
	await RenderingServer.frame_post_draw
	var picture := get_viewport().get_texture().get_image()
	var error := picture.save_png(capture_dir.path_join("frame_%04d.png" % capture_frame))
	if error != OK:
		push_error("Cel charge capture failed: %s" % error)
		get_tree().quit(1)
		return
	capture_frame += 1
	capture_busy = false
	if capture_frame >= CAPTURE_FRAMES: get_tree().quit()
