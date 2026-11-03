extends SceneTree
## Must run on a real rendering display, not --headless. Captures outside repository.
const Frost := preload("frost_ring.gd")
var failures := 0
var checks := 0
var viewport: SubViewport
var effect: Node2D
var output := ""
func _initialize() -> void: call_deferred("run")
func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)
func frame() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()
func pixel_count(image: Image, actual_radius: float, center: Vector2 = Vector2(256, 256)) -> int:
	var count := 0
	var outside := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.01:
				count += 1
				var offset := Vector2(x + 0.5, y + 0.5) - center
				if offset.length() > actual_radius + 0.001: outside += 1
	check(outside == 0, "all rendered pixels remain inside actual radius")
	return count
func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	viewport = SubViewport.new()
	viewport.size = Vector2i(512, 512)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	effect = Frost.new()
	viewport.add_child(effect)
	for radius in [100.0, 120.0, 140.0]:
		effect.play(Vector2(256, 256), radius)
		for milliseconds in [20, 75, 120, 160, 180]:
			effect.seek(milliseconds / 1000.0)
			var image := await frame()
			var count := pixel_count(image, radius)
			check(count > 0 if milliseconds < 180 else count == 0, "visible lifecycle / clean expiry")
			if not output.is_empty():
				check(image.save_png(output + "-%d-%03d.png" % [int(radius), milliseconds]) == OK, "PNG capture saved")
		effect.seek(0.075)
		var peak := await frame()
		var maximum := 0.0
		for y in range(peak.get_height()):
			for x in range(peak.get_width()):
				if peak.get_pixel(x, y).a > 0.01:
					maximum = maxf(maximum, Vector2(x + 0.5 - 256.0, y + 0.5 - 256.0).length())
		check(maximum > radius - effect.art_pixel_size * 2.0, "full pulse reaches caller bound to within two art pixels")
		effect.paused = true
		effect.advance(0.50)
		var still := await frame()
		check(peak.get_data() == still.get_data(), "pause is pixel-identical")
		effect.paused = false
		effect.seek(0.12)
		await frame()
		effect.seek(0.075)
		var replayed := await frame()
		check(peak.get_data() == replayed.get_data(), "seek/replay is pixel-identical")
		effect.position += Vector2(24, 18)
		var moved := await frame()
		var first := peak.get_region(Rect2i(64, 64, 384, 384))
		var second := moved.get_region(Rect2i(88, 82, 384, 384))
		check(first.get_data() == second.get_data(), "local geometry translates with canvas transform")
		effect.stop()
		var cleared := await frame()
		check(pixel_count(cleared, radius) == 0, "stop removes every rendered pixel")
	effect.play(Vector2(256, 256), 1.0)
	effect.seek(0.075)
	check(pixel_count(await frame(), 1.0) > 0, "small positive radius remains drawable")
	print("FROST RING NATIVE RENDER: %d checks, %d failed" % [checks, failures])
	quit(1 if failures else 0)
