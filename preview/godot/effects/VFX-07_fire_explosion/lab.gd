extends Control
const Fire = preload("res://effects/VFX-07_fire_explosion/fire.gd")
const PRESETS_PATH = "res://effects/VFX-07_fire_explosion/presets.json"
var presets: Array = []
var config: Dictionary
var effects: Array = []
var time_since_play := 0.0
var loop_enabled := true
var paused := false
var background_index := 0
var selected_index := 0
var rate := 1.0
var _status: Label
var _preset: OptionButton
var _sliders: Dictionary = {}
var _labels: Dictionary = {}
var _rebuilding := false
var _auto_showcase := false
var _showcase_time := 0.0
var _last_showcase_slot := -1
var _loop_toggle: CheckButton
var _pause_button: Button
var _capture_dir := ""
var _capture_frame := 0
var _capture_pending := false
var _capture_limit := 720

func _ready() -> void:
	presets = JSON.parse_string(FileAccess.get_file_as_string(PRESETS_PATH)).presets
	config = presets[0].duplicate(true)
	RenderingServer.set_default_clear_color(Color("#161b24"))
	for item in [{"at":Vector2(105,192), "scale":1.0}, {"at":Vector2(291,205), "scale":3.0}]:
		var fx = Fire.new()
		fx.scale = Vector2.ONE * item.scale
		fx.auto_tick = false
		add_child(fx)
		effects.append({"fx":fx, "at":item.at})
	_build_ui()
	_sync_controls()
	_auto_showcase = "--fire-showcase" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fire-capture-dir="):
			_capture_dir = arg.trim_prefix("--fire-capture-dir=")
			DirAccess.make_dir_recursive_absolute(_capture_dir)
		elif arg.begins_with("--fire-capture-frames="):
			_capture_limit = clampi(int(arg.trim_prefix("--fire-capture-frames=")),1,3600)
	play()

func _label(text: String, at: Vector2, font_size := 12, color := Color("#dfe5e8")) -> Label:
	var l := Label.new()
	l.text = text
	l.position = at
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	add_child(l)
	return l

