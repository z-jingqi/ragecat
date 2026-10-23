extends SceneTree
## Controlled real production nodes, Compatibility render; not natural gameplay.
var game: Node
var arena: RageArena
var output := "/tmp/impact-motion"
var frame_number := 0
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Visual capture requires a rendering display")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_language("en")
	game.start_run(true, 1901)
	game.return_from_practice_navigation()
	game.window_settings.begin_preview(WindowSettingsController.WINDOWED,Vector2i(960,600))
	game.window_settings.confirm_preview()
	arena = game.arena
	arena.clear_enemies()
	arena.set_sound_enabled(false)
	arena.bow.enabled = false
	arena.player.invulnerable = false
	arena.player.movement_enabled = false
	arena.player.position = Vector2(480,360)
	paused = true
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var label := Label.new()
	label.position = Vector2(24,100)
	label.add_theme_font_size_override("font_size",18)
	layer.add_child(label)
	for section in ["Shield break", "Monster smoke", "Boss smoke", "Dense deaths"]:
		arena.clear_enemies()
		label.text = section
		var targets: Array[EnemyActor] = []
		arena.stats.shields = 1 if section == "Shield break" else 0
		arena.player.health_state.invulnerability = 0
		if section == "Monster smoke":
			for i in range(4): targets.append(arena.spawn_enemy(["mob","ranged","swiftfang","elite_hornling"][i],Vector2(300+i*120,260)))
		elif section == "Boss smoke": targets.append(arena.spawn_enemy("mountainbreaker", Vector2(480,250)))
		elif section == "Dense deaths":
			for i in range(30): targets.append(arena.spawn_enemy("mob",Vector2(330+(i%6)*56,210+(i/6)*35)))
		for frame in range(48):
			if frame == 12:
				if section == "Shield break": arena.player.receive_hit(3)
				else:
					for enemy in targets: enemy.receive_damage(enemy.health+1)
			for visual in arena.feedback.visuals.get_children():
				if not visual.is_queued_for_deletion(): visual._process(1.0/24.0)
			for text in arena.effects.get_children():
				if text.has_method("_process"): text._process(1.0/24.0)
			arena.player._physics_process(1.0/24.0)
			arena.player.queue_redraw()
			game.update_hud()
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join("frame_%04d.png" % frame_number))
			frame_number += 1
	game.show_menu()
	game.queue_free()
	layer.queue_free()
	await process_frame
	await process_frame
	print("IMPACT MOTION: %d frames captured through actual production events" % frame_number)
	quit(0)
