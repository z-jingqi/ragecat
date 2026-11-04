# Run with --headless for explicitly-labelled diagnostic Images.
# Run without --headless on a working display for actual viewport captures.
extends SceneTree
const Scene = preload("res://scenes/effects/heal.tscn")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var args = OS.get_cmdline_user_args()
	var output: String = args[0] if args.size() else "/tmp/sf-heal-preview"
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 400)
	root.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	RenderingServer.set_default_clear_color(Color(0.05, 0.055, 0.07, 1.0))
	var preview = Scene.instantiate()
	root.add_child(preview)
	preview.set_physics_process(false)
	preview.auto_loop = false
	var native_display := DisplayServer.get_name() != "headless"
	for target in [0, 15, 45, 90, 150, 180]:
		while preview.tick < target: preview.advance_frame()
		assert(preview.canvases[0].scale == Vector2(2, 2))
		assert(preview.canvases[1].scale == Vector2(2, 2))
		var image: Image
		var mode: String
		if native_display:
			await process_frame
			await RenderingServer.frame_post_draw
			image = root.get_texture().get_image()
			mode = "viewport"
		else:
			image = preview.diagnostic_image()
			mode = "diagnostic-image-not-viewport"
		assert(image.get_width() == 1280 and image.get_height() == 400)
		assert(image.save_png(output + "/heal-mana-%03d-%s.png" % [target, mode]) == OK)
		print("CAPTURE ", mode, " tick=", target, " done=", preview.effects[0].done(), "/", preview.effects[1].done())
	print("DISPLAY ", DisplayServer.get_name(), "; actual viewport verified=", native_display)
	preview.queue_free()
	await process_frame
	quit(0)