func _button(text: String, at: Vector2, width: float, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.position = at
	b.size = Vector2(width,24)
	b.add_theme_font_size_override("font_size", 11)
	b.pressed.connect(callback)
	add_child(b)
	return b

func _build_ui() -> void:
	_label("VFX-07  /  FIRE EXPLOSION", Vector2(18,12), 19)
	_label("CODE-GENERATED  •  GODOT 4.6.3  •  NO FRAME ATLAS", Vector2(18,39), 10, Color("#95a2ad"))
	_label("ACTUAL  /  1× logical pixels", Vector2(22,74), 11)
	_label("INSPECT  /  3× nearest", Vector2(216,74), 11)
	_label("compact blast / rising fire", Vector2(36,229), 10, Color("#95a2ad"))
	_label("same time / same seed", Vector2(240,278), 10, Color("#95a2ad"))
	_label("ONE SHOT / NO HOST OR TEXTURES", Vector2(18,278), 10, Color("#95a2ad"))
	_status = _label("", Vector2(18,297), 11)
	_button("Replay", Vector2(18,323), 63, play)
	_pause_button = _button("Pause", Vector2(85,323), 58, _toggle_pause)
	_button("Clear", Vector2(147,323), 55, _clear)
	_button("+1/60 s", Vector2(206,323), 64, _step)
	_loop_toggle = CheckButton.new()
	_loop_toggle.text = "Loop"
	_loop_toggle.position = Vector2(275,322)
	_loop_toggle.add_theme_font_size_override("font_size", 11)
	_loop_toggle.button_pressed = true
	_loop_toggle.toggled.connect(func(v: bool): loop_enabled = v)
	add_child(_loop_toggle)
	_button("BG", Vector2(357,323), 42, func(): background_index = (background_index + 1) % 4; queue_redraw())
	_label("LIVE PARAMETERS", Vector2(428,14), 13)
	_label("Changes replay immediately", Vector2(428,34), 10, Color("#95a2ad"))
	_preset = OptionButton.new()
	_preset.position = Vector2(428,54)
	_preset.size = Vector2(194,24)
	_preset.add_theme_font_size_override("font_size",11)
	for p in presets:
		_preset.add_item(str(p.name))
	_preset.item_selected.connect(_select_preset)
	add_child(_preset)
	_slider("radius", "Radius px",6,30,1,94)
	_slider("duration", "Duration s",0.18,0.85,0.01,126)
	_slider("rise", "Rise px",0,45,1,158)
	_slider("lobes", "Fire lobes",3,10,1,190)
	_slider("embers", "Embers",0,12,1,222)
	_slider("spread", "Spread ×",0.5,1.5,0.05,254)
	_button("Seed +1", Vector2(428,291),65,func(): config.seed=(int(config.seed)+1)&4095; play())
	_button("Reset",Vector2(497,291),58,_reset_defaults)
	_button("Rate",Vector2(559,291),63,func(): rate=0.25 if rate==1.0 else 1.0; play())
	_label("Palette: warm fire / blue test", Vector2(428,339), 10, Color("#95a2ad"))

func _slider(key: String, title: String, low: float, high: float, step: float, y: float) -> void:
	_labels[key] = _label(title, Vector2(428,y), 10)
	var slider := HSlider.new()
	slider.position = Vector2(518,y+2)
	slider.size = Vector2(104,16)
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.value_changed.connect(func(v: float):
		if not _rebuilding:
			config[key] = int(v) if key in ["lobes","embers"] else v
			_labels[key].text = "%s %s" % [title, str(snappedf(v,0.01))]
			play())
	add_child(slider)
	_sliders[key] = slider
	_labels[key].set_meta("title", title)

func _sync_controls() -> void:
	_rebuilding = true
	for key in _sliders:
		_sliders[key].value = config[key]
		_labels[key].text = "%s %s" % [_labels[key].get_meta("title"), str(snappedf(float(config[key]),0.01))]
	_preset.select(selected_index)
	_rebuilding = false

func _select_preset(index: int) -> void:
	selected_index = index
	config = presets[index].duplicate(true)
	_sync_controls()
	play()

func _reset_defaults() -> void:
	rate = 1.0
	loop_enabled = true
	_loop_toggle.button_pressed = true
	background_index = 0
	_select_preset(0)
	queue_redraw()

func play() -> void:
	paused = false
	time_since_play = 0.0
	_pause_button.text = "Pause"
	for item in effects:
		item.fx.playback_rate = rate
		item.fx.play(item.at, config)
	queue_redraw()

func _toggle_pause() -> void:
	paused = not paused
	_pause_button.text = "Resume" if paused else "Pause"

func _clear() -> void:
	loop_enabled = false
	_loop_toggle.button_pressed = false
	paused = false
	_pause_button.text = "Pause"
	for item in effects:
		item.fx.clear()

func _step() -> void:
	paused = true
	_pause_button.text = "Resume"
	for item in effects:
		if item.fx.age < 0.0:
			item.fx.replay()
		item.fx.tick(1.0 / 60.0)
	time_since_play += 1.0/60.0

func _process(delta: float) -> void:
	if _auto_showcase:
		_showcase_time += delta
		var slot := int(_showcase_time / 3.0)
		if slot != _last_showcase_slot:
			_last_showcase_slot = slot
			selected_index = slot % presets.size()
			config = presets[selected_index].duplicate(true)
			background_index = slot % 4
			_sync_controls()
			play()
	if not paused:
		time_since_play += delta * rate
		for item in effects:
			item.fx.tick(delta)
		if loop_enabled and time_since_play >= maxf(float(config.duration) + 0.55,0.8):
			play()
	var phase := "CLEAR" if effects[0].fx.age < 0.0 else ("ACTIVE" if effects[0].fx.active else "ENDED")
	_status.text = "%s | %.3f / %.2fs | %.2f× | seed %d" % [phase,maxf(effects[0].fx.age,0.0),config.duration,rate,config.seed]

	if not _capture_dir.is_empty() and not _capture_pending:
		_capture_frame_after_draw()

func _capture_frame_after_draw() -> void:
	_capture_pending = true
	await RenderingServer.frame_post_draw
	var output := _capture_dir.path_join("frame_%05d.png" % _capture_frame)
	var error := get_viewport().get_texture().get_image().save_png(output)
	if error != OK:
		push_error("VFX-07 capture failed: " + error_string(error))
		get_tree().quit(1)
		return
	_capture_frame += 1
	_capture_pending = false
	if _capture_frame >= _capture_limit:
		print("VFX-07 actual Godot rendered frames saved: ", _capture_frame)
		_capture_dir = ""
		set_process(false)
		get_tree().quit()

func _draw() -> void:
	draw_rect(Rect2(0,0,640,360), Color("#161b24"))
	draw_rect(Rect2(412,0,228,360), Color("#212936"))
	var stage := Rect2(18,96,382,174)
	var backgrounds := [Color("#242b35"),Color.BLACK,Color("#f5f0df"),Color("#404652")]
	draw_rect(stage, backgrounds[background_index])
	if background_index == 3:
		for y in range(96,270,8):
			for x in range(18,400,8):
				if ((x-18)/8+(y-96)/8) % 2 == 0:
					draw_rect(Rect2(x,y,8,8).intersection(stage), Color("#555b68"))
