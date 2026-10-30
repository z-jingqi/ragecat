extends Control
## Preview owns motion, camera and UI; the reusable effect only measures and draws.
const Effect = preload("res://scripts/vfx/cel/energy_bolt.gd")
const Config = preload("res://scripts/vfx/cel/energy_bolt_config.gd")
const CAPTURE_FRAMES := 1200
const MODES := ["INTRINSIC ENERGY / CONSTANT SPEED","ACCELERATE / TAIL STRETCH","DECELERATE / TAIL CONTRACT","TURN / RECORDED FLIGHT PATH"]
const PARAMS := [
	["size","Size ×",0.25,2.5,0.05],
	["head_height","Head height",24.0,200.0,1.0],
	["direction_degrees","Launch direction °",-180.0,180.0,1.0],
	["reference_speed","Reference px/s",80.0,1600.0,10.0],
	["tail_min","Minimum tail ×",0.2,1.0,0.01],
	["tail_max","Maximum tail ×",1.0,2.5,0.01],
	["response_seconds","Tail response / sec",0.025,0.5,0.005],
	["flow_speed","Energy flow speed",0.0,4.0,0.05],
	["flow_strength","Flow strength",0.0,2.0,0.05],
	["core_pulse_amplitude","Core pulse",0.0,0.12,0.005],
	["core_pulse_rate","Pulse / second",0.2,8.0,0.1],
	["edge_shed_rate","Shed / second",0.0,24.0,0.5],
	["edge_lifetime","Shard life / sec",0.06,0.6,0.01],
	["edge_length","Shard length",4.0,70.0,1.0],
	["edge_speed","Shard speed",50.0,600.0,10.0],
]
var effect: Effect
var stage: SubViewport
var camera: Camera2D
var world: Node2D
var mode := 0
var elapsed := 0.0
var playing := true
var playback_speed := 1.0
var teal := false
var head := Vector2.ZERO
var settings_panel: PanelContainer
var param_controls: Dictionary = {}
var color_controls: Dictionary = {}
var status: Label
var pass_label: Label
var play_button: Button
var capture_dir := ""
var capture_frame := 0
var capture_busy := false
var _capture_segment := -1

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("111d2b"))
	var container := SubViewportContainer.new()
	container.position = Vector2(48,175)
	container.size = Vector2(1184,420)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	stage = SubViewport.new()
	stage.size = Vector2i(1184,420)
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(stage)
	world = Node2D.new()
	world.draw.connect(_draw_world)
	stage.add_child(world)
	effect = Effect.new()
	world.add_child(effect)
	camera = Camera2D.new()
	stage.add_child(camera)
	_label("RAGE CAT   /   CEL EFFECT STUDIES",Vector2(48,27),16,Color("94aabd"))
	_label("04   ENERGY BOLT",Vector2(48,59),34,Color("f4f0e3"))
	_label("ONE CONTINUOUS SILHOUETTE   ·   MEASURED VELOCITY   ·   NO CHARGE DEPENDENCY",Vector2(48,111),14,Color("94aabd"))
	pass_label = _label("",Vector2(65,146),14,Color("e6d8ad"))
	status = _label("",Vector2(48,616),17,Color("f1e8ce"))
	for i in range(4):
		_button(["Reference [1]","Accelerate [2]","Decelerate [3]","Turn [4]"][i],48+i*222,658,func(): set_mode(i),208)
	_button("Replay [R]",48,711,replay,156)
	play_button = _button("Pause [Space]",221,711,toggle_play,156)
	_button("Slow ¼ / 1× [S]",394,711,toggle_speed,156)
	_button("Gold / Teal [C]",567,711,func(): set_palette(not teal),156)
	_button("Reset defaults",1046,711,reset_defaults,156)
	_button("Parameters [P]",1046,64,toggle_parameters,156)
	_label("1–4 motion   ·   R replay   ·   → single frame   ·   P parameters   ·   Esc close panel",Vector2(48,763),14,Color("8195a6"))
	_build_parameters()
	_sync_controls()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
	if not capture_dir.is_empty():
		if DisplayServer.get_name() == "headless":
			push_error("Energy bolt capture requires a real Godot rendering display.")
			get_tree().quit(1)
			return
		var error := DirAccess.make_dir_recursive_absolute(capture_dir)
		if error != OK:
			push_error("Cannot create energy bolt capture directory: %s" % error)
			get_tree().quit(1)
			return
	replay()

