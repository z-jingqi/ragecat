extends SceneTree
## Run using a real rendering display, not --headless (dummy renderer).
const Burn := preload("ground_burn.gd")
var checks := 0
var failed := 0
var viewport: SubViewport
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failed += 1
		push_error(label)
func frame() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()
func count_visible(image: Image) -> int:
	var result := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x,y).a > 0.01: result += 1
	return result
func run() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(192,192)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var burn := Burn.new()
	viewport.add_child(burn)
	burn.play(Vector2(96,96),36,4,{"seed":37})
	burn.seek(1.0)
	var original: Image = await frame()
	var n := count_visible(original)
	check(n > 500 and n < 4500,"native shader renders bounded fire footprint")
	var transparent := 0
	var fire_pixels := 0
	var outside := 0
	for y in range(192):
		for x in range(192):
			var color := original.get_pixel(x,y)
			var point := Vector2(x+.5,y+.5)-Vector2(96,96)
			if point.length() > 38 and color.a > .01: outside += 1
			if point.length() < 30 and color.a < .5: transparent += 1
			if color.a > .85 and color.r > .7 and color.g > .3: fire_pixels += 1
	check(outside == 0,"nothing escapes caller footprint beyond one art-pixel quantization")
	check(transparent > 1800,"ground remains mostly transparent for scene readability")
	check(fire_pixels > 20,"distinct visible flame tongues instead of boundary-only zone")
	var paused: Image = await frame()
	check(original.get_data() == paused.get_data(),"paused externally owned clock is pixel-identical")
	burn.seek(1.25)
	var later: Image = await frame()
	check(original.get_data() != later.get_data(),"flame geometry evolves over actual render time")
	burn.seek(1.0)
	var repeated: Image = await frame()
	check(original.get_data() == repeated.get_data(),"same seed and absolute age reproduce exact image")
	burn.seek(4.0)
	var expired: Image = await frame()
	check(count_visible(expired) == 0,"exact expiry clears every rendered pixel")
	burn.play(Vector2(78,96),36,4,{"intensity":0.0,"ground_opacity":0.5})
	burn.seek(1.0)
	var second := Burn.new()
	viewport.add_child(second)
	second.play(Vector2(114,96),36,4,{"intensity":0.0,"ground_opacity":0.5})
	second.seek(1.0)
	var overlap: Image = await frame()
	# First zone's right boundary is deep inside the second zone's fill. Its
	# outline must remain bright, not be covered by the later sibling's coal bed.
	# Compare actual compositing against deliberately broken Z ordering. Raw
	# SubViewport pixels may be premultiplied, so do not assume opaque RGB values.
	burn.outline.z_index = 0
	var wrong_order: Image = await frame()
	burn.outline.z_index = 1
	var retained := 0
	var max_difference := 0.0
	for y in range(58,134):
		for x in range(74,116):
			var color := overlap.get_pixel(x,y)
			var covered := wrong_order.get_pixel(x,y)
			max_difference = maxf(max_difference,color.r-covered.r)
			if color.r > covered.r + .10 and color.g > covered.g + .05: retained += 1
	print("OVERLAP diagnostic: samples=%d, max red difference=%.4f; before=%s after=%s" % [retained,max_difference,overlap.get_pixel(111,95),wrong_order.get_pixel(111,95)])
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			var directory := argument.trim_prefix("--output=")
			DirAccess.make_dir_recursive_absolute(directory)
			overlap.save_png(directory.path_join("overlap-correct.png"))
			wrong_order.save_png(directory.path_join("overlap-wrong.png"))
	check(retained >= 8,"overlap retains earlier zone boundary above later fill (%d samples)" % retained)
	burn.clear(); second.clear()
	var cleared: Image = await frame()
	check(count_visible(cleared) == 0,"clear removes both zones immediately")
	viewport.free()
	print("GROUND BURN NATIVE RENDER: %d checks, %d failed" % [checks,failed])
	quit(1 if failed else 0)
