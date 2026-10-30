extends Control
const Config = preload("res://scripts/vfx/impact/impact_config.gd")
@export var impact_settings: Config = Config.new()
const Behavior = preload("res://scripts/vfx/impact/impact_behavior.gd")
const PixelRenderer = preload("res://scripts/vfx/impact/pixel_impact.gd")
var behavior := Behavior.new()
var renderer: Node2D
var clock := 0.0
var playing := true
var looping := true
var speed := 1.0
var status: Label
var capture_dir := ""
var capture_frame := 0
var capture_busy := false
var settings_panel: PanelContainer
var param_controls: Dictionary = {}
var demo_toggle: CheckBox
var capture_parameters := false
const PARAMS := [
	["strength","Impact intensity",0.25,2.0,0.05],
	["effect_scale","Effect size",0.5,1.5,0.05],
	["direction_degrees","Incoming angle °",-180.0,180.0,5.0],
	["hit_x","Hit X (lab)",100.0,270.0,1.0],
	["hit_y","Hit Y (lab)",45.0,100.0,1.0],
	["spark_count","Spark count",0.0,40.0,1.0],
	["spark_spread_degrees","Spark spread °",10.0,160.0,0.01],
	["spark_speed","Spark speed ×",0.25,1.5,0.05],
	["spark_lifetime","Spark lifetime ×",0.5,1.5,0.05],
	["flash_seconds","Flash seconds",0.025,0.2,0.005],
	["smoke_amount","Smoke amount",0.0,1.5,0.05],
	["smoke_seconds","Smoke seconds",0.3,1.2,0.05],
	["recoil_pixels","Target recoil px",0.0,8.0,0.5],
	["recoil_seconds","Recoil seconds",0.1,0.5,0.01],
]

func _ready() -> void:
	behavior.configure(impact_settings)
	for arg in OS.get_cmdline_user_args():
		if arg == "--parameter-preview": capture_parameters = true
		if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
	RenderingServer.set_default_clear_color(Color("0b1118"))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(384,160)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	renderer = PixelRenderer.new()
	renderer.behavior = behavior
	renderer.show_demo = true
	viewport.add_child(renderer)
	var display := TextureRect.new()
	display.texture = viewport.get_texture()
	display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	display.position = Vector2(64,152)
	display.size = Vector2(1152,480)
	add_child(display)
	label_at("RAGE CAT  /  EFFECT STUDIES", Vector2(64,28),18,Color("b3a57f"))
	label_at("01   ARROW × ARMOR",Vector2(64,58),32,Color("f0ecd9"))
	label_at("PIXEL ART  /  ORIGINAL PROCEDURAL VFX",Vector2(64,108),16,Color("80949e"))
	label_at("384 × 160  /  3× NEAREST",Vector2(940,112),14,Color("80949e"))
	status = label_at("",Vector2(64,651),17,Color("f0ecd9"))
	button_at("Replay [R]",64, func(): replay())
	button_at("Pause / Play [Space]",220,func(): playing = not playing)
	button_at("Loop on/off [L]",452,func(): looping = not looping)
	button_at("Slow ¼ / 1× [S]",652,func(): speed = 0.25 if speed == 1.0 else 1.0)
	button_at("Backdrop [B]",852,func(): renderer.bright = not renderer.bright)
	label_at("Shared behavior → style renderer  •  No gameplay changes  •  Next style awaits review",Vector2(64,754),16,Color("7f949e"))
	_build_parameters()
	if not capture_dir.is_empty():
		if DisplayServer.get_name() == "headless":
			push_error("Viewport capture requires a rendering display, not headless dummy.")
			get_tree().quit(1)
			return
		DirAccess.make_dir_recursive_absolute(capture_dir)
		playing = false

