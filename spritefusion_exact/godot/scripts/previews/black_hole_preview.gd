# Native Black Hole source-effect preview; procedural exact Canvas lens.
# Independent scene: the other accepted family previews are unchanged.
# Shared Frame ordering is back -> actor pixels -> front, never split canvases.
extends Node2D
const Frame = preload("res://scripts/core/sf_frame.gd")
const Canvas = preload("res://scripts/core/sf_canvas.gd")
const JS = preload("res://scripts/core/sf_js.gd")
const ActorFixture = preload("res://scripts/previews/heal_preview.gd")
var slug := "black-hole"
var cases: Array = []
var chosen := 0
var current: Dictionary = {}
var frame
var canvas
var lens_host
var background: Image
var actor_data := PackedInt64Array()
var live: Array = []
var tick := 0
var call_index := 0
var paused := false
var elapsed := 0.0
var replay_delay := 0.0
var hooks: Array = []
var pending_lens: Dictionary = {}
var label: Label
var stage_viewport: SubViewport
const STAGE_SIZE := Vector2i(640, 400)
const LOGICAL_SIZE := Vector2i(640, 456)
const FOOTER_RECT := Rect2(8, 408, 624, 40)

func _ready() -> void:
	get_window().content_scale_size = LOGICAL_SIZE
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	get_window().size = Vector2i(960, 684)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	RenderingServer.set_default_clear_color(Color("171b29"))
	for item in JSON.parse_string(FileAccess.get_file_as_string("res://scripts/previews/group_two_cases.json")):
		if item.slug == slug: cases.append(item)
	var bytes := Marshalls.base64_to_raw(ActorFixture.ACTOR_BASE64)
	for i in range(512): actor_data.append(bytes.decode_u32(i * 4))
	background = Image.create(320, 200, false, Image.FORMAT_RGBA8)
	for y in range(200):
		for x in range(320):
			var color := Color("171b29") if y < 150 else Color("282c36")
			if y >= 150 and (x % 32 == 0 or (y - 150) % 16 == 0): color = Color("373c49")
			background.set_pixel(x, y, color)
	var stage_parent: Node = self
	if slug == "black-hole":
		# Keep snapshot sampling on the original 640x400 scene.
		# The new footer must never enter the lens snapshot or its refracted samples.
		stage_viewport = SubViewport.new()
		stage_viewport.size = STAGE_SIZE
		stage_viewport.world_2d = World2D.new()
		stage_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		stage_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		add_child(stage_viewport)
		var stage_output := Sprite2D.new()
		stage_output.centered = false
		stage_output.texture = stage_viewport.get_texture()
		add_child(stage_output)
		stage_parent = stage_viewport
	var backdrop := Sprite2D.new()
	backdrop.centered = false
	backdrop.texture = ImageTexture.create_from_image(background)
	backdrop.scale = Vector2(2, 2)
	stage_parent.add_child(backdrop)
	# Lens reads the background snapshot only, before the art buffers.
	if slug == "black-hole" and ResourceLoader.exists("res://scripts/hosts/black_hole_lens_exact.gd"):
		lens_host = load("res://scripts/hosts/black_hole_lens_exact.gd").new()
		stage_parent.add_child(lens_host)
		lens_host.set_anchors_preset(Control.PRESET_TOP_LEFT)
		lens_host.position = Vector2.ZERO
		lens_host.size = Vector2(STAGE_SIZE)
		var scene_image := background.duplicate()
		scene_image.resize(STAGE_SIZE.x, STAGE_SIZE.y, Image.INTERPOLATE_NEAREST)
		lens_host.set_source_rgba(scene_image.get_data(), STAGE_SIZE.x, STAGE_SIZE.y)
	frame = Frame.new(320, 200)
	canvas = Canvas.new()
	stage_parent.add_child(canvas)
	var footer_background := ColorRect.new()
	footer_background.position = Vector2(0, 400)
	footer_background.size = Vector2(640, 56)
	footer_background.color = Color("10131d")
	footer_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(footer_background)
	label = Label.new()
	label.position = FOOTER_RECT.position
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 13)
	add_child(label)
	restart()

func actor_feet(): return [160.0, 300.0]
func actor_head(): return [160.0, 238.0]
func actor_hand(): return {"x":184.0,"y":254.0,"a":0.0}
func actor_silhouette(): return {"x":72.0,"y":118.0,"w":16.0,"h":32.0,"data":actor_data}
func record_hook(name: String, args: Array) -> void: hooks.append({"frame":tick,"name":name,"args":args})
func on_shake(a): record_hook("shake",[a])
func on_flash(a,b): record_hook("flash",[a,b])
func on_darken(a): record_hook("darken",[a])
func on_lens(a):
	pending_lens = a.duplicate(true)
	record_hook("lens",[a])
