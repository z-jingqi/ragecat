extends SceneTree
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func press_pad(button_index: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button_index
	event.pressed = true
	root.push_input(event)
	event.pressed = false
	root.push_input(event)
func settle() -> void:
	for frame in range(3): await process_frame
func run() -> void:
	var controller := WindowSettingsController.new()
	controller.native_enabled = false
	controller.settings_path = "user://window-contract.cfg"
	DirAccess.remove_absolute(controller.settings_path)
	root.add_child(controller)
	check(not controller.is_host_embedded(), "standalone editor executable is not falsely treated as embedded")
	check(not controller.previewing and controller.active.mode == 0, "first launch safe window")
	for area in [Vector2i(1920,1080), Vector2i(1920,1200), Vector2i(3440,1440), Vector2i(1024,768), Vector2i(800,600), Vector2i(640,360), Vector2i(3840,2160)]:
		var sizes := controller.available_sizes(area)
		check(not sizes.is_empty(), "available size for " + str(area))
		for value in sizes: check(value.x <= area.x and value.y <= area.y and value.x > 0 and value.y > 0, "fits usable area")
		check(controller.initial_size(area) in sizes, "initial preset valid")
	check(controller.supported_modes("Wayland", "Linux") == [0,3], "Wayland hides redundant exclusive")
	check(controller.supported_modes("Windows", "Windows") == [0,3,4], "Windows has engine exclusive")
	check(controller.supported_modes("macOS", "macOS") == [0,3,4], "macOS has engine exclusive")
	check(controller.sanitize({"mode":"4", "size":"1920x1080"}).mode == 0, "corrupt mode rejected")
	check(controller.sanitize({"mode":99, "size":Vector2i(-3,99999)}).size == controller.initial_size(), "corrupt size rejected")
	var config := ConfigFile.new()
	config.set_value("audio", "enabled", false)
	config.set_value("display", "language", "zh_CN")
	config.set_value("custom", "keep", 123)
	config.save(controller.settings_path)
	controller.begin_preview(3, Vector2i(1280,800))
	check(controller.previewing and controller.seconds_remaining() == 15, "15 second preview")
	var untouched := ConfigFile.new()
	untouched.load(controller.settings_path)
	check(not untouched.has_section("window"), "preview does not persist")
	controller.confirm_preview()
	config.load(controller.settings_path)
	check(controller.confirmed.mode == 3 and not controller.previewing, "confirmed fullscreen")
	check(config.get_value("audio","enabled") == false and config.get_value("custom","keep") == 123, "other preferences preserved")
	controller.begin_preview(0, Vector2i(960,600))
	controller.cancel_preview()
	check(controller.active.mode == 3 and controller.active.size == Vector2i(1280,800), "revert restores window selection")
	controller.begin_preview(0, Vector2i(960,600))
	paused = true
	Engine.time_scale = 0.0
	controller.deadline_msec = Time.get_ticks_msec() - 1
	await process_frame
	await process_frame
	check(not controller.previewing and controller.active.mode == 3, "timeout works paused and timescale zero")
	controller.begin_preview(0, Vector2i(960,600))
	controller.deadline_msec = Time.get_ticks_msec() - 1
	controller.confirm_preview()
	check(controller.confirmed.mode == 3, "expired input cannot confirm")
	paused = false
	Engine.time_scale = 1.0
	controller.begin_preview(0, Vector2i(960,600))
	root.remove_child(controller)
	check(not controller.previewing and controller.active.mode == 3, "exit cancels pending change")
	controller.free()
	DirAccess.remove_absolute("user://window-contract.cfg")
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	for locale in ["en", "zh_CN"]:
		TranslationServer.set_locale(locale)
		game.open_display_settings()
		await process_frame
		var panel := game.overlay.get_node("ModalScroll/ModalContent").get_child(0) as WindowSettingsPanel
		check(panel != null and game.current_mode == "display", "menu enters display " + locale)
		check(TranslationServer.translate("DISPLAY_EXCLUSIVE") == ("Fullscreen" if locale == "en" else "全屏"), "fullscreen display name " + locale)
		check(TranslationServer.translate("DISPLAY_FULLSCREEN") == ("Borderless fullscreen" if locale == "en" else "无边框全屏"), "borderless name stays distinct " + locale)
		var original_definition: WindowDefinition = panel.controller.definition
		panel.controller.definition = original_definition.duplicate()
		panel.controller.definition.presets = [Vector2i(960,600)]
		panel.refresh()
		panel.mode_choice.select(1)
		panel.refresh_mode()
		panel.mode_choice.select(0)
		panel.refresh_mode()
		check(panel.size_choice.get_item_text(0) == "960 × 600" and not panel.size_choice.disabled, "one-preset screen restores honest window label")
		panel.controller.definition = original_definition
		panel.refresh()
		panel.mode_choice.grab_focus()
		press_pad(JOY_BUTTON_A)
		await settle()
		check(panel.mode_choice.get_popup().visible, "controller opens mode options")
		press_pad(JOY_BUTTON_B)
		await settle()
		check(not panel.mode_choice.get_popup().visible and game.current_mode == "display", "controller Back closes only dropdown")
		panel.controller.begin_preview(3, Vector2i(1280,800))
		await process_frame
		check(root.gui_get_focus_owner() == panel.revert_button, "safe focus is revert")
		press_pad(JOY_BUTTON_A)
		await settle()
		check(not panel.controller.previewing, "controller default confirm chooses safe revert")
		panel.controller.begin_preview(3, Vector2i(1280,800))
		await settle()
		panel.close_panel()
		await process_frame
		check(game.current_mode == "menu" and not game.window_settings.previewing, "closing rolls back and returns")
	game.start_run(true)
	game.show_pause()
	game.open_display_settings()
	await process_frame
	check(paused, "settings keep gameplay paused")
	game.close_display_settings()
	await process_frame
	check(game.current_mode == "pause" and paused, "back returns to paused menu")
	game.queue_free()
	await process_frame
	paused = false
	print("WINDOW SETTINGS: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