func label_at(text: String, pos: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	add_child(label)
	return label

func button_at(text: String, x: float, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.position = Vector2(x,698)
	button.size = Vector2(144,38)
	button.add_theme_font_size_override("font_size",16)
	button.pressed.connect(func(): _release_editor_focus(); action.call())
	add_child(button)

func replay() -> void:
	clock = 0.0
	playing = true

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo(): return
	match event.keycode:
		KEY_P: settings_panel.visible = not settings_panel.visible
		KEY_R: replay()
		KEY_SPACE: playing = not playing
		KEY_L: looping = not looping
		KEY_S: speed = 0.25 if speed == 1.0 else 1.0
		KEY_B: renderer.bright = not renderer.bright
		KEY_RIGHT:
			playing = false
			clock = minf(clock+1.0/60.0,behavior.duration())

func _process(delta: float) -> void:
	if capture_busy or (not capture_dir.is_empty() and capture_frame >= 240): return
	if not capture_dir.is_empty():
		# Deterministic actual viewport captures: normal dark, then slow light pass.
		var frame_in_pass := capture_frame % 120
		clock = frame_in_pass / 60.0 if capture_frame < 120 else frame_in_pass / 120.0
		renderer.bright = capture_frame >= 120
		if capture_parameters and capture_frame == 120:
			apply_preset()
			settings_panel.visible = true
		speed = 1.0 if capture_frame < 120 else 0.5
	elif playing:
		clock += delta*speed
		if clock >= behavior.duration():
			if looping: clock = fposmod(clock,behavior.duration())
			else: clock = behavior.duration(); playing = false
	renderer.time = clock
	renderer.queue_redraw()
	var phase := "APPROACH" if clock < Behavior.CONTACT else ("CONTACT" if clock < Behavior.CONTACT+behavior.config.flash_seconds else ("SPARKS / DECAY" if clock < 1.15 else "SETTLE"))
	status.text = "%s    %.3f s    |    %s    |    %.2f×    |    Loop %s    •    → frame step" % [phase,clock,"CAPTURE" if not capture_dir.is_empty() else ("PLAY" if playing else "PAUSED"),speed,"ON" if looping else "OFF"]
	if not capture_dir.is_empty(): capture()

func capture() -> void:
	capture_busy = true
	await RenderingServer.frame_post_draw
	var picture := get_viewport().get_texture().get_image()
	var error := picture.save_png(capture_dir.path_join("frame_%04d.png" % capture_frame))
	if error != OK:
		push_error("Capture failed: %s" % error)
		get_tree().quit(1)
	capture_frame += 1
	capture_busy = false
	if capture_frame >= 240: get_tree().quit()

func _build_parameters() -> void:
	var toggle := Button.new()
	toggle.text = "Parameters [P]"
	toggle.position = Vector2(1030,65)
	toggle.size = Vector2(186,36)
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.pressed.connect(func(): _release_editor_focus(); settings_panel.visible = not settings_panel.visible)
	add_child(toggle)
	button_at("Reset defaults",1030,reset_defaults)
	settings_panel = PanelContainer.new()
	settings_panel.position = Vector2(842,152)
	settings_panel.size = Vector2(374,480)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("17232c")
	panel_style.content_margin_left = 12
	panel_style.content_margin_right = 12
	panel_style.content_margin_top = 10
	panel_style.content_margin_bottom = 10
	settings_panel.add_theme_stylebox_override("panel",panel_style)
	add_child(settings_panel)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(350,460)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	settings_panel.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	var heading := Label.new()
	heading.text = "ARMOR HIT / LIVE PARAMETERS"
	heading.add_theme_font_size_override("font_size",16)
	rows.add_child(heading)
	var hint := Label.new()
	hint.text = "Changes replay. Reset keeps approved defaults."
	hint.add_theme_font_size_override("font_size",12)
	rows.add_child(hint)
	for spec in PARAMS:
		var row := HBoxContainer.new()
		rows.add_child(row)
		var title := Label.new()
		title.text = spec[1]
		title.custom_minimum_size.x = 195
		title.add_theme_font_size_override("font_size",15)
		row.add_child(title)
		var spin := SpinBox.new()
		spin.min_value = spec[2]
		spin.max_value = spec[3]
		spin.step = spec[4]
		spin.custom_minimum_size.x = 120
		spin.add_theme_font_size_override("font_size",15)
		row.add_child(spin)
		param_controls[spec[0]] = spin
		spin.value_changed.connect(func(value: float): set_parameter(spec[0],value))
	demo_toggle = CheckBox.new()
	demo_toggle.text = "Show arrow + target demo"
	demo_toggle.button_pressed = true
	demo_toggle.toggled.connect(func(value: bool): renderer.show_demo = value; replay())
	rows.add_child(demo_toggle)
	var example := Button.new()
	example.text = "Example: heavy angled hit"
	example.pressed.connect(func(): _release_editor_focus(); apply_preset())
	rows.add_child(example)
	var note := Label.new()
	note.text = "Extreme combinations may leave the preview area."
	note.add_theme_font_size_override("font_size",12)
	rows.add_child(note)
	_sync_controls()
	settings_panel.hide()

func set_parameter(name: String, value: float) -> void:
	var supported := false
	for spec in PARAMS:
		if spec[0] == name: supported = true; break
	if not supported: return
	if name == "hit_x": behavior.config.hit_position.x = value
	elif name == "hit_y": behavior.config.hit_position.y = value
	else: behavior.config.set(name,value)
	behavior.config.sanitize()
	_sync_controls()
	replay()

func _sync_controls() -> void:
	for name in param_controls:
		var value: float = behavior.config.hit_position.x if name == "hit_x" else (behavior.config.hit_position.y if name == "hit_y" else behavior.config.get(name))
		param_controls[name].set_value_no_signal(value)

func reset_defaults() -> void:
	behavior.configure(Config.new())
	renderer.show_demo = true
	demo_toggle.set_pressed_no_signal(true)
	_sync_controls()
	replay()

func apply_preset() -> void:
	behavior.configure(Config.new())
	behavior.config.strength = 1.5
	behavior.config.direction_degrees = -30.0
	behavior.config.effect_scale = 1.2
	behavior.config.spark_count = 30
	behavior.config.spark_spread_degrees = 90
	behavior.config.smoke_amount = 0.6
	behavior.config.recoil_pixels = 6
	behavior.config.sanitize()
	_sync_controls()
	replay()

func _release_editor_focus() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null: focused.release_focus()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and event.keycode == KEY_ESCAPE and settings_panel != null and settings_panel.visible:
		_release_editor_focus()
		settings_panel.hide()
		get_viewport().set_input_as_handled()