func on_cue(name, data = {}): record_hook("cue",[name,data])
func on_kick(a,b): record_hook("kick",[a,b])
func on_ripple(a,b,c,d,e,f,g): record_hook("ripple",[a,b,c,d,e,f,g])

func dispose_effects() -> void:
	for effect in live: effect.dispose()
	live.clear()

func restart() -> void:
	dispose_effects()
	current = cases[chosen]
	tick = 0
	call_index = 0
	elapsed = 0.0
	replay_delay = 0.0
	hooks.clear()
	pending_lens.clear()
	spawn()
	render_frame()

func spawn() -> void:
	var calls = current.get("calls", [{"at":0.0}])
	while call_index < calls.size() and calls[call_index].at <= tick / 60.0 + 1e-12:
		var options = current.options.duplicate(true)
		options.merge(calls[call_index].get("options", {}), true)
		if options.get("actor") == true:
			options.actor = {"feet":actor_feet,"head":actor_head,"hand":actor_hand,"silhouette":actor_silhouette}
		options.merge({"shake":on_shake,"flash":on_flash,"darken":on_darken,"lens":on_lens,"kick":on_kick,"ripple":on_ripple,"cue":on_cue}, true)
		live.append(load("res://scripts/effects/" + slug + ".gd").new().configure(options))
		call_index += 1

func advance_frame() -> void:
	tick += 1
	pending_lens.clear()
	spawn()
	if tick == int(current.get("stopFrame", -1)):
		for effect in live: effect.stop()
	for effect in live: effect.update(1.0 / 60.0)
	render_frame()

func render_frame() -> void:
	frame.clear()
	for effect in live: effect.draw(frame, "back")
	# Keep synthetic actor visible as a location/occlusion reference in every case.
	for y in range(32):
		for x in range(16):
			var pixel: int = actor_data[y * 16 + x]
			if (pixel >> 24) != 0: frame.color.put(72 + x, 118 + y, pixel)
	for effect in live: effect.draw(frame, "front")
	if lens_host != null:
		if pending_lens.is_empty(): lens_host.visible = false
		else: lens_host.present(pending_lens)
	canvas.present(frame)
	update_footer()

func update_footer() -> void:
	label.text = "%s / %s | %.2fs | Space pause | R restart | Left/Right variant | S stop\nHooks recorded; flash/shake/darken not applied." % [slug,current.situation,tick/60.0]
	# Shape the actual font before sizing; a position-only check misses clipped text.
	label.size = label.get_combined_minimum_size()
	assert(FOOTER_RECT.encloses(label.get_rect()), "Footer font rectangle exceeds its outside-stage area")

func all_done() -> bool:
	return call_index == current.get("calls", [{"at":0.0}]).size() and live.all(func(effect): return effect.done())

func _process(delta: float) -> void:
	if paused: return
	if replay_delay > 0.0:
		replay_delay -= delta
		if replay_delay <= 0.0: restart()
		return
	elapsed += delta
	if elapsed >= 1.0 / 60.0:
		# No skipped source ticks and no unbounded catch-up if the exact port is slow.
		elapsed = minf(elapsed - 1.0 / 60.0, 1.0 / 60.0)
		advance_frame()
		if all_done(): replay_delay = 1.0

func _unhandled_key_input(event) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.keycode:
		KEY_SPACE: paused = not paused
		KEY_R: restart()
		KEY_LEFT:
			chosen = posmod(chosen - 1, cases.size())
			restart()
		KEY_RIGHT:
			chosen = posmod(chosen + 1, cases.size())
			restart()
		KEY_S:
			for effect in live: effect.stop()

# Diagnostic Image only: excludes the lens and camera hooks; not a viewport capture.
func diagnostic_image() -> Image:
	var output := background.duplicate()
	var light: Image = frame.light.to_image()
	var color: Image = frame.color.to_image()
	for y in range(200):
		for x in range(320):
			var bg := background.get_pixel(x,y)
			var glow := light.get_pixel(x,y)
			bg.r = minf(1.0,bg.r+glow.r*glow.a)
			bg.g = minf(1.0,bg.g+glow.g*glow.a)
			bg.b = minf(1.0,bg.b+glow.b*glow.a)
			output.set_pixel(x,y,bg.blend(color.get_pixel(x,y)))
	output.resize(640,400,Image.INTERPOLATE_NEAREST)
	return output

func _exit_tree() -> void:
	dispose_effects()
