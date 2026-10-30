extends Control
## Isolated demo timeline/UI. The reusable slash has no dependency on this lab.
const Config = preload("res://scripts/vfx/cel/slash_config.gd")
const Effect = preload("res://scripts/vfx/cel/slash.gd")
const START := 0.32
const CYCLE := 1.5
const CAPTURE_FRAMES := 720
const COMPARISON_ANGLES := [0.0,90.0,180.0,-90.0]
@export var settings: Config = Config.new()
var effect: Effect
var clock := 0.0
var playing := true
var looping := true
var speed := 1.0
var bright := false
var angle_comparison := false
var comparison_effects: Array[Effect] = []
var comparison_labels: Array[Label] = []
var status: Label
var pass_label: Label
var settings_panel: PanelContainer
var param_controls: Dictionary = {}
var color_controls: Dictionary = {}
var reverse_toggle: CheckBox
var preview_bounds := Rect2(-400,-180,800,400)
var capture_dir := ""
var capture_frame := 0
var capture_busy := false
const PARAMS := [
	["size","Size ×",0.25,2.5,0.05],
	["length","Arc length",160.0,1100.0,10.0],
	["thickness","Blade thickness",6.0,220.0,1.0],
	["curvature","Curvature",0.3,1.0,0.01],
	["arc_degrees","Sweep angle °",60.0,250.0,5.0],
	["direction_degrees","Rotation °",-180.0,180.0,5.0],
	["sweep_seconds","Reveal / seconds",0.025,0.25,0.005],
	["peak_seconds","Peak / seconds",0.0,0.15,0.005],
	["disappear_seconds","Disappear / seconds",0.05,0.4,0.005],
	["duration_scale","Duration ×",0.4,2.0,0.05],
	["extension","Extension",0.0,0.2,0.01],
]

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("101b28"))
	effect = Effect.new()
	effect.configure(settings)
	add_child(effect)
	for i in range(4):
		var comparison := Effect.new()
		add_child(comparison)
		comparison_effects.append(comparison)
		comparison_labels.append(_label(["0°","90°","180°","270° / −90°"][i],Vector2(180+i*290,557),18,Color("a8bac9")))
	_label("RAGE CAT   /   CEL EFFECT STUDIES",Vector2(48,28),16,Color("94aabd"))
	_label("02   GOLDEN CRESCENT",Vector2(48,60),34,Color("f4f0e3"))
	_label("ONE CONTINUOUS SWEEP  ·  IVORY EDGE + GOLD  ·  NO OUTLINE",Vector2(48,112),15,Color("94aabd"))
	pass_label = _label("SLASH    /    REAL-TIME GODOT",Vector2(66,182),13,Color("a8bac9"))
	status = _label("",Vector2(48,630),16,Color("f1e8ce"))
	_button("Replay [R]",48,680,replay)
	_button("Pause [Space]",221,680,func(): playing = not playing)
	_button("Slow ¼ / 1× [S]",394,680,func(): speed = 0.25 if speed == 1.0 else 1.0)
	_button("Backdrop [B]",567,680,func(): bright = not bright)
	_button("Loop [L]",740,680,func(): looping = not looping)
	_button("Angles [A]",913,680,toggle_angles,115)
	_button("Parameters [P]",1046,66,toggle_parameters)
	_button("Reset defaults",1046,680,reset_defaults)
	_label("R replay   ·   → frame step   ·   X reverse   ·   A four angles   ·   Esc close parameters",Vector2(48,750),14,Color("8195a6"))
	_build_parameters()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
	if not capture_dir.is_empty():
		if DisplayServer.get_name() == "headless":
			push_error("Cel slash capture needs a real rendering display, not headless dummy.")
			get_tree().quit(1)
			return
		DirAccess.make_dir_recursive_absolute(capture_dir)
		playing = false
	_update_art()

func _draw() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("e9e8df") if bright else Color("293747")
	box.set_corner_radius_all(12)
	draw_style_box(box,Rect2(48,164,1184,446))

func duration() -> float:
	return maxf(CYCLE,START+effect.config.duration()+0.4)

func replay() -> void:
	clock = 0.0
	playing = true

func _process(delta: float) -> void:
	if effect == null or capture_busy: return
	if not capture_dir.is_empty():
		if capture_frame >= CAPTURE_FRAMES: return
		var sample := capture_sample(capture_frame)
		clock = sample.time
		bright = sample.bright
		angle_comparison = sample.get("angles",false)
		speed = sample.speed
		pass_label.text = sample.label
	elif playing:
		clock += maxf(delta,0)*speed
		if clock >= duration():
			if looping: clock = fposmod(clock,duration())
			else: clock = duration(); playing = false
	_update_art()
	if not capture_dir.is_empty(): _capture()

