extends SceneTree
## Production-node regression of distance-keeping, health palette and live lab workflow.
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var prefs := DisplaySettings.new()
	prefs.sound_enabled = false
	prefs.save_settings()
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_run(true)
	game.arena.set_sound_enabled(false)
	game.arena.bow.enabled = false
	check(game.lab.visible and game.current_mode == "practice_ui", "Practice opens directly with controls expanded")
	check(not paused and game.arena.player.movement_enabled, "Live panel allows gameplay movement")
	check(game.combat_hud.practice_button.visible, "Practice toggle is directly available without pause menu")
	check(game.lab.find_child("CollapsePractice", true, false) != null, "Panel has a fixed collapse button outside scroll")
	game.practice_command("preset_fire")
	check(game.arena.stats.active_element == "fire", "Preset applies immediately while panel is open")
	game.practice_command("spawn_ranged")
	check(game.arena.enemies.get_child_count() == 1, "Spawn command applies immediately")
	game.practice_option("enemy_ai", true)
	var enemy: EnemyActor = game.arena.enemies.get_child(0)
	check(enemy.ai_enabled, "AI option applies without closing any modal")
	var age := enemy.age
	enemy._physics_process(0.1)
	check(enemy.age > age, "Open lab does not freeze enemy simulation")
	Input.action_press("dash")
	game.arena.player._physics_process(0.01)
	check(game.arena.player.dash_cooldown > 0.0, "Panel leaves dedicated dash action available")
	Input.action_release("dash")
	game.combat_hud.practice_button.pressed.emit()
	check(not game.lab.visible and game.current_mode == "practice" and not paused, "HUD toggle collapses directly into play")
	check(game.arena.player.movement_enabled, "Collapse restores movement input")
	game.combat_hud.practice_button.pressed.emit()
	check(game.lab.visible and not paused, "HUD toggle expands directly without pause overlay")
	game.practice_option("time_scale", 0.0)
	check(paused, "Explicit simulation pause works while controls open")
	game.practice_option("time_scale", 0.25)
	check(not paused and Engine.time_scale == 0.25, "Slow simulation takes effect immediately")
	game.practice_option("time_scale", 1.0)
	game.show_pause()
	game.enter_practice_navigation()
	check(game.overlay == null and not paused, "Pause-to-controls does not leave a pause modal behind")
	game.return_from_practice_navigation()
	check(game.current_mode == "practice" and not paused, "Closing controls never reopens pause menu")
	game.enter_practice_navigation()
	game.open_run_details()
	check(paused and not game.lab.visible, "Details temporarily hide live panel and pause")
	game.close_run_details()
	check(game.lab.visible and game.current_mode == "practice_ui" and not paused, "Details restore live lab context")
	game.return_from_practice_navigation()
	game.arena.clear_enemies()
	game.arena.process_mode = Node.PROCESS_MODE_DISABLED
	game.arena.player.position = Vector2(200, 400)
	var ranged := game.arena.spawn_enemy("ranged", Vector2(1000, 400)) as Spitter
	check(ranged != null, "Spitter fixture spawned")
	if ranged != null:
		ranged.ai_enabled = true
		ranged._physics_process(0.1)
		check(ranged.position.x < 1000 and ranged.approaching, "Distant ranged approaches instead of idling forever")
		for i in range(100): ranged._physics_process(0.1)
		check(is_equal_approx(ranged.position.distance_to(game.arena.player.position), ranged.definition.approach_end), "Approach stops at configured distance without overshoot")
		var at := ranged.position
		for i in range(20): ranged._physics_process(0.1)
		check(ranged.position == at and not ranged.approaching and not ranged.retreating, "Comfort band holds without jitter")
		ranged.position = game.arena.player.position + Vector2(50, 0)
		ranged._physics_process(0.1)
		check(ranged.retreating and not ranged.approaching and ranged.position.x > 250, "Near target switches to retreat")
		for i in range(40): ranged._physics_process(0.1)
		check(is_equal_approx(ranged.position.distance_to(game.arena.player.position), ranged.definition.retreat_end), "Retreat still ends exactly at its threshold")
	var invalid := SpitterDefinition.new()
	invalid.retreat_end = 400
	invalid.approach_end = -10
	invalid.approach_start = -20
	var safe := invalid.validated_copy()
	check(safe.approach_start > safe.approach_end and safe.approach_end >= safe.retreat_end, "Distance bands validate in order")
	game.arena.clear_enemies()
	var summoner := game.arena.spawn_enemy("beastcaller", Vector2(1100, 400)) as Beastcaller
	summoner.ai_enabled = true
	summoner.state = "recovery"
	summoner.phase_time = 100.0
	summoner._physics_process(0.1)
	check(summoner.position.x < 1100 and summoner.approaching, "Ranged Boss also returns from excessive distance during recovery")
	summoner.state = "projectile"
	summoner.phase_time = 100.0
	var locked := summoner.position
	summoner._physics_process(0.1)
	check(summoner.position == locked, "Ranged Boss still stops movement for telegraphs")
	var palette := load("res://resources/settings/health_bars.tres") as HealthBarDefinition
	check(palette.fill_color.r > palette.fill_color.g and palette.fill_color.r > palette.fill_color.b, "Shared health palette is red")
	for kind in ["mob", "ranged", "swiftfang", "elite_hornling", "mountainbreaker", "beastcaller", "wildfire"]:
		game.arena.clear_enemies()
		var actor: EnemyActor = game.arena.spawn_enemy(kind, Vector2(600, 400))
		check(actor != null and actor.health_bar_definition.fill_color == palette.fill_color, "Health is not actor/element tint: " + kind)
	check((game.combat_hud.health_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color == palette.fill_color, "Player HP uses same red")
	check((game.combat_hud.boss_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color == palette.fill_color, "Fixed Boss HP uses same red")
	check((game.combat_hud.xp_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color != palette.fill_color, "XP retains separate meaning/color")
	game.start_run(true)
	check(game.lab.visible and not paused, "Practice restart resets to expanded live controls")
	game.lab.show_upgrade_details(str(game.lab._rank_controls.keys()[0]))
	check(is_instance_valid(game.lab._details_layer), "Upgrade details opened during live practice")
	game.arena.player.invulnerable = false
	game.arena.player.receive_hit(10000.0)
	await process_frame
	check(game.current_mode == "practice_ui" and not paused, "Lethal practice damage restarts without end menu")
	check(game.lab.visible and game.lab.navigation_active and game.lab._details_layer == null, "Respawn closes old details and restores live controls")
	game.start_run(true)
	check(game.lab.visible and game.lab.navigation_active and not paused, "Death restart restores fresh live controls")
	game.queue_free()
	paused = false
	Engine.time_scale = 1.0
	await process_frame
	await preload("res://tests/audio_teardown.gd").drain(self)
	print("PLAYTEST WORKFLOW: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
