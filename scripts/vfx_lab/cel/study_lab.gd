extends Control
## Shared presentation-only study host; the effects themselves do not depend on it.
const CAPTURE_FRAMES := 780
@export var effect_script: Script
@export var study_title := "CEL EFFECT"
@export var study_subtitle := "INDEPENDENT COMPONENT / HARD COLOR / REAL TIME"
@export var floor_host := true
var effect: Node2D
var stage: Control
var world: Node2D
var elapsed := -0.35
var playing := true
var playback_speed := 1.0
var light_background := false
var effect_only := false
var settings_panel: PanelContainer
var param_controls: Dictionary = {}
var color_controls: Dictionary = {}
var status: Label
var pass_label: Label
var play_button: Button
var capture_dir := ""
var capture_frame := 0
var capture_busy := false
var capture_segment := -1
var fit_scale := 1.0
var fit_origin := Vector2(592,340)

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("111d2b"))
	stage = Control.new()
	stage.position = Vector2(48,164)
	stage.size = Vector2(1184,432)
	stage.clip_contents = true
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	world = Node2D.new()
	world.draw.connect(_draw_world)
	stage.add_child(world)
	effect = effect_script.new()
	world.add_child(effect)
	effect.set_process(false)
	_label("RAGE CAT   /   CEL EFFECT STUDIES",Vector2(48,27),16,Color("94aabd"))
	_label(study_title,Vector2(48,59),32,Color("f4f0e3"))
	_label(study_subtitle,Vector2(48,108),13,Color("94aabd"))
	pass_label = _label("",Vector2(64,138),14,Color("e6d8ad"))
	status = _label("",Vector2(48,619),16,Color("f1e8ce"))
	_button("Replay [R]",48,669,replay,171)
	play_button = _button("Pause [Space]",235,669,toggle_play,171)
	_button("Slow ¼ / 1× [S]",422,669,toggle_speed,171)
	_button("Dark / Light [B]",609,669,toggle_background,171)
	_button("Effect only [E]",796,669,toggle_effect_only,171)
	_button("Reset defaults",983,669,reset_defaults,219)
	_button("Parameters [P]",1046,64,toggle_parameters,156)
	_label("R replay   ·   Space pause   ·   → single frame   ·   S slow   ·   B background   ·   E isolate   ·   P parameters   ·   Esc close",Vector2(48,734),13,Color("94aabd"))
	_label("Standalone VFX laboratory. No gameplay, damage, camera shake or asset replacement.",Vector2(48,763),13,Color("718b9f"))
	_build_parameters()
	_sync_controls()
	_fit_effect()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
	if not capture_dir.is_empty():
		if DisplayServer.get_name() == "headless":
			push_error("Cel study recording requires a real rendering display.")
			get_tree().quit(1)
			return
		var error := DirAccess.make_dir_recursive_absolute(capture_dir)
		if error != OK:
			push_error("Cannot create capture folder: %s" % error)
			get_tree().quit(1)
			return
	replay()

func _draw() -> void:
	draw_rect(Rect2(48,164,1184,432),Color("455466"),false,1.0)
	draw_rect(Rect2(48,650,1154,3),Color("25384a"))
	if effect != null:
		draw_rect(Rect2(48,650,1154*clampf((elapsed+0.35)/cycle_duration(),0,1),3),Color("e7ca84"))

func _draw_world() -> void:
	world.draw_rect(Rect2(Vector2.ZERO,stage.size),Color("e3e6df") if light_background else Color("273545"))
	if _has_host():
		var color := Color("a4aea9") if light_background else Color("415465")
		world.draw_line(Vector2(45,fit_origin.y+2),Vector2(1139,fit_origin.y+2),color,1.0,true)
		# An abstract weight indicates contact, not an attack or game character.
		if elapsed < 0 and elapsed > -0.32:
			var u := clampf((elapsed+0.32)/0.32,0,1)
			var center := fit_origin+Vector2(0,-185*(1-u*u)-18)
			var corners := PackedVector2Array([center+Vector2(-16,-16),center+Vector2(16,-16),center+Vector2(19,16),center+Vector2(-19,16)])
			world.draw_colored_polygon(corners,Color("91a6b5"))

