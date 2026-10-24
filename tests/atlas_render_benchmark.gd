extends SceneTree
## Manual rendered A/B benchmark. Run WITHOUT --headless on the target GPU:
## godot --path . --script res://tests/atlas_render_benchmark.gd
## Identical positions, node counts, presentation budgets and animation clocks;
## only the atlas library's enabled flag changes. No combat simulation is run.
## Capturing optional PNGs uses -- --capture-dir=/tmp/ragecat_atlas_benchmark.
## Timings are relative measurements on the executing renderer, not an FPS claim.
const WARMUP_FRAMES := 30
const MEASURED_FRAMES := 120
const VIEWPORT_SIZE := Vector2i(1280, 800)
var _original_library: VfxAtlasLibrary
var _original_vsync: int
var _original_max_fps: int
var _capture_directory := ""
var _failed := false

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("ATLAS_RENDER_BENCHMARK requires a real display; headless timings are invalid.")
		quit(2)
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			_capture_directory = argument.trim_prefix("--capture-dir=")
	if not _capture_directory.is_empty():
		if not _capture_directory.is_absolute_path() or _capture_directory.begins_with(ProjectSettings.globalize_path("res://")):
			printerr("Capture directory must be an absolute path outside the project.")
			quit(2)
			return
		if DirAccess.make_dir_recursive_absolute(_capture_directory) != OK:
			printerr("Cannot create capture directory.")
			quit(2)
			return
	_original_library = VfxAtlasRenderer.library
	if _original_library == null:
		printerr("No VFX library is configured.")
		quit(2)
		return
	for key in [&"fire_burst", &"lightning_impact", &"dark_vortex", &"fire_ring"]:
		if _original_library.find_clip(key) == null:
			printerr("Missing valid atlas clip: ", key)
			quit(2)
			return
	VfxAtlasRenderer.library = _original_library.duplicate(true) as VfxAtlasLibrary
	_original_vsync = DisplayServer.window_get_vsync_mode()
	_original_max_fps = Engine.max_fps
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	root.size = VIEWPORT_SIZE
	root.content_scale_size = VIEWPORT_SIZE
	await process_frame
	await RenderingServer.frame_post_draw
	print("ATLAS_RENDER_ENV ", JSON.stringify({"display": DisplayServer.get_name(), "renderer": RenderingServer.get_current_rendering_method(), "adapter": RenderingServer.get_video_adapter_name(), "viewport": [root.size.x, root.size.y], "warmup": WARMUP_FRAMES, "samples": MEASURED_FRAMES, "player_budget": VfxAtlasRenderer.library.player_quad_budget, "boss_budget": VfxAtlasRenderer.library.boss_quad_budget}))
	for spec in [
		{"name": "sparse", "chains": 4, "blasts": 4, "dark": 1, "rings": 0},
		{"name": "dense", "chains": 70, "blasts": 70, "dark": 3, "rings": 0},
		{"name": "rings", "chains": 0, "blasts": 0, "dark": 0, "rings": 3},
	]:
		for atlas_enabled in [false, true]:
			VfxAtlasRenderer.library.enabled = atlas_enabled
			await _measure(spec, atlas_enabled)
	VfxAtlasRenderer.library = _original_library
	_original_library = null
	DisplayServer.window_set_vsync_mode(_original_vsync)
	Engine.max_fps = _original_max_fps
	await process_frame
	print("ATLAS_RENDER_BENCHMARK ", "FAIL" if _failed else "PASS")
	quit(1 if _failed else 0)

