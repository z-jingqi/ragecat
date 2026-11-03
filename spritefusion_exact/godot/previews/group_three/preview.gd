# Native effect preview, with original synthetic host art (no website scene art).
extends Node2D
const Frame = preload("res://scripts/core/sf_frame.gd")
const Canvas = preload("res://scripts/core/sf_canvas.gd")
const JS = preload("res://scripts/core/sf_js.gd")
@export var slug = "sparkle"
var cases = []
var chosen = 0
var c = {}
var source
var live = []
var sim_frame = 0
var call_index = 0
var accumulator = 0.0
var paused = false
var canvas
var composite_frame
var actor_visible = false
var actor_data = PackedInt64Array()
var label
var last_hook = ""
var replay_delay = 0.0
var warmup_remaining = 0

func _ready():
	get_window().size = Vector2i(960, 684)
	get_window().content_scale_size = Vector2i(640, 456)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	Engine.max_fps = 60
	RenderingServer.set_default_clear_color(Color("171b29"))
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for value in unpack(JSON.parse_string(FileAccess.get_file_as_string("res://previews/group_three/cases-f64.json"))):
		if value.slug == slug: cases.append(value)
	composite_frame = Frame.new(320, 200)
	canvas = Canvas.new()
	add_child(canvas)
	var image = Image.create(16, 32, false, Image.FORMAT_RGBA8)
	for y in range(32):
		for x in range(16):
			var head = y >= 1 and y < 8 and x >= 5 and x < 11
			var body = y >= 8 and y < 22 and x >= 4 and x < 12
			var arms = y >= 11 and y < 17 and x >= 1 and x < 15
			var legs = y >= 22 and y < 31 and ((x >= 3 and x < 6) or (x >= 10 and x < 13))
			if head or body or arms or legs: image.set_pixel(x,y,Color8(255,189,117) if head else Color8(51,84,121) if legs else Color8(78,165,214))
	var rgba = image.get_data()
	actor_data.resize(512)
	for i in range(512): actor_data[i] = rgba.decode_u32(i * 4)
	label = Label.new()
	label.position = Vector2(8, 408)
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(label)
	restart()

func restart():
	for fx in live:
		if fx.has_method("dispose"): fx.dispose()
	live.clear()
	c = cases[chosen]
	source = load("res://scripts/effects/" + slug + ".gd")
	sim_frame = 0
	call_index = 0
	accumulator = 0.0
	replay_delay = 0.0
	last_hook = ""
	actor_visible = c.options.get("actor", false)
	spawn()
	warmup_remaining = int(c.get("warmup", 0))
	draw_buffers()
	present()

func spawn():
	var calls = c.get("calls", [{"at": 0.0}])
	while call_index < calls.size() and calls[call_index].at <= float(sim_frame) / 60.0 + 1e-12:
		var opts = c.options.duplicate(true)
		opts.merge(calls[call_index].get("options", {}), true)
		if opts.get("actor", false) == true:
			opts.actor = {"feet": func(): return [160.0, 300.0], "head": func(): return [160.0, 238.0]}
		opts.shake = func(trauma): last_hook = "shake(" + str(trauma) + ")"
		live.append(source.new().configure(opts))
		call_index += 1

func _process(delta):
	if paused: return
	if replay_delay > 0.0:
		replay_delay -= delta
		if replay_delay <= 0.0: restart()
		return
	accumulator += delta
	if accumulator < 1.0 / 60.0: return
	# Never skip a source tick. If rendering is slow, playback slows instead of
	# spiralling into an unbounded wall-clock catch-up loop.
	accumulator -= 1.0 / 60.0
	if warmup_remaining > 0:
		for fx in live: fx.update(1.0 / 60.0)
		draw_buffers()
		warmup_remaining -= 1
	else:
		sim_frame += 1
		spawn()
		if sim_frame == c.get("stopFrame", -1):
			for fx in live: fx.stop()
		for fx in live: fx.update(1.0 / 60.0)
		draw_buffers()
		if call_index == c.get("calls", [{"at":0.0}]).size() and live.all(func(fx): return fx.done()):
			replay_delay = 1.0
	present()

func draw_buffers():
	# One shared Frame preserves source overwrites, blending and light accumulation.
	composite_frame.clear()
	for fx in live: fx.draw(composite_frame, "back")
	if actor_visible:
		for y in range(32):
			for x in range(16):
				var word = actor_data[y * 16 + x]
				if word >> 24:
					composite_frame.color.put(72.0 + x, 118.0 + y, word)
	for fx in live: fx.draw(composite_frame, "front")

func present():
	# Add the final combined light once, then alpha-composite the combined color.
	canvas.present(composite_frame)
	label.text = "%s | %s | %.2fs%s\nSpace pause · R replay · ←/→ situation · C collect · S stop" % [slug, c.situation, float(sim_frame) / 60.0, (" | " + last_hook if warmup_remaining == 0 and not last_hook.is_empty() else " | Warmup: %d source ticks remaining" % warmup_remaining if warmup_remaining > 0 else "")]

func _unhandled_key_input(event):
	if not event.pressed or event.echo: return
	match event.keycode:
		KEY_SPACE: paused = not paused
		KEY_R: restart()
		KEY_LEFT:
			chosen = posmod(chosen - 1, cases.size())
			restart()
		KEY_RIGHT:
			chosen = posmod(chosen + 1, cases.size())
			restart()
		KEY_C:
			for fx in live:
				if fx.has_method("invoke"): fx.invoke("collect", [])
		KEY_S:
			for fx in live: fx.stop()

func _exit_tree():
	for fx in live:
		if fx.has_method("dispose"): fx.dispose()
	live.clear()

func unpack(v):
	if v is Dictionary:
		if v.has("__f64"): return str(v.__f64).hex_decode().decode_double(0)
		var result = {}
		for key in v: result[key] = unpack(v[key])
		return result
	if v is Array:
		var result = []
		for item in v: result.append(unpack(item))
		return result
	return v