func _has_host() -> bool:
	return floor_host and not effect_only and is_zero_approx(effect.config.direction_degrees)

func cycle_duration() -> float:
	return effect.config.duration()+0.9

func replay() -> void:
	elapsed = -0.35
	playing = true
	_update_view()

func step(delta: float) -> void:
	if not is_finite(delta) or delta <= 0: return
	elapsed += delta
	_update_view()

func _update_view() -> void:
	effect.seek(elapsed)
	effect.position = fit_origin
	effect.scale = Vector2.ONE*fit_scale
	status.text = "%s    %.2f s    /    %.2f× playback    /    VIEW %.2f×    /    %s" % ["PLAYING" if playing else "PAUSED",maxf(elapsed,0),playback_speed,fit_scale,"GENERIC CONTACT HOST" if _has_host() else "EFFECT ONLY"]
	play_button.text = "Pause [Space]" if playing else "Play [Space]"
	pass_label.text = "CONTACT → EXPANSION → DISSIPATION" if _has_host() else "PURE EFFECT"
	world.queue_redraw()
	queue_redraw()

func _fit_effect() -> void:
	var bounds := Rect2(Vector2(-30,-30),Vector2(60,60))
	for i in range(90):
		for command in effect.build_commands(effect.config.duration()*i/90.0):
			for point in command.points: bounds = bounds.expand(point)
	var width := 720.0 if settings_panel.visible else 1100.0
	fit_scale = minf(1.6,minf(width/maxf(bounds.size.x,1),350/maxf(bounds.size.y,1)))
	var center_x := 395.0 if settings_panel.visible else 592.0
	fit_origin = Vector2(center_x-bounds.get_center().x*fit_scale,390-bounds.end.y*fit_scale)

func _process(delta: float) -> void:
	if effect == null or capture_busy: return
	if not capture_dir.is_empty():
		if capture_frame >= CAPTURE_FRAMES: return
		var segment := 0 if capture_frame < 300 else (1 if capture_frame < 540 else 2)
		if segment != capture_segment:
			capture_segment = segment
			light_background = segment == 1
			effect_only = segment == 2
			playback_speed = 1.0 if segment == 0 else 0.5
			elapsed = -0.35
		if segment == 0 and elapsed >= cycle_duration()-0.35: elapsed = -0.35
		step(playback_speed/60.0)
		_capture()
	elif playing:
		step(minf(maxf(delta,0),0.1)*playback_speed)
		if elapsed >= cycle_duration()-0.35: replay()

func toggle_play() -> void:
	playing = not playing
	_update_view()

func toggle_speed() -> void:
	playback_speed = 0.25 if playback_speed == 1.0 else 1.0
	_update_view()

func toggle_background() -> void:
	light_background = not light_background
	_update_view()

func toggle_effect_only() -> void:
	effect_only = not effect_only
	_update_view()

func set_parameter(name: String, value: Variant) -> void:
	if not param_controls.has(name): return
	effect.config.set(name,value)
	effect.configure(effect.config)
	_sync_controls()
	_fit_effect()
	replay()

func set_color(name: String, value: Color) -> void:
	if not color_controls.has(name): return
	effect.config.set(name,value)
	effect.configure(effect.config)
	_sync_controls()
	replay()

func reset_defaults() -> void:
	effect.configure(null)
	playback_speed = 1.0
	light_background = false
	effect_only = false
	_sync_controls()
	_fit_effect()
	replay()

func toggle_parameters() -> void:
	settings_panel.visible = not settings_panel.visible
	if not settings_panel.visible:
		for name in color_controls: color_controls[name].get_popup().hide()
	_release_focus()
	_fit_effect()
	_update_view()

func _sync_controls() -> void:
	for name in param_controls:
		var control: Control = param_controls[name]
		if control is CheckBox: control.set_pressed_no_signal(effect.config.get(name))
		else: control.set_value_no_signal(effect.config.get(name))
	for name in color_controls: color_controls[name].color = effect.config.get(name)

