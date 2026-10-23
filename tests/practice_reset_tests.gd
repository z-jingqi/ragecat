extends SceneTree
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_run(true)
	game.arena.set_sound_enabled(false)
	var arena: RageArena = game.arena
	arena.bow.enabled = false
	check(game.lab.visible and arena.player.movement_enabled, "Open lab permits movement")
	var position := arena.player.position
	Input.action_press("move_right")
	arena.player._physics_process(0.1)
	Input.action_release("move_right")
	check(arena.player.position.x > position.x, "Move works with open controls")
	Input.action_press("dash")
	arena.player._physics_process(0.01)
	Input.action_release("dash")
	check(arena.player.dash_cooldown > 0, "Dedicated dash works with open controls")
	for event in InputMap.action_get_events("ui_accept"):
		check(not(event is InputEventKey and (event.physical_keycode == KEY_SPACE or event.keycode == KEY_SPACE)), "Dash cannot also activate focused UI")
	await physics_frame
	await process_frame
	var rank: SpinBox = game.lab._rank_controls["damage"]
	var label: Control = rank.get_parent().get_child(0)
	label.grab_focus()
	var stick := InputEventJoypadMotion.new()
	stick.device = 0
	stick.axis = JOY_AXIS_LEFT_X
	stick.axis_value = 1.0
	var rank_before := rank.value
	var at := arena.player.position
	Input.parse_input_event(stick)
	await process_frame
	arena.player._physics_process(0.1)
	check(rank.value == rank_before and arena.player.position.x > at.x, "Left stick moves without editing focused upgrade")
	stick.axis_value = 0.0
	Input.parse_input_event(stick)
	await process_frame
	var dpad := InputEventJoypadButton.new()
	dpad.device = 0
	dpad.button_index = JOY_BUTTON_DPAD_RIGHT
	dpad.pressed = true
	at = arena.player.position
	Input.parse_input_event(dpad)
	await process_frame
	arena.player._physics_process(0.1)
	check(rank.value > rank_before and arena.player.position == at, "D-pad edits panel without moving player")
	dpad.pressed = false
	Input.parse_input_event(dpad)
	await process_frame
	game.practice_command("preset_fire")
	var ranks := arena.ranks.duplicate(true)
	game.practice_option("enemy_ai", true)
	game.practice_option("invulnerability", false)
	game.practice_option("boss_phase", 2)
	var completed: Array = game.progression.completed.duplicate(true)
	var metrics: Dictionary = game.progression.metrics.duplicate(true)
	var endings := [0, 0, 0]
	arena.run_ended.connect(func() -> void: endings[0] += 1)
	arena.victory_reached.connect(func() -> void: endings[1] += 1)
	arena.practice_restarted.connect(func() -> void: endings[2] += 1)
	game.lab.show_upgrade_details(str(game.lab._rank_controls.keys()[0]))
	for repeat in range(2):
		arena.spawn_enemy("ranged", Vector2(800, 400))
		arena.player.dash_left = 0
		arena.player.health_state.invulnerability = 0
		arena.stats.shields = 0
		arena.player.receive_hit(100000)
		arena.player.receive_hit(100000)
		check(arena.finished and arena._practice_restart_pending, "Lethal callback schedules safe single restart")
		check(game.current_mode != "dead" and not paused, "No death/end menu in lethal frame")
		await process_frame
		check(endings[2] == repeat + 1, "Repeated lethal callbacks reset only once")
		check(arena.stats.hp == arena.stats.max_hp and not arena.finished, "Restart is alive at full health")
		check(arena.enemies.get_child_count() == 0 and arena.arrows.get_child_count() == 0 and arena.enemy_bullets.get_child_count() == 0, "Restart clears hazards")
		check(arena.ranks == ranks and arena.lab_ai and arena.practice_boss_phase == 2 and not arena.player.invulnerable, "Restart keeps chosen build and practice options")
		check(arena.player.position == arena.bounds.get_center() and arena.player.dash_left == 0 and arena.player.dash_cooldown == 0, "Restart resets position and movement transients")
		check(game.current_mode == "practice_ui" and game.lab.visible and game.lab._details_layer == null, "Restart preserves open panel but dismisses stale details")
	check(endings[0] == 0 and endings[1] == 0, "Practice emits no terminal campaign signals")
	for i in range(3):
		var boss: EnemyActor = arena.spawn_enemy("boss", Vector2(800, 400))
		boss.is_dead = true
		boss.health = 0
		arena._on_enemy_killed(boss)
		arena.clear_enemies()
	check(endings[1] == 0 and not paused and arena.run_phase != "victory", "Three practice bosses never trigger campaign victory")
	check(game.progression.completed == completed and game.progression.metrics == metrics and game.unlock_queue.is_empty(), "Practice awards no achievement progress or toast")
	game.show_victory()
	game.show_death()
	check(game.current_mode == "practice_ui" and not paused, "UI defensive terminal handlers reject practice")
	game.return_from_practice_navigation()
	arena.stats.shields = 0
	arena.player.health_state.invulnerability = 0
	arena.player.receive_hit(100000)
	await process_frame
	check(not game.lab.visible and game.current_mode == "practice", "Closed panel stays closed on respawn")
	arena.stats.shields = 0
	arena.player.health_state.invulnerability = 0
	arena.player.receive_hit(100000)
	game.start_run(false)
	var campaign: RageArena = game.arena
	await process_frame
	check(game.arena == campaign and not campaign.practice and game.current_mode == "campaign", "Leaving cancels old deferred practice reset")
	campaign.player.receive_hit(100000)
	check(game.current_mode == "dead" and paused, "Campaign death still uses proper end menu")
	game.queue_free()
	paused = false
	Engine.time_scale = 1
	await process_frame
	await preload("res://tests/audio_teardown.gd").drain(self)
	print("PRACTICE RESET: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
