extends SceneTree
const FixedPath := preload("fixed_path.gd")
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, text: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(text)
func frame(view: SubViewport) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return view.get_texture().get_image()
func pixels(image: Image) -> int:
	var count := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.1: count += 1
	return count
func run() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(384, 224)
	view.transparent_bg = true
	view.disable_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var fx := FixedPath.new()
	view.add_child(fx)
	var path := PackedVector2Array([Vector2(35, 100), Vector2(100, 70), Vector2(170, 140), Vector2(250, 70), Vector2(330, 130)])
	fx.play_path(path)
	fx.seek(0.05)
	var first := await frame(view)
	check(pixels(first) > 30, "native fixed path contains visible pixel arcs")
	for y in range(first.get_height()):
		for x in range(first.get_width()):
			if first.get_pixel(x, y).a > 0.1:
				check(x >= 25 and x <= 341 and y >= 40 and y <= 164, "arc stays within snapshot geometry envelope")
	fx.paused = true
	fx.advance(5)
	var frozen := await frame(view)
	check(first.get_data() == frozen.get_data(), "native pause exact pixels")
	fx.paused = false
	fx.seek(0.11)
	var later := await frame(view)
	check(pixels(later) > 30 and first.get_data() != later.get_data(), "native arc visibly advances along path")
	fx.seek(0.05)
	var repeated := await frame(view)
	check(first.get_data() == repeated.get_data(), "native backward seek reproduces pixels")
	fx.advance(10)
	var cleared := await frame(view)
	check(pixels(cleared) == 0 and fx.done, "native expiry leaves zero residue")
	fx.replay()
	fx.seek(0.05)
	var replayed := await frame(view)
	check(first.get_data() == replayed.get_data(), "native replay reproducible")
	fx.reset()
	var reset_frame := await frame(view)
	check(pixels(reset_frame) == 0 and fx.get_child_count() == 0, "native reset removes every visual")
	print("FIXED_PATH_RENDER_PASSED ", checks, " failures=", failures)
	view.free()
	quit(1 if failures else 0)
