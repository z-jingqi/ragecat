extends SceneTree
const Preview = preload("res://previews/group_one/preview.gd")
const Fx = preload("res://scripts/effects/impact.gd")
const Canvas = preload("res://scripts/core/sf_canvas.gd")
const JS = preload("res://scripts/core/sf_js.gd")
func digest(words):
	var bytes = PackedByteArray()
	bytes.resize(words.size() * 4)
	for i in range(words.size()): bytes.encode_u32(i * 4, words[i])
	var hash = HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	return hash.finish().hex_encode()
func _initialize(): call_deferred("run")
func run():
	var preview = Preview.new()
	preview.paused = true
	root.add_child(preview)
	assert(preview.get_window().content_scale_size == Vector2i(640, 456), "Reserved footer must not resize the effect area")
	assert(preview.composite_frame.w == 320 and preview.composite_frame.h == 200)
	assert(preview.canvas.position == Vector2.ZERO and preview.canvas.scale == Vector2(2, 2))
	assert(preview.label.position == Vector2(8, 408), "Controls must remain below the effect area")
	await process_frame
	assert(preview.label.get_rect().end.y <= 456, "All footer text must fit inside the viewport")
	assert(preview.label.get_rect().end.x <= 640, "Footer text must fit the unchanged logical width")
	var canvas_count = 0
	for child in preview.get_children():
		if child is Canvas: canvas_count += 1
		assert(not child is Sprite2D, "Host actor must be inside the shared Frame, not between separate canvases")
	assert(canvas_count == 1, "Only one combined light/color Canvas is allowed")
	var vectors = JSON.parse_string(FileAccess.get_file_as_string("res://tests/common/presentation-vectors.json"))
	var checks = 0
	for actor_visible in [false, true]:
		for old in preview.live: old.dispose()
		preview.live.clear()
		var fx = Fx.new().configure({"kind":"hit", "x":470.0, "y":300.0, "angle":0.19, "size":0.6, "surface":4285087562, "ground":300.0, "seed":5})
		preview.live.append(fx)
		preview.actor_visible = actor_visible
		preview.px = 470.0
		preview.py = 300.0
		for tick in range(37):
			if tick: fx.update(1.0 / 60.0)
			preview.draw_buffers()
			for row in vectors.rows:
				if row.actor_visible == actor_visible and int(row.tick) == tick:
					assert(digest(preview.composite_frame.color.data) == row.color, "Combined color at tick %d actor %s" % [tick, actor_visible])
					assert(digest(preview.composite_frame.light.data) == row.light, "Combined light at tick %d actor %s" % [tick, actor_visible])
					checks += 2
	# An opaque host pixel must cover all light, including light emitted by a
	# front-pass effect. A separate front Canvas would incorrectly brighten it.
	preview.live[0].dispose()
	preview.live.clear()
	preview.draw_buffers()
	var i = (150 - 32 + 12) * 320 + 235
	assert(preview.composite_frame.color.data[i] >> 24 == 255)
	preview.composite_frame.light.data[i] = 0xffffffff
	var color = preview.composite_frame.color.data[i]
	var alpha = float(color >> 24) / 255.0
	assert(alpha == 1.0 and (1.0 - alpha) * 255.0 == 0.0)
	preview.free()
	JS.clear_property_cache()
	print("PASS combined presentation: ", checks, " original TypeScript buffer hashes; one Canvas; opaque host occlusion")
	quit()
