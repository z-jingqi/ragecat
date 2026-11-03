extends SceneTree
const Preview = preload("res://previews/group_three/preview.gd")
const JS = preload("res://scripts/core/sf_js.gd")
func bytes_of(words):
	var bytes = PackedByteArray()
	bytes.resize(words.size() * 4)
	for i in range(words.size()): bytes.encode_u32(i * 4, words[i])
	return bytes
func digest(bytes):
	var hash = HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	return hash.finish().hex_encode()
func _initialize(): call_deferred("run")
func run():
	var args = OS.get_cmdline_user_args()
	assert(args.size() == 2, "Usage: -- combined-oracle.json output-directory")
	var oracle = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var output = args[1]
	DirAccess.make_dir_recursive_absolute(output)
	var preview = Preview.new()
	preview.slug = oracle.slug
	preview.paused = true
	root.add_child(preview)
	var canvas_count = 0
	for child in preview.get_children():
		assert(not child is Sprite2D, "Actor must be part of the shared Frame")
		if child.get_script() == preload("res://scripts/core/sf_canvas.gd"): canvas_count += 1
	assert(canvas_count == 1, "Exactly one combined light/color canvas")
	for i in range(preview.cases.size()):
		if preview.cases[i].id == oracle.id: preview.chosen = i
	preview.restart()
	for n in range(preview.warmup_remaining):
		for fx in preview.live: fx.update(1.0 / 60.0)
		preview.draw_buffers()
	var checks = 0
	var last = int(oracle.rows[-1].frame)
	for n in range(last + 1):
		preview.sim_frame = n
		if n:
			preview.spawn()
			if n == preview.c.get("stopFrame", -1):
				for fx in preview.live: fx.stop()
			for fx in preview.live: fx.update(1.0 / 60.0)
		preview.draw_buffers()
		for row in oracle.rows:
			if int(row.frame) != n: continue
			for channel in ["color", "light"]:
				var bytes = bytes_of(preview.composite_frame.get(channel).data)
				assert(digest(bytes) == row[channel], "%s frame %d %s" % [oracle.id, n, channel])
				var file = FileAccess.open(output.path_join("%04d-%s.rgba" % [n, channel]), FileAccess.WRITE)
				file.store_buffer(bytes)
				checks += 1
	preview.free()
	JS.clear_property_cache()
	print("PASS ", oracle.id, " ", checks, " combined native buffer hashes")
	quit()
