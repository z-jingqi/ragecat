extends SceneTree
## Deterministic production hazard compositions, not a natural-play screenshot.
var output := ""
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
	call_deferred("run")
func capture(game: Node, name: String) -> void:
	game.update_hud()
	for i in range(4): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name + ".png"))
func run() -> void:
	if DisplayServer.get_name() == "headless" or output.is_empty():
		push_error("Hazard screenshots require rendering and --capture-dir outside the repo")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_language("zh_CN")
	game.start_run(true, 717)
	game.window_settings.begin_preview(WindowSettingsController.WINDOWED, Vector2i(1280, 800))
	game.window_settings.confirm_preview()
	var arena: RageArena = game.arena
	arena.set_sound_enabled(false)
	arena.player.position = Vector2(100, 48)
	arena.player.movement_enabled = false
	arena.bow.process_mode = Node.PROCESS_MODE_DISABLED
	paused = true
	for at in [Vector2(36, 40), Vector2(260, 42), Vector2(1215, 60), Vector2(350, 160), Vector2(600, 160), Vector2(900, 750)]:
		arena.spawn_enemy("mob", at)
	var boss := arena.spawn_enemy("mountainbreaker", Vector2(850, 72)) as Mountainbreaker
	boss.force_phase_for_practice(2)
	boss._start_charge_warning()
	boss.queue_redraw()
	await capture(game, "edge_charge")
	boss.reset_state()
	boss._spawn_tracking_rock()
	await capture(game, "edge_rocks")
	arena.clear_enemies()
	var summoner := arena.spawn_enemy("beastcaller", Vector2(930, 90)) as Beastcaller
	summoner.force_phase_for_practice(2)
	summoner._start_summon()
	summoner.queue_redraw()
	await capture(game, "edge_summon")
	arena.clear_enemies()
	var fire := arena.spawn_enemy("wildfire", Vector2(760, 100)) as Wildfire
	fire.force_phase_for_practice(2)
	var hazard := fire._create_skyfire(arena.player.position, false)
	hazard.elapsed = hazard.warning * 0.6
	hazard.queue_redraw()
	await capture(game, "edge_skyfire_warning")
	hazard._physics_process(hazard.warning * 0.5)
	await capture(game, "edge_skyfire_burning")
	fire._start_rings()
	fire._release_ring()
	for child in fire.get_children():
		if child is BossFireRing:
			child.ring_radius = 650
			child.queue_redraw()
	await capture(game, "edge_ring")
	game.show_menu()
	game.queue_free()
	await process_frame
	print("FULL PLAYFIELD HAZARD RENDER: 6 compositions")
	quit()