func _build_parameters() -> void:
	settings_panel = PanelContainer.new()
	settings_panel.position = Vector2(880,180)
	settings_panel.size = Vector2(336,402)
	add_child(settings_panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("152333")
	style.set_corner_radius_all(8)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	settings_panel.add_theme_stylebox_override("panel",style)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(316,386)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	settings_panel.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation",7)
	scroll.add_child(rows)
	for property in effect.config.get_property_list():
		if not (property.usage & PROPERTY_USAGE_EDITOR) or not (property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE): continue
		var name: String = property.name
		if not property.type in [TYPE_BOOL,TYPE_INT,TYPE_FLOAT,TYPE_COLOR]: continue
		var row := HBoxContainer.new()
		rows.add_child(row)
		var caption := Label.new()
		caption.text = name.replace("_"," ").capitalize()
		caption.custom_minimum_size.x = 182
		caption.add_theme_font_override("font",ThemeDB.fallback_font)
		caption.add_theme_font_size_override("font_size",12)
		row.add_child(caption)
		if property.type == TYPE_COLOR:
			var picker := ColorPickerButton.new()
			picker.edit_alpha = false
			picker.custom_minimum_size = Vector2(98,26)
			row.add_child(picker)
			color_controls[name] = picker
			picker.color_changed.connect(func(value: Color): set_color(name,value))
		elif property.type == TYPE_BOOL:
			var toggle := CheckBox.new()
			row.add_child(toggle)
			param_controls[name] = toggle
			toggle.toggled.connect(func(value: bool): set_parameter(name,value))
		else:
			var spin := SpinBox.new()
			var range_values: PackedStringArray = property.hint_string.split(",")
			spin.min_value = float(range_values[0]) if property.hint == PROPERTY_HINT_RANGE and range_values.size() >= 2 else 0
			spin.max_value = float(range_values[1]) if property.hint == PROPERTY_HINT_RANGE and range_values.size() >= 2 else 9999
			spin.step = float(range_values[2]) if property.hint == PROPERTY_HINT_RANGE and range_values.size() >= 3 else 1
			spin.custom_minimum_size.x = 98
			row.add_child(spin)
			param_controls[name] = spin
			spin.value_changed.connect(func(value: float): set_parameter(name,value))
	settings_panel.hide()

func _label(text: String, at: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_override("font",ThemeDB.fallback_font)
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	add_child(label)
	return label

func _button(text: String, x: float, y: float, action: Callable, width: float) -> Button:
	var button := Button.new()
	button.text = text
	button.position = Vector2(x,y)
	button.size = Vector2(width,38)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font",ThemeDB.fallback_font)
	button.add_theme_font_size_override("font_size",14)
	button.pressed.connect(func(): _release_focus(); action.call())
	add_child(button)
	return button

func _release_focus() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null: focused.release_focus()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.is_pressed() or event.is_echo(): return
	match event.keycode:
		KEY_R: replay()
		KEY_SPACE: toggle_play()
		KEY_S: toggle_speed()
		KEY_B: toggle_background()
		KEY_E: toggle_effect_only()
		KEY_P: toggle_parameters()
		KEY_RIGHT: playing = false; step(1.0/60.0)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo() and event.keycode == KEY_ESCAPE and settings_panel.visible:
		for name in color_controls: color_controls[name].get_popup().hide()
		_release_focus()
		settings_panel.hide()
		_fit_effect()
		_update_view()
		get_viewport().set_input_as_handled()

func _capture() -> void:
	capture_busy = true
	await RenderingServer.frame_post_draw
	var picture := get_viewport().get_texture().get_image()
	var error := picture.save_png(capture_dir.path_join("frame_%04d.png" % capture_frame))
	if error != OK:
		push_error("Cel study capture failed: %s" % error)
		get_tree().quit(1)
		return
	capture_frame += 1
	capture_busy = false
	if capture_frame >= CAPTURE_FRAMES: get_tree().quit()