func _draw() -> void:
	draw_rect(Rect2(48,175,1184,420),Color("455466"),false,1.0)
	# A compact, live measured-speed meter; no guessed animation-speed value.
	draw_rect(Rect2(48,645,890,3),Color("25384a"))
	if effect != null:
		draw_rect(Rect2(48,645,890*clampf(effect.actual_speed/1400.0,0,1),3),effect.config.body_color)

func _draw_world() -> void:
	var half_view := Vector2(stage.size)/camera.zoom*0.5+Vector2.ONE*10.0
	world.draw_rect(Rect2(camera.position-half_view,half_view*2.0),Color("273545"))
	# World-space markers pass the projectile, making constant speed legible.
	if mode != 0:
		var start := int((head.x-1500)/160.0)*160
		for x in range(start,start+3200,160):
			for y in range(-1000,1200,160):
				world.draw_line(Vector2(x,y),Vector2(x+15,y),Color("354759"),1.0,true)
				world.draw_line(Vector2(x,y),Vector2(x,y+6),Color("354759"),1.0,true)

func set_mode(value: int) -> void:
	mode = clampi(value,0,3)
	replay()

func replay() -> void:
	elapsed = 0.0
	playing = true
	head = Vector2.ZERO
	var direction := Vector2.RIGHT.rotated(deg_to_rad(effect.config.direction_degrees))
	effect.reset_motion(head,direction)
	# Warm with actual positions, not a forged tail parameter or target-speed input.
	var initial_speed := _motion_speed(0.0)
	for i in range(90):
		head += direction*initial_speed/60.0
		effect.advance(head,1.0/60.0)
	_update_view()

func _motion_speed(time: float) -> float:
	var blend := smoothstep(0.0,3.0,time)
	match mode:
		1: return lerpf(180.0,1280.0,blend)
		2: return lerpf(1280.0,130.0,blend)
	return effect.config.reference_speed

func step(delta: float, refresh_view: bool = true) -> void:
	if not is_finite(delta) or delta <= 0: return
	elapsed += delta
	var angle := deg_to_rad(effect.config.direction_degrees)
	if mode == 3: angle += 1.15*sin(elapsed*1.6)
	var velocity := Vector2.RIGHT.rotated(angle)*_motion_speed(elapsed)
	head += velocity*delta
	effect.advance(head,delta)
	if refresh_view: _update_view()

func _update_view() -> void:
	var direction := effect.actual_velocity.normalized() if effect.actual_speed > 0.001 else Vector2.RIGHT
	var zoom := 2.0 if mode == 0 else (0.88 if mode == 3 else 1.25)
	if settings_panel.visible: zoom *= 0.62
	var offset := direction*(140.0 if mode == 3 else 170.0)
	# Keep user-edited extreme sizes/directions inside the live viewport as well.
	var extent := Vector2.ONE
	for command in effect.build_commands(false):
		for point in command.points:
			var framed: Vector2 = point+offset
			extent.x = maxf(extent.x,absf(framed.x))
			extent.y = maxf(extent.y,absf(framed.y))
	zoom = minf(zoom,minf((380.0 if settings_panel.visible else 570.0)/extent.x,195.0/extent.y))
	camera.zoom = Vector2.ONE*zoom
	camera.position = head-offset
	if settings_panel.visible: camera.position.x += 170/zoom
	pass_label.text = "%s    /    %s" % [MODES[mode],"TEAL" if teal else "APPROVED GOLD"]
	status.text = "ACTUAL  %4.0f px/s     TAIL  %.2f×     %.2f s     %s     %.2f× playback" % [effect.actual_speed,effect.tail_scale,elapsed,"PLAYING" if playing else "PAUSED",playback_speed]
	play_button.text = "Pause [Space]" if playing else "Play [Space]"
	world.queue_redraw()
	queue_redraw()

func _process(delta: float) -> void:
	if effect == null or capture_busy: return
	if not capture_dir.is_empty():
		if capture_frame >= CAPTURE_FRAMES: return
		var segment := 0 if capture_frame < 300 else (1 if capture_frame < 540 else (2 if capture_frame < 780 else (3 if capture_frame < 1020 else 4)))
		if segment != _capture_segment:
			_capture_segment = segment
			settings_panel.visible = segment == 4
			set_palette(segment == 4,false)
			set_mode(mini(segment,3))
		step(1.0/60.0)
		_capture()
	elif playing:
		# Bounded substeps make curved history independent of display frame pacing.
		var remaining := minf(maxf(delta,0.0),0.1)*playback_speed
		while remaining > 0.000001:
			var dt := minf(remaining,1.0/120.0)
			step(dt,false)
			remaining -= dt
		_update_view()
		if elapsed > 5.0: replay()