static func capture_sample(frame: int) -> Dictionary:
	if frame < 180:
		return {"time":fposmod(frame/60.0,CYCLE),"bright":false,"speed":1.0,"label":"ONE CRESCENT    /    NORMAL SPEED · TWO REPLAYS"}
	if frame < 360:
		return {"time":(frame-180)/240.0+0.15,"bright":false,"speed":0.25,"label":"SHAPE & TIMING    /    ¼ SPEED · DARK BACKDROP"}
	if frame < 480:
		return {"time":(frame-360)/120.0+0.15,"bright":true,"speed":0.5,"label":"PALETTE & SILHOUETTE    /    ½ SPEED · LIGHT BACKDROP"}
	return {"time":fposmod((frame-480)/120.0,1.0),"bright":false,"speed":0.5,"angles":true,"label":"360° ROTATION    /    SAME COMPONENT · FOUR ANGLES · ½ SPEED"}

func _update_art() -> void:
	# Fit the reference silhouette for the chosen orientation, not the user's size
	# or length. Rotation stays readable while those shape controls remain visible.
	var frame := Rect2(80,222,780 if settings_panel.visible else 1120,360)
	var zoom := minf(0.82 if settings_panel.visible else 0.92,minf(frame.size.x/preview_bounds.size.x,frame.size.y/preview_bounds.size.y))
	effect.scale = Vector2.ONE*zoom
	effect.position = frame.get_center()-preview_bounds.get_center()*zoom
	effect.seek(clock-START)
	effect.visible = not angle_comparison
	for i in range(comparison_effects.size()):
		comparison_effects[i].visible = angle_comparison
		comparison_effects[i].position = Vector2(200+i*290,382)
		comparison_effects[i].scale = Vector2.ONE*0.3
		comparison_effects[i].seek(clock-START)
		comparison_labels[i].visible = angle_comparison
		comparison_labels[i].modulate = Color("415565") if bright else Color.WHITE
	var t := (clock-START)/effect.config.duration_scale
	var phase := "READY"
	if t >= 0:
		phase = "SWEEP" if t < effect.config.sweep_seconds else ("EXTEND" if t < effect.config.sweep_seconds+effect.config.peak_seconds else ("SHRINK" if clock < START+effect.config.duration() else "CLEAR"))
	status.text = "%s    %.3f s     /     %.2f×     /     %s     /     LOOP %s" % [phase,clock,speed,"PLAY" if playing else "PAUSED","ON" if looping else "OFF"]
	if not capture_dir.is_empty(): status.text = "%s    %.3f s     /     %.2f×     /     GODOT VIEWPORT CAPTURE" % [phase,clock,speed]
	pass_label.modulate = Color("415565") if bright else Color.WHITE
	queue_redraw()

func _capture() -> void:
	capture_busy = true
	await RenderingServer.frame_post_draw
	var picture := get_viewport().get_texture().get_image()
	var error := picture.save_png(capture_dir.path_join("frame_%04d.png" % capture_frame))
	if error != OK:
		push_error("Cel slash capture failed: %s" % error)
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

func _button(text: String, x: float, y: float, action: Callable, width: float = 156.0) -> void:
	var button := Button.new()
	button.text = text
	button.position = Vector2(x,y)
	button.size = Vector2(width,38)
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
	for spec in [["core_color","Ivory blade"],["body_color","Gold body"],["shade_color","Warm cel shadow"]]:
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
		picker.color_changed.connect(func(value: Color): effect.config.set(spec[0],value); effect.config.sanitize(); _sync_controls(); replay())
	reverse_toggle = CheckBox.new()
	reverse_toggle.text = "Reverse sweep [X]"
	reverse_toggle.toggled.connect(func(value: bool): effect.config.reverse = value; _sync_controls(); replay())
	rows.add_child(reverse_toggle)
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
	reverse_toggle.set_pressed_no_signal(effect.config.reverse)
	for i in range(comparison_effects.size()):
		comparison_effects[i].configure(effect.config)
		comparison_effects[i].config.direction_degrees = COMPARISON_ANGLES[i]
	var reference := Effect.new()
	var reference_config := Config.new()
	reference_config.direction_degrees = effect.config.direction_degrees
	reference_config.reverse = effect.config.reverse
	reference.configure(reference_config)
	var points: PackedVector2Array = reference.build_commands(reference_config.sweep_seconds+reference_config.peak_seconds)[0].points
	preview_bounds = Rect2(points[0],Vector2.ZERO)
	for point in points: preview_bounds = preview_bounds.expand(point)
	reference.free()

func reset_defaults() -> void:
	effect.configure(Config.new())
	_sync_controls()
	replay()

func toggle_parameters() -> void:
	settings_panel.visible = not settings_panel.visible
	if settings_panel.visible: angle_comparison = false
	else: _release_focus()

func toggle_angles() -> void:
	angle_comparison = not angle_comparison
	if angle_comparison:
		_release_focus()
		settings_panel.hide()

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
		KEY_B: bright = not bright
		KEY_X: effect.config.reverse = not effect.config.reverse; _sync_controls(); replay()
		KEY_A: toggle_angles()
		KEY_P: toggle_parameters()
		KEY_RIGHT: playing = false; clock = minf(clock+1.0/60.0,duration())

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and event.keycode == KEY_ESCAPE and settings_panel.visible:
		_release_focus()
		settings_panel.hide()
		get_viewport().set_input_as_handled()
