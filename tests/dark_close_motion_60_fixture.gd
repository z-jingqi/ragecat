extends SceneTree
## Original-direction prototype, not a recreation of unseen reference footage.
## Exactly 120 separately rendered frames, fixed 60 Hz timeline, no interpolation.
## Controlled production nodes: camera tracks a scripted moving player; AI is held.
var output := "/tmp/dark-close-60"
var close_zoom := 2.3
var failures := 0
func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="): output = argument.trim_prefix("--capture-dir=")
		elif argument.begins_with("--zoom="): close_zoom = float(argument.trim_prefix("--zoom="))
	call_deferred("run")
func run() -> void:
	if DisplayServer.get_name() == "headless" or not output.begins_with("/tmp/"):
		push_error("Real rendering display and temporary output required")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_language("en")
	game.start_run(true, 72103)
	game.return_from_practice_navigation()
	game.window_settings.begin_preview(WindowSettingsController.WINDOWED, Vector2i(960, 600))
	while game.window_settings.apply_pending: await process_frame
	game.window_settings.confirm_preview()
	var arena: RageArena = game.arena
	arena.set_sound_enabled(false)
	arena.player.invulnerable = true
	arena.player.movement_enabled = false
	arena.clear_enemies()
	arena.apply_ranks({"dark_enchant": 3, "dark_bow": 3})
	arena.player.position = Vector2(350, 400)
	arena.follow_camera.set_magnification(close_zoom)
	var enemy = arena.spawn_enemy("mob", Vector2(520, 455))
	enemy.ai_enabled = false
	enemy.health = 100000
	enemy.max_health = 100000
	arena.bow.shoot()
	arena.bow.enabled = false
	var arrow: BowArrow = arena.bow.active_gravity_arrow
	arrow.direction = Vector2.RIGHT
	arrow.rotation = 0.0
	arrow.position = Vector2(430 - arena.stats.element_skill.gravity.tip_offset, 400)
	arrow.presentation_origin_offset = Vector2.ZERO
	var field: GravityField = arrow.gravity_field
	var rock := RockWarning.new()
	rock.radius = 34.0
	rock.warning_duration = 5.0
	rock.elapsed = 2.0
	rock.ai_enabled = false
	rock.arena_bounds = arena.bounds
	arena.effects.add_child(rock)
	rock.position = Vector2(495, 350)
	var charge := HazardWarningVisual.new()
	arena.effects.add_child(charge)
	charge.set_charge(Vector2(390, 490), Vector2(560, 490), 24.0, 0.55)
	paused = true
	var sampled_positions: Array = []
	for frame in range(120):
		if frame == 60:
			rock.hide()
			charge.hide()
		# Real arrow simulation uses two 120 Hz substeps per rendered frame.
		for substep in range(2):
			arena.player.position.x += arrow.speed / 120.0
			arrow._physics_process(1.0 / 120.0)
		arena.follow_camera.sync_now()
		field._sync_matter_surface()
		field.queue_redraw()
		game.update_hud()
		await process_frame
		await RenderingServer.frame_post_draw
		var result := root.get_texture().get_image().save_png(output.path_join("frame_%04d.png" % frame))
		if result != OK: failures += 1
		sampled_positions.append([field.age, field.global_position.x, arena.follow_camera.global_position.x])
	var evidence := {"frames":120, "fps":60, "duration":2.0, "physics_substeps_per_frame":2, "zoom":close_zoom, "first_half_warning_visible":true, "second_half_warning_visible":false, "samples":sampled_positions, "failures":failures, "note":"Controlled real production nodes with scripted player movement and held enemy AI. Original prototype; not a reproduction of verified Gungeon animation."}
	var file := FileAccess.open(output.path_join("capture.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence))
	print("DARK_CLOSE_NATIVE60 ", JSON.stringify(evidence))
	game.show_menu()
	game.queue_free()
	await process_frame
	await process_frame
	quit(1 if failures else 0)
