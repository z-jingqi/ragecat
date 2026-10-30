extends Control
const Behavior = preload("res://scripts/vfx/charge/charge_behavior.gd")
const PixelRenderer = preload("res://scripts/vfx/charge/pixel_charge.gd")
const Demo = preload("res://scripts/vfx_lab/charge/pixel_charge_demo.gd")
const Config = preload("res://scripts/vfx/charge/charge_config.gd")
@export var settings: Resource = Config.new()
var behavior := Behavior.new()
var parameter_panel: PanelContainer
var fields: Dictionary = {}
var preset_selector: OptionButton
var preset_name := "DEFAULT"
var stop_at := -1.0
var auto_demo := true
var parameter_demo := false
var capture_limit := 720
var renderer: Node2D
var clock := 0.0
var playing := true
var looping := true
var speed := 1.0
var status: Label
var capture_dir := ""
var capture_frame := 0
var capture_busy := false

func _ready() -> void:
	settings = settings.duplicate() if settings is Config else Config.new()
	settings.sanitize()
	behavior.config = settings
	for arg in OS.get_cmdline_user_args():
		if arg == "--parameter-demo": parameter_demo = true; capture_limit = 960
		if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
	RenderingServer.set_default_clear_color(Color("0b1118"))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(384,160)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	renderer = PixelRenderer.new()
	renderer.behavior = behavior
	renderer.demo = Demo.new()
	renderer.show_demo = true
	viewport.add_child(renderer)
	var display := TextureRect.new()
	display.texture = viewport.get_texture()
	display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	display.position = Vector2(64,152)
	display.size = Vector2(1152,480)
	add_child(display)
	label_at("RAGE CAT  /  EFFECT STUDIES", Vector2(64,28),18,Color("b3a57f"))
	label_at("03   PIXEL CHARGE",Vector2(64,58),32,Color("f0ecd9"))
	label_at("PIXEL ART  /  ORIGINAL PROCEDURAL VFX",Vector2(64,108),16,Color("80949e"))
	label_at("384 × 160  /  3× NEAREST",Vector2(940,112),14,Color("80949e"))
	status = label_at("",Vector2(64,651),17,Color("f0ecd9"))
	button_at("Replay [R]",64, func(): replay())
	button_at("Pause / Play [Space]",220,func(): playing = not playing)
	button_at("Loop on/off [L]",452,func(): looping = not looping)
	button_at("Slow ¼ / 1× [S]",652,func(): speed = 0.25 if speed == 1.0 else 1.0)
	button_at("Backdrop [B]",852,func(): renderer.bright = not renderer.bright)
	button_at("Dissipate [C]",1044,func(): stop_charge())
	label_at("Shared behavior → style renderer  •  No gameplay changes  •  Inward particles + ground wind  •  A: auto demo / sustain  •  C: dissipate",Vector2(64,754),16,Color("7f949e"))
	build_parameter_panel()
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
	button.pressed.connect(action)
	add_child(button)

func replay() -> void:
	clock = 0.0
	stop_at = -1.0
	playing = true

func demo_stop_time() -> float:
	return Behavior.START+settings.charge_seconds+0.6

func stop_charge() -> void:
	if stop_at < 0.0 and clock >= Behavior.START: stop_at = clock

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo(): return
	match event.keycode:
		KEY_P: parameter_panel.visible = not parameter_panel.visible
		KEY_ESCAPE: parameter_panel.hide(); get_viewport().gui_release_focus()
		KEY_R: replay()
		KEY_C: stop_charge()
		KEY_A: auto_demo = not auto_demo; replay()
		KEY_SPACE: playing = not playing
		KEY_L: looping = not looping
		KEY_S: speed = 0.25 if speed == 1.0 else 1.0
		KEY_B: renderer.bright = not renderer.bright
		KEY_RIGHT:
			playing = false
			clock = minf(clock+1.0/60.0,behavior.duration(stop_at))

func _process(delta: float) -> void:
	if capture_busy or (not capture_dir.is_empty() and capture_frame >= capture_limit): return
	if not capture_dir.is_empty():
		# 4 s per preset, or complete default normal + half-speed + early dissipation.
		if parameter_demo:
			if capture_frame % 240 == 0: apply_preset(capture_frame/240)
			clock = (capture_frame % 240)/60.0
			stop_at = demo_stop_time()
			speed = 1.0
			renderer.bright = capture_frame >= 480
		else:
			if capture_frame < 180:
				stop_at = demo_stop_time()
				clock = capture_frame/60.0
				speed = 1.0
			elif capture_frame < 540:
				stop_at = demo_stop_time()
				clock = (capture_frame-180)/120.0
				speed = 0.5
				renderer.bright = true
			else:
				clock = (capture_frame-540)/60.0
				speed = 1.0
				stop_at = 1.05
				renderer.bright = false
	elif playing:
		clock += delta*speed
		if auto_demo and stop_at<0 and clock>=demo_stop_time(): stop_at=demo_stop_time()
		if clock >= behavior.duration(stop_at):
			if looping:
				clock = fposmod(clock,behavior.duration(stop_at))
				stop_at = -1.0
			else: clock = behavior.duration(stop_at); playing = false
	renderer.time = clock
	if auto_demo and stop_at<0 and clock>=demo_stop_time(): stop_at=demo_stop_time()
	renderer.stop_at = stop_at
	renderer.queue_redraw()
	var phase: String = behavior.sample(clock,stop_at).phase
	phase += " / AUTO" if auto_demo else " / MANUAL"
	if parameter_demo: phase = preset_name+" / "+phase
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
	if capture_frame >= capture_limit: get_tree().quit()