func _fixture(spec: Dictionary) -> Dictionary:
	var stage := Node2D.new()
	root.add_child(stage)
	var chains := Node2D.new()
	var blasts := Node2D.new()
	var dark_fields := Node2D.new()
	var rings := Node2D.new()
	# Match production containers: unrelated effects must not change the chain
	# priority index and accidentally hide every lightning ribbon in dense cases.
	for container in [chains, blasts, dark_fields, rings]: stage.add_child(container)
	for i in range(int(spec.chains)):
		var flash := ElementFlash.new()
		flash.kind = "chain"
		var start := Vector2(110 + (i % 7) * 105, 140 + (i / 7) * 48)
		flash.points = PackedVector2Array([start, start + Vector2(70, -25), start + Vector2(130, 20), start + Vector2(190, -20), start + Vector2(250, 15)])
		chains.add_child(flash)
		flash.set_process(false)
		# Essential: creates the real normal-blended atlas impact child. Calling
		# queue_redraw alone would benchmark a path that omits the new impacts.
		flash._process(0.0)
	for i in range(int(spec.blasts)):
		var flash := ElementFlash.new()
		flash.kind = "blast"
		flash.radius = 70.0
		flash.position = Vector2(160 + (i % 10) * 95, 220 + (i / 10) * 65)
		blasts.add_child(flash)
		flash.set_process(false)
		flash._process(0.0)
	for i in range(int(spec.dark)):
		var field := GravityField.new()
		field.outer_radius = 140.0
		field.inner_radius = 65.0
		field.position = Vector2(350 + i * 280, 470)
		dark_fields.add_child(field)
		field.set_process(false)
	for i in range(int(spec.rings)):
		var ring := BossFireRing.new()
		ring.ai_enabled = false
		ring.position = Vector2(400 + i * 190, 400)
		ring.arena_bounds = Rect2(Vector2.ZERO, Vector2(VIEWPORT_SIZE))
		rings.add_child(ring)
		ring.set_physics_process(false)
	return {"stage": stage, "chains": chains, "blasts": blasts, "dark": dark_fields, "rings": rings}

func _advance(fixture: Dictionary, frame: int) -> void:
	for container in [fixture.chains, fixture.blasts]:
		for flash: ElementFlash in container.get_children():
			flash.remaining = flash.duration * (1.0 - float(frame % 15) / 15.0)
			flash._process(0.0)
	for field: GravityField in fixture.dark.get_children():
		field.age = float(frame) / 60.0
		field.queue_redraw()
	for ring: BossFireRing in fixture.rings.get_children():
		ring.ring_radius = 90.0 + float(frame % 90) * 3.0 + float(ring.get_index()) * 45.0
		ring._update_flame_band()
		ring.queue_redraw()

func _measure(spec: Dictionary, atlas_enabled: bool) -> void:
	var before_nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var before_orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var fixture := _fixture(spec)
	var impacts := 0
	for flash: ElementFlash in fixture.chains.get_children():
		if is_instance_valid(flash._atlas_impacts): impacts += 1
	if impacts != (int(spec.chains) if atlas_enabled else 0):
		_failed = true
		printerr("Atlas impact children were not created as expected: ", impacts)
	var samples: Array[float] = []
	var draw_calls: Array[float] = []
	var previous := Time.get_ticks_usec()
	for frame in range(WARMUP_FRAMES + MEASURED_FRAMES):
		_advance(fixture, frame)
		await process_frame
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		if frame >= WARMUP_FRAMES:
			samples.append(float(now - previous) / 1000.0)
			draw_calls.append(float(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		previous = now
	samples.sort()
	draw_calls.sort()
	var label: String = spec.name + ("_atlas" if atlas_enabled else "_baseline")
	print("ATLAS_RENDER_RESULT ", JSON.stringify({"case": label, "median_ms": samples[samples.size() / 2], "p95_ms": samples[mini(samples.size() - 1, ceili(samples.size() * 0.95) - 1)], "median_draw_calls": draw_calls[draw_calls.size() / 2], "samples": samples.size(), "impact_nodes": impacts, "chains": spec.chains, "blasts": spec.blasts, "dark": spec.dark, "rings": spec.rings}))
	if not _capture_directory.is_empty():
		var error := root.get_texture().get_image().save_png(_capture_directory.path_join(label + ".png"))
		if error != OK:
			_failed = true
			printerr("Screenshot save failed: ", error)
	var refs: Array[WeakRef] = []
	_collect_refs(fixture.stage, refs)
	fixture.stage.free()
	fixture.clear()
	await process_frame
	await process_frame
	for ref in refs:
		if ref.get_ref() != null:
			_failed = true
			printerr("Fixture node retained after free.")
	var after_nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var after_orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	if after_nodes != before_nodes or after_orphans != before_orphans:
		_failed = true
		printerr("Node leak: ", before_nodes, "/", before_orphans, " -> ", after_nodes, "/", after_orphans)

func _collect_refs(node: Node, refs: Array[WeakRef]) -> void:
	refs.append(weakref(node))
	for child in node.get_children(): _collect_refs(child, refs)
