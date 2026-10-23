extends SceneTree
## Actual practice combat rendered at a chosen time. No survival/balance claim.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Boss combat rendering requires a display")
		quit(1)
		return
	var identity := "wildfire"
	var skill := "skyfire"
	var seconds := 1.35
	var output := ""
	var edge := false
	for argument in OS.get_cmdline_user_args():
		if argument == "--edge": edge = true
		elif argument.begins_with("--boss="): identity = argument.trim_prefix("--boss=")
		elif argument.begins_with("--skill="): skill = argument.trim_prefix("--skill=")
		elif argument.begins_with("--time="): seconds = float(argument.trim_prefix("--time="))
		elif argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.start_run(true)
	var arena: RageArena = game.arena
	if edge: arena.player.position = arena.bounds.position + Vector2(30,30)
	arena.bow.enabled = false
	arena.player.invulnerable = true
	arena.set_enemy_ai(true)
	arena.practice_boss_identity = identity
	var boss := arena.spawn_enemy("boss", arena.player.position + Vector2(-220,0)) as BossActor
	if boss == null:
		push_error("Could not create selected boss")
		quit(1)
		return
	# Observe the real phase signal/audio routing before forcing fixture ability.
	boss._forced_phase = 0
	boss.receive_damage(boss.max_health * 0.55)
	boss.update_phase_at_boundary()
	print("Phase roar callback observed: ", arena.feedback.event_counts.get("boss_roar", 0) == 1)
	boss.force_phase_for_practice(2)
	if boss is Wildfire:
		if skill == "rings": boss._start_rings()
		else:
			boss.skyfires_remaining = boss.boss_definition.skyfire_count
			boss._next_skyfire()
	elif boss is Beastcaller:
		if skill == "projectile": boss._start_projectile()
		else: boss._start_summon()
	await create_timer(seconds).timeout
	await process_frame
	await RenderingServer.frame_post_draw
	print("BOSS RENDER READY: %s / %s / %.2fs / phase %d / enemies %d / bullets %d" % [identity,skill,seconds,boss.phase_number,arena.enemies.get_child_count(),arena.enemy_bullets.get_child_count()])
	if not output.is_empty():
		var error := root.get_texture().get_image().save_png(output)
		if error != OK: push_error(error_string(error))
		await preload("res://tests/audio_teardown.gd").drain(self)
		game.queue_free()
		await process_frame
		await process_frame
		quit(0 if error == OK else 1)