func build_parameter_panel() -> void:
	var open := Button.new()
	open.text = "Parameters [P]"
	open.position = Vector2(1030,65)
	open.size = Vector2(186,38)
	open.pressed.connect(func(): parameter_panel.visible = not parameter_panel.visible)
	add_child(open)
	var presets := OptionButton.new()
	preset_selector = presets
	presets.position = Vector2(760,65)
	presets.size = Vector2(252,38)
	for name in ["Default", "Quick / compact", "Heavy / wide", "Quiet / sparse"]: presets.add_item(name)
	presets.add_item("Custom")
	presets.set_item_disabled(4,true)
	presets.item_selected.connect(apply_preset)
	add_child(presets)
	parameter_panel = PanelContainer.new()
	parameter_panel.position = Vector2(815,155)
	parameter_panel.size = Vector2(402,470)
	add_child(parameter_panel)
	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,12)
	parameter_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",5)
	margin.add_child(column)
	var heading := Label.new()
	heading.text = "CHARGE PARAMETERS  /  live replay"
	column.add_child(heading)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation",12)
	column.add_child(grid)
	for spec in [["charge_seconds","Build-up duration (s)",0.4,2.5,0.05],["radius","Base wind radius (px)",24,64,1],["wind_speed","Wind speed (×)",0.25,3,0.05],["rise_height","Wind rise height (px)",16,60,1],["inward_speed","Particle inward speed (×)",0.25,3,0.05],["strength","Wind strength",0.5,2,0.05],["intensity","Sustained intensity",0.25,1,0.05],["dissipate_seconds","Dissipation time (s)",0.2,1,0.05],["particle_count","Particle count",0,40,1]]:
		var title := Label.new()
		title.text = spec[1]
		title.add_theme_font_size_override("font_size",15)
		grid.add_child(title)
		var input := SpinBox.new()
		input.min_value = spec[2]; input.max_value = spec[3]; input.step = spec[4]
		input.custom_minimum_size.x = 142
		input.value = settings.get(spec[0])
		input.tooltip_text = spec[1]+" — changes replay the effect"
		input.value_changed.connect(func(value): set_parameter(spec[0],value))
		grid.add_child(input)
		fields[spec[0]] = input
	var note := Label.new()
	note.text = "P / Esc closes • Tab moves between fields
A: auto demo / sustain • C: dissipate now."
	note.add_theme_font_size_override("font_size",13)
	column.add_child(note)
	var reset := Button.new()
	reset.text = "Reset defaults + replay"
	reset.pressed.connect(func(): apply_preset(0))
	column.add_child(reset)
	var close := Button.new()
	close.text = "Close parameters"
	close.pressed.connect(func(): parameter_panel.hide(); get_viewport().gui_release_focus())
	column.add_child(close)
	parameter_panel.hide()

func set_parameter(name: String, value: float) -> void:
	if not fields.has(name): return
	settings.set(name,value)
	settings.sanitize()
	fields[name].set_value_no_signal(settings.get(name))
	preset_name = "CUSTOM"
	preset_selector.select(4)
	if name != "intensity": replay()

func apply_preset(index: int) -> void:
	settings = Config.new()
	match index:
		1:
			settings.charge_seconds=0.6; settings.radius=32
			settings.strength=0.7; settings.dissipate_seconds=0.3; settings.particle_count=14
		2:
			settings.charge_seconds=2.0; settings.radius=60
			settings.strength=1.6; settings.particle_count=36; settings.wind_speed=1.5; settings.rise_height=50
		3:
			settings.radius=42; settings.intensity=0.45; settings.wind_speed=0.6; settings.rise_height=28
			settings.charge_seconds=1.0; settings.particle_count=8
	settings.sanitize()
	behavior.config = settings
	preset_name = ["DEFAULT","QUICK / COMPACT","HEAVY / WIDE","QUIET / SPARSE"][clampi(index,0,3)]
	preset_selector.select(clampi(index,0,3))
	for name in fields: fields[name].set_value_no_signal(settings.get(name))
	replay()
