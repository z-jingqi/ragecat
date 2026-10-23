extends SceneTree
## Run on a real desktop with an isolated HOME. Never treat headless as native QA.
var checks := 0
var failures := 0
var captures := ""
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func settle(frames: int = 20) -> void:
	for frame in range(frames): await process_frame
func run() -> void:
	if DisplayServer.get_name() == "headless":
		print("NATIVE WINDOW SMOKE: skipped; real desktop required")
		quit()
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): captures = argument.trim_prefix("--output=")
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await settle()
	var controller: WindowSettingsController = game.window_settings
	controller.settings_path = "user://native-window-smoke.cfg"
	for locale in ["en", "zh_CN"]:
		TranslationServer.set_locale(locale)
		game.refresh_language()
		game.open_display_settings()
		await settle()
		for size in controller.available_sizes():
			controller.begin_preview(0, size)
			await settle()
			check(root.size == size, "actual window pixels " + str(size))
			check(root.unresizable, "native window resize disabled")
			check(root.min_size == size and root.max_size == size, "fixed preset bounds also constrain Wayland")
			check(root.get_visible_rect().size.is_equal_approx(Vector2(1280,800)), "logical gameplay canvas unchanged")
			controller.confirm_preview()
			await settle()
			await capture(locale + "-" + str(size.x) + "x" + str(size.y))
		for mode in controller.supported_modes():
			if mode == 0: continue
			var remembered: Vector2i = controller.active.size
			controller.begin_preview(mode, remembered)
			await settle()
			check(root.mode == mode, "actual fullscreen mode " + str(mode))
			check(root.size == DisplayServer.screen_get_size(root.current_screen), "fullscreen uses current monitor desktop")
			await capture(locale + "-mode-" + str(mode))
			controller.cancel_preview()
			await settle()
			check(root.mode == Window.MODE_WINDOWED and root.size == remembered, "fullscreen rollback restores exact window")
		game.close_display_settings()
		await settle()
		await capture(locale + "-menu")
	game.start_run(true)
	game.show_pause()
	game.open_display_settings()
	await settle()
	check(paused, "native settings pause gameplay")
	await capture("pause-settings")
	game.close_display_settings()
	check(game.current_mode == "pause" and paused, "native settings return to pause")
	game.queue_free()
	await process_frame
	paused = false
	DirAccess.remove_absolute("user://native-window-smoke.cfg")
	print("NATIVE WINDOW SMOKE: ", checks, " checks, ", failures, " failures; backend ", DisplayServer.get_name())
	quit(1 if failures else 0)
func capture(label: String) -> void:
	if captures.is_empty(): return
	DirAccess.make_dir_recursive_absolute(captures)
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(captures.path_join(label + ".png")) == OK, "capture " + label)
