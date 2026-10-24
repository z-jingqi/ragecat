extends SceneTree
## Real production UI contracts; optional captures require a rendering display.
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
	for i in range(6): await process_frame

func capture(name: String) -> void:
	if output.is_empty(): return
	check(DisplayServer.get_name() != "headless", "Capture uses actual rendering")
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(output)
	check(root.get_texture().get_image().save_png(output.path_join(name + ".png")) == OK, "Captured " + name)

func snapshot(game: Node) -> Array:
	return [game.arena.director.elapsed, game.arena.stats.hp, game.arena.player.dash_cooldown,
		game.arena.rng.state, game.arena.ranks.duplicate(true), game.arena.player.position]

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
		for locale in ["en", "zh_CN"]:
			game.set_language(locale)
			game.start_run(true, 717)
			game.arena.set_sound_enabled(false)
			await settle()
			var prefix := "%s_%dx%d_" % [locale, viewport.x, viewport.y]
			check(game.arena.bounds == Rect2(0, 0, 1280, 800), "Practice uses the complete logical playfield")
			check(game.lab.visible and not paused, "Lab opens by default without pausing simulation")
			game.return_from_practice_navigation()
			check(game.combat_hud.get_parent() is CanvasLayer, "HUD floats in the independent canvas layer")
			check(game.combat_hud.get_global_rect() == Rect2(0, 0, 1280, 800), "HUD root fills the logical viewport")
			check(game.combat_hud.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Empty HUD space does not consume pointer input")
			check(not game.combat_hud.boss_group.visible, "No empty Boss rail")
			for child in game.combat_hud.find_children("*", "Label", true, false):
				check(not str(child.text).contains("Dash") and not str(child.text).contains("冲刺"), "No cooldown/ready text on HUD")
			await capture(prefix + "practice")
			game.practice_command("preset_ice")
			game.arena.apply_ranks({"element_type":"ice","enchant_rank":3,"element_skill_rank":3,"burst":3,"pierce":3,"shield":3,"damage_flat":3,"attack_speed":3,"move_speed":3})
			game.update_hud()
			var before := snapshot(game)
			game.open_run_details()
			await settle()
			check(game.current_mode == "details" and paused, "Opening details pauses live practice")
			check(game.overlay.get_node("ModalScroll").scroll_vertical == 0, "Details initially open at their first line")
			check(snapshot(game) == before, "Details do not advance combat or cooldown")
			var rows := 0
			for control in game.overlay.find_children("*", "Label", true, false):
				if control.has_meta("owned_upgrade"):
					rows += 1
					check(control.text.length() > 0 and control.text.contains("/"), "Owned upgrade retains rank and full effect")
			check(rows > 5, "Current upgrade list is available in details")
			await capture(prefix + "details_top")
			var scroll: ScrollContainer = game.overlay.get_node("ModalScroll")
			var close_button: Button
			for node in game.overlay.find_children("*", "Button", true, false):
				if node.get_meta("details_close", false): close_button = node
			check(close_button != null and not scroll.is_ancestor_of(close_button), "Details have an always-visible close button outside scrolling content")
			check(Rect2(0, 0, 1280, 800).encloses(close_button.get_global_rect()), "Fixed Close remains inside viewport")
			var down := InputEventJoypadButton.new()
			down.button_index = JOY_BUTTON_DPAD_DOWN
			down.pressed = true
			root.push_input(down)
			down.pressed = false
			root.push_input(down)
			await settle()
			check(scroll.scroll_vertical > 0, "Controller Down scrolls the detailed descriptions")
			game.scroll_run_details(10000)
			await settle()
			await capture(prefix + "details_bottom")
			check(close_button.visible and Rect2(0, 0, 1280, 800).encloses(close_button.get_global_rect()), "Close stays visible at end of details")
			var back := InputEventJoypadButton.new()
			back.button_index = JOY_BUTTON_B
			back.pressed = true
			root.push_input(back)
			back.pressed = false
			root.push_input(back)
			check(game.current_mode == "practice" and not paused, "Controller Back restores live practice")
			game.show_pause()
			game.open_run_details()
			game.open_run_details() # Re-entry cannot replace the saved return context.
			await settle()
			game.close_run_details()
			await settle()
			check(game.current_mode == "pause" and paused, "Details opened from pause return to pause")
			check(root.gui_get_focus_owner().get_meta("translation_key", "") == "RUN_DETAILS", "Return restores the Details menu focus")
			game.resume_run()
			game.practice_option("time_scale", 0.0)
			game.open_run_details()
			game.close_run_details()
			check(paused and game.current_mode == "practice", "Details preserve practice simulation pause")
			game.practice_option("time_scale", 1.0)
			game.enter_practice_navigation()
			check(game.lab.visible and not paused, "Practice controls overlay a live full map")
			game.return_from_practice_navigation()
			check(not game.lab.visible and not paused, "Practice controls close without reserving map space")
			for identity in ["mountainbreaker", "beastcaller", "wildfire"]:
				game.arena.clear_enemies()
				var boss: BossActor = game.arena.spawn_enemy(identity, Vector2(640, 36))
				boss.ai_enabled = false
				game.update_hud()
				check(game.combat_hud.boss_group.visible and game.combat_hud.boss_bar.max_value == boss.max_health, "Fixed HUD always shows current Boss health")
				check(Rect2(0, 0, 1280, 800).encloses(game.combat_hud.boss_group.get_global_rect()), "Boss HUD stays inside screen at upper edge")
				game.arena.set_enemy_health_bars(false)
				game.update_hud()
				check(game.combat_hud.boss_group.visible, "Enemy health toggle never hides Boss HUD")
				await capture(prefix + identity)
			game.arena.player.position = Vector2(50, 30)
			game.arena.follow_camera.sync_now()
			game.update_hud()
			check(game.combat_hud.status_group.modulate.a == 1.0, "Camera overscan keeps legal edge position clear of health HUD")
			# Exercise true screen-space occlusion independently of camera framing.
			# Do not advance physics at this synthetic position outside the playfield.
			var hud_center: Vector2 = game.combat_hud.status_group.get_global_rect().get_center()
			game.arena.player.position = game.arena.get_global_transform_with_canvas().affine_inverse() * hud_center
			game.update_hud()
			check(game.combat_hud.status_group.modulate.a < 1.0, "Screen-overlapping player fades floating health group rather than hiding hazards")
			game.arena.player.position = Vector2(640, 400)
			game.arena.follow_camera.sync_now()
			game.update_hud()
			check(game.combat_hud.status_group.modulate.a == 1.0, "HUD opacity restores away from player")
			game.start_run(false, 717)
			check(game.arena.bounds == Rect2(0, 0, 1280, 800), "Campaign also uses entire map")
			game.open_run_details()
			for node in game.overlay.find_children("*", "Button", true, false):
				if node.get_meta("details_close", false): node.pressed.emit()
			check(game.current_mode == "campaign" and not paused, "Campaign detail close resumes correctly")
			game.show_menu()
	game.set_language("en")
	game.queue_free()
	await settle()
	paused = false
	print("OVERLAY HUD: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
