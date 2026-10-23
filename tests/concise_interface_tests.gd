extends SceneTree
## UI content and navigation contracts. Optional real-render captures stay outside the repository.
var checks := 0
var failures := 0
var output := ""

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="): output = argument.trim_prefix("--capture-dir=")
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func settle() -> void:
	for i in range(8): await process_frame

func has_key(node: Node, key: String) -> bool:
	for control in node.find_children("*", "Control", true, false):
		if control.get_meta("translation_key", "") == key: return true
	return false

func capture(name: String) -> void:
	await settle()
	if output.is_empty(): return
	check(DisplayServer.get_name() != "headless", "Screenshots require a real rendering display")
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(output)
	check(root.get_texture().get_image().save_png(output.path_join(name + ".png")) == OK, "Saved " + name)

func run() -> void:
	var preferences := DisplaySettings.new()
	preferences.sound_enabled = false
	preferences.save_settings()
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await settle()
	for viewport in [Vector2i(960, 600), Vector2i(1280, 800)]:
		game.window_settings.begin_preview(WindowSettingsController.WINDOWED, viewport)
		game.window_settings.confirm_preview()
		await settle()
		check(root.size == viewport or DisplayServer.get_name() == "headless", "Requested native window size is active")
		for locale in ["en", "zh_CN"]:
			game.set_language(locale)
			game.show_menu()
			await settle()
			for key in ["MENU_INTRO", "MENU_TAGLINE", "SETTINGS_LANGUAGE"]:
				check(not has_key(game.ui, key), "No redundant menu copy " + key)
			check(has_key(game.ui, "MENU_CONTROLS"), "Keyboard and controller controls remain discoverable")
			check(root.gui_get_focus_owner() != null, "Menu retains actionable initial focus")
			var prefix := "%s_%dx%d_" % [locale, viewport.x, viewport.y]
			await capture(prefix + "menu")
			game.open_display_settings()
			await settle()
			var panel := game.overlay.get_node("ModalScroll/ModalContent").get_child(0) as WindowSettingsPanel
			check(panel != null, "Display settings still open")
			for key in ["DISPLAY_MODE", "DISPLAY_RESOLUTION", "DISPLAY_DESKTOP_HINT"]:
				check(not has_key(panel, key), "Self-explanatory selector has no duplicate label " + key)
			check(not panel.mode_choice.get_item_text(0).is_empty(), "Mode identifies itself")
			check(panel.size_choice.get_item_text(0).contains("×"), "Resolution identifies itself")
			await capture(prefix + "display")
			game.close_display_settings()
			game.open_achievements()
			check(has_key(game.ui, "ACH_INTRO"), "Unlock semantics remain available")
			await capture(prefix + "achievements")
			game.close_achievements()
			game.start_run(true)
			game.arena.process_mode = Node.PROCESS_MODE_DISABLED
			await settle()
			check(not has_key(game.ui, "HUD_HELP") and not has_key(game.ui, "LAB_TITLE"), "No repeated HUD instructions or lab heading")
			check(has_key(game.ui, "LAB_HINT"), "Lab rank/detail controls remain discoverable")
			check(game.lab._rank_controls.size() > 0, "Lab still exposes upgrade ranks")
			await capture(prefix + "practice")
			game.enter_practice_navigation()
			game.lab.show_upgrade_details("fire_bow")
			await settle()
			check(game.lab._details_body.text.length() > 0, "Full passive effect and numeric description remains")
			check(has_key(game.lab, "DETAILS_CLOSE"), "Details retain explicit Close")
			game.lab._close_upgrade_details()
			game.return_from_practice_navigation()
			game.show_pause()
			await settle()
			check(root.gui_get_focus_owner() != null and has_key(game.ui, "PAUSE_RESUME"), "Pause keeps functional controls")
			game.resume_run()
			game.start_run(false)
			game.arena.process_mode = Node.PROCESS_MODE_DISABLED
			game.catalog.all_unlocked = true
			game.show_upgrades()
			await settle()
			var cards := 0
			for control in game.overlay.find_children("*", "Button", true, false):
				if control.has_meta("upgrade_key"):
					cards += 1
					check(control.text.contains("\n") and control.text.contains("/"), "Upgrade retains rank and effect description")
			check(cards == 3, "Three upgrade choices remain")
			await capture(prefix + "upgrades")
			game.show_death()
			check(has_key(game.ui, "DEATH_STATS"), "Run result retains statistics")
			game.show_menu()
	game.set_language("en") # Leave shared aggregate fixtures in their expected locale.
	game.queue_free()
	await settle()
	paused = false
	print("CONCISE INTERFACE: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
