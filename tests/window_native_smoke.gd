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
		var panel := game.overlay.get_node("ModalScroll/ModalContent").get_child(0) as WindowSettingsPanel
		for size in controller.available_sizes():
			select_and_apply(panel, 0, size)
			await settle_native(controller)
			check(root.size == size, "actual window pixels " + str(size))
			check(root.unresizable, "native window resize disabled")
			check(root.min_size == size and root.max_size == size, "fixed preset bounds also constrain Wayland")
			check(root.get_visible_rect().size.is_equal_approx(Vector2(1280,800)), "logical gameplay canvas unchanged")
			panel.keep_button.pressed.emit()
			await settle()
			check(controller.confirmed.size == size and not controller.previewing, "UI Keep persists actual preset")
			await capture(locale + "-" + str(size.x) + "x" + str(size.y))
		for mode in controller.supported_modes():
			if mode == 0: continue
			var remembered: Vector2i = controller.active.size
			select_and_apply(panel, mode, remembered)
			await settle_native(controller)
			check(root.mode == mode, "actual fullscreen mode " + str(mode))
			check(root.size == DisplayServer.screen_get_size(root.current_screen), "fullscreen uses current monitor desktop")
			await capture(locale + "-mode-" + str(mode))
			panel.revert_button.pressed.emit()
			await settle_native(controller)
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

func select_and_apply(panel: WindowSettingsPanel, mode: int, size: Vector2i) -> void:
	# Exercise the selection-to-request path, not just the controller's API.
	panel.mode_choice.select(panel.modes.find(mode))
	panel.mode_choice.item_selected.emit(panel.mode_choice.selected)
	if mode == WindowSettingsController.WINDOWED:
		panel.size_choice.select(panel.sizes.find(size))
		panel.size_choice.item_selected.emit(panel.size_choice.selected)
	panel.apply_button.pressed.emit()

func settle_native(controller: WindowSettingsController) -> void:
	# Resize acknowledgement uses real time, not a fixed number of render frames.
	var deadline := Time.get_ticks_msec() + 4000
	while controller.apply_pending and Time.get_ticks_msec() < deadline:
		await process_frame
	await settle()
	check(not controller.apply_pending and controller.apply_error_key.is_empty(), "native request acknowledged before Keep")