func toggle_play() -> void:
	playing = not playing
	_update_view()

func toggle_speed() -> void:
	playback_speed = 0.25 if playback_speed == 1.0 else 1.0
	_update_view()

func set_palette(value: bool, restart: bool = true) -> void:
	teal = value
	var defaults := Config.new()
	for spec in [["core_color",Color("effff1")],["body_color",Color("83efca")],["shade_color",Color("26a995")],["flow_color",Color("8de7bd")],["spark_color",Color("e2ffef")]]:
		effect.config.set(spec[0],spec[1] if teal else defaults.get(spec[0]))
	effect.configure(effect.config)
	_sync_controls()
	if restart: replay()

func set_parameter(name: String, value: float) -> void:
	if not param_controls.has(name): return
	effect.config.set(name,value)
	effect.configure(effect.config)
	_sync_controls()
	replay()

func set_color(name: String, value: Color) -> void:
	if not color_controls.has(name): return
	effect.config.set(name,value)
	effect.configure(effect.config)
	_sync_controls()
	replay()

func reset_defaults() -> void:
	effect.configure(Config.new())
	teal = false
	playback_speed = 1.0
	_sync_controls()
	set_mode(0)

func toggle_parameters() -> void:
	settings_panel.visible = not settings_panel.visible
	_release_focus()
	_update_view()

func _sync_controls() -> void:
	for name in param_controls: param_controls[name].set_value_no_signal(effect.config.get(name))
	for name in color_controls: color_controls[name].color = effect.config.get(name)

func _build_parameters() -> void:
	settings_panel = PanelContainer.new()
	settings_panel.position = Vector2(884,193)
	settings_panel.size = Vector2(334,386)
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
	scroll.custom_minimum_size = Vector2(314,370)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	settings_panel.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation",8)
	scroll.add_child(rows)
	for spec in [["core_color","Ivory core"],["body_color","Pale-gold body"],["shade_color","Gold underside"],["flow_color","Internal flow"],["spark_color","Energy streaks"]]:
		var row := _parameter_row(rows,spec[1])
		var picker := ColorPickerButton.new()
		picker.edit_alpha = false
		picker.custom_minimum_size = Vector2(104,26)
		row.add_child(picker)
		color_controls[spec[0]] = picker
		picker.color_changed.connect(func(value: Color): set_color(spec[0],value))
	rows.add_child(HSeparator.new())
	for spec in PARAMS:
		var row := _parameter_row(rows,spec[1])
		var spin := SpinBox.new()
		spin.min_value = spec[2]
		spin.max_value = spec[3]
		spin.step = spec[4]
		spin.custom_minimum_size.x = 104
		row.add_child(spin)
		param_controls[spec[0]] = spin
		spin.value_changed.connect(func(value: float): set_parameter(spec[0],value))
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
		KEY_1: set_mode(0)
		KEY_2: set_mode(1)
		KEY_3: set_mode(2)
		KEY_4: set_mode(3)
		KEY_R: replay()
		KEY_SPACE: toggle_play()
		KEY_S: toggle_speed()
		KEY_C: set_palette(not teal)
		KEY_P: toggle_parameters()
		KEY_RIGHT: playing = false; step(1.0/60.0)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo() and event.keycode == KEY_ESCAPE and settings_panel.visible:
		for name in color_controls: color_controls[name].get_popup().hide()
		_release_focus()
		settings_panel.hide()
		_update_view()
		get_viewport().set_input_as_handled()

func _capture() -> void:
	capture_busy = true
	await RenderingServer.frame_post_draw
	var picture := get_viewport().get_texture().get_image()
	var error := picture.save_png(capture_dir.path_join("frame_%04d.png" % capture_frame))
	if error != OK:
		push_error("Energy bolt capture failed: %s" % error)
		get_tree().quit(1)
		return
	capture_frame += 1
	capture_busy = false
	if capture_frame >= CAPTURE_FRAMES: get_tree().quit()
