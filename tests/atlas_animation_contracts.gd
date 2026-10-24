extends SceneTree
## Baked animation is presentation only; sampling never owns combat or RNG.
const REQUIRED: Array[StringName] = [&"fire_explosion", &"fire_burst", &"fire_loop", &"fire_ground", &"fire_ring", &"skyfire_fall", &"stone_impact", &"charge_dust", &"stone_fall", &"summon", &"lightning_impact", &"ice_shell", &"ice_shatter", &"ice_thaw", &"death_smoke", &"shield_break"]
const RGBA_BUDGET_BYTES := 64 * 1024 * 1024
class RingCanvas extends Node2D:
	var draws := 0
	func _draw() -> void:
		draws += 1
		VfxAtlasRenderer.draw_ring(self, &"fire_ring", 0.25, 120.0, 28.0)
		VfxAtlasRenderer.draw_ring(self, &"fire_ring", 0.5, 160.0, 28.0)

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func run() -> void:
	var library := load("res://resources/feedback/atlas/library.tres") as VfxAtlasLibrary
	check(library != null, "production atlas library loads")
	if library == null:
		quit(1)
		return
	check(library.find_clip(&"energy_orb") == null and library.find_clip(&"dark_vortex") == null, "Retired orb/vortex atlases are not resident")
	var bytes := 0
	var textures: Dictionary = {}
	var identifiers: Dictionary = {}
	for key in REQUIRED:
		check(library.find_clip(key) != null, "required presentation is registered: " + str(key))
	for clip: VfxAtlasClip in library.clips:
		check(clip != null and clip.valid(), "authored clip valid")
		if clip == null or not clip.valid(): continue
		check(not identifiers.has(clip.id), "clip key unique: " + str(clip.id))
		identifiers[clip.id] = true
		var size := clip.texture.get_size()
		check(int(size.x) % clip.columns == 0 and int(size.y) % clip.rows == 0, "atlas cells have whole pixels: " + str(clip.id))
		check(size.x <= 4096 and size.y <= 4096, "atlas fits 4K texture ceiling: " + str(clip.id))
		check(is_finite(clip.opacity) and clip.opacity >= 0 and clip.opacity <= 1, "authored opacity valid")
		check(is_finite(clip.size_multiplier) and clip.size_multiplier > 0, "authored size valid")
		if not textures.has(clip.texture.resource_path):
			textures[clip.texture.resource_path] = true
			bytes += int(size.x * size.y) * 4
		for frame in range(clip.frames):
			var at := (float(frame) + 0.25) / clip.fps
			check(clip.frame_at(at) == frame, "correct time sample %s/%d" % [clip.id, frame])
			var rect := clip.source_rect(at)
			check(rect.position.x >= 0 and rect.position.y >= 0 and rect.end.x <= size.x and rect.end.y <= size.y, "UV cell stays inside atlas")
			check(rect.size == Vector2(size.x / clip.columns, size.y / clip.rows), "UV preserves one cell size")
		check(clip.frame_at(0, true) == 0, "normalized starts at first frame")
		check(clip.frame_at(1, true) == clip.frames - 1, "normalized ends on last frame")
		check(clip.frame_at(100, true) == clip.frames - 1, "normalized clamps excess duration")
		check(clip.frame_at(-1) == 0 and clip.frame_at(INF) == 0 and clip.frame_at(NAN) == 0, "invalid clocks safely select first frame")
		var next_cycle := (clip.frames + 0.25) / clip.fps
		check(clip.frame_at(next_cycle) == (0 if clip.loop else clip.frames - 1), "loop wrapping or one-shot hold is explicit")
		var image := clip.texture.get_image()
		check(image != null and not image.is_empty(), "texture can be inspected")
		if image != null and not image.is_empty():
			check(image.get_format() in [Image.FORMAT_RGBA8, Image.FORMAT_RGBAF, Image.FORMAT_RGBAH], "atlas preserves alpha channel")
	check(bytes <= RGBA_BUDGET_BYTES, "unique RGBA textures remain within 64 MiB")
	var invalid := VfxAtlasClip.new()
	check(not invalid.valid() and invalid.source_rect(0) == Rect2(), "missing texture safely invalid")
	if not library.clips.is_empty():
		invalid.texture = library.clips[0].texture
		invalid.columns = 0
		check(not invalid.valid(), "zero columns rejected")
		invalid.columns = 4
		invalid.rows = 0
		check(not invalid.valid(), "zero rows rejected")
		invalid.rows = 4
		invalid.frames = 17
		check(not invalid.valid(), "frames exceeding atlas rejected")
		invalid.frames = 16
		invalid.fps = INF
		check(not invalid.valid(), "infinite fps rejected")
		invalid.fps = 0
		check(not invalid.valid(), "zero fps rejected")
	var original := VfxAtlasRenderer.library
	var isolated := library.duplicate(true) as VfxAtlasLibrary
	VfxAtlasRenderer.library = isolated
	isolated.enabled = false
	var canvas := Node2D.new()
	check(not VfxAtlasRenderer.available(&"fire_burst"), "disabled atlas exposes procedural fallback")
	check(not VfxAtlasRenderer.draw_clip(canvas, &"fire_burst", 0, Rect2(0, 0, 32, 32)), "disabled draw returns fallback without commands")
	isolated.enabled = true
	check(not VfxAtlasRenderer.draw_clip(canvas, &"missing", 0, Rect2(0, 0, 32, 32)), "missing clip exposes fallback")
	isolated.player_quad_budget = 2
	isolated.boss_quad_budget = 1
	VfxAtlasRenderer._frame = -1
	check(VfxAtlasRenderer._reserve(false), "first player visual admitted")
	check(VfxAtlasRenderer._reserve(false), "second player visual admitted")
	check(not VfxAtlasRenderer._reserve(false), "player visual budget bounded")
	check(VfxAtlasRenderer._reserve(true), "boss reserve independent of player saturation")
	check(not VfxAtlasRenderer._reserve(true), "boss budget bounded")
	seed(41231)
	var expected := randi()
	seed(41231)
	for clip: VfxAtlasClip in isolated.clips:
		clip.source_rect(0.123)
		clip.frame_at(10.0)
		VfxAtlasRenderer.available(clip.id)
	VfxAtlasRenderer._reserve(false)
	check(randi() == expected, "atlas sampling and budgeting do not consume global RNG")
	VfxAtlasRenderer.library = original
	var ring_canvas := RingCanvas.new()
	root.add_child(ring_canvas)
	for i in range(3):
		await process_frame
	check(ring_canvas.draws > 0, "ring lifecycle test runs real CanvasItem draw notification")
	var retained: Array = ring_canvas.get_meta(&"vfx_ring_meshes", [])
	check(retained.size() == 2, "multiple rings in one canvas frame retain both meshes")
	var first_mesh: WeakRef = weakref(retained[0]) if retained.size() > 0 else null
	for mesh: ArrayMesh in retained:
		check(mesh.get_surface_count() == 1 and mesh.get_rid().is_valid(), "ring command mesh has a live render resource")
	retained = []
	# Do not clear the array stored by the canvas: only release our local reference.
	ring_canvas.queue_redraw()
	for i in range(3):
		await process_frame
	check(first_mesh != null and first_mesh.get_ref() == null, "previous-frame meshes released on redraw")
	var next_retained: Array = ring_canvas.get_meta(&"vfx_ring_meshes", [])
	check(next_retained.size() == 2, "redraw replaces rather than accumulates retained meshes")
	var final_mesh: WeakRef = weakref(next_retained[0]) if next_retained.size() > 0 else null
	next_retained = []
	ring_canvas.queue_free()
	await process_frame
	check(final_mesh != null and final_mesh.get_ref() == null, "canvas disposal releases ring mesh resources")
	canvas.free()
	isolated = null
	invalid = null
	await process_frame
	check(VfxAtlasRenderer.library == original, "test restores production library without leaked actor references")
	print("Atlas animation contracts: %d checks, %d failures; unique RGBA bytes: %d" % [checks, failures, bytes])
	quit(1 if failures > 0 else 0)
