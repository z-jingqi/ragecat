extends SceneTree
const Effect = preload("res://effects/VFX-21_xp_pickup/xp_external.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var fx = Effect.new()
	root.add_child(fx)
	RenderingServer.set_default_clear_color(Color.BLACK)
	fx.sample_position(Vector2(30, 30))
	fx.sample_position(Vector2(35, 30))
	fx.sample_position(Vector2(40, 30))
	await process_frame
	await RenderingServer.frame_post_draw
	var trail: Image = root.get_texture().get_image()
	assert(trail.get_pixel(37, 30).g > 0.4, "Native trail pixels missing")
	assert(trail.get_pixel(40, 27).g < 0.05, "Adapter must not draw a collectible")
	fx.collect(Vector2(64, 64))
	await process_frame
	await RenderingServer.frame_post_draw
	var burst: Image = root.get_texture().get_image()
	for point in [Vector2i(67, 64), Vector2i(61, 64), Vector2i(64, 67), Vector2i(64, 61)]:
		assert(burst.get_pixelv(point).g > 0.9, "Native four-way glint missing")
	assert(burst.get_pixel(64, 64).g < 0.05, "Glint center should remain open")
	fx.tick(0.14)
	await process_frame
	await RenderingServer.frame_post_draw
	var cleared: Image = root.get_texture().get_image()
	assert(cleared.get_pixel(67, 64).g < 0.05, "Expired glint remained visible")
	print("XP_EXTERNAL_NATIVE_RENDER PASS: trail, no collectible, four-way glint, complete clear")
	quit()
