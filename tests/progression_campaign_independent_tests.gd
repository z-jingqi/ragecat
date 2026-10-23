extends SceneTree
## Independent black-box progression, persistence, modal, and raw-input contracts.
## The profile paths are always under /tmp, never a player's user directory.
var checks := 0
var failures := 0
var work := "/tmp/ragecat_independent_%s" % Time.get_ticks_usec()
var notifications: Array[String] = []

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("INDEPENDENT PROGRESSION: " + label)
func profile(suffix: String) -> AchievementProfile:
	var result := AchievementProfile.new()
	result.save_path = work + "/" + suffix + ".json"
	result.load_profile()
	return result
func write_json(path: String, data: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
func offers(game: Node) -> Array[String]:
	var result: Array[String] = []
	for node in game.overlay.find_children("*", "Button", true, false):
		if node.has_meta("upgrade_key"): result.append(str(node.get_meta("upgrade_key")))
	return result
func press_pad(button_index: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 7
	event.button_index = button_index
	event.pressed = true
	root.push_input(event)
	event.pressed = false
	root.push_input(event)
func kill_boss(arena: RageArena) -> BossActor:
	arena.director.boss_alive = true
	var boss := arena.spawn_enemy("boss", Vector2(1100, 700)) as BossActor
	boss.receive_damage(boss.max_health * 2.0)
	return boss

func persistence_contracts() -> void:
	var p := profile("normal")
	check(p.metrics == {"kills":0,"survival":0,"bosses":0} and p.completed.is_empty(), "missing legacy history starts at zero")
	p.unlocked.connect(func(key: String) -> void: notifications.append(key))
	p.begin_run(false)
	for i in range(20): p.record_kill(false)
	check(p.completed.has("first_flame") and p.is_unlocked("fire_enchant"), "natural kill threshold unlocks reward")
	check(FileAccess.file_exists(p.save_path), "achievement completion writes immediately")
	for i in range(5): p.record_kill(false)
	p.observe_time(75, 1)
	p.end_run()
	check(notifications.count("first_flame") == 1, "unlock notification is exactly once")
	var process_output: Array = []
	var process_exit := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/progression_campaign_independent_tests.gd", "--", "--verify-profile", p.save_path], process_output, true)
	check(process_exit == 0, "separate restarted engine process restores earned progress: " + str(process_output))
	var loaded := profile("normal")
	check(loaded.metrics.kills == 25 and loaded.metrics.survival == 75, "new profile instance restores cumulative kills and best time")
	loaded.begin_run(false)
	loaded.observe_time(12, 1)
	loaded.end_run()
	check(loaded.metrics.survival == 75, "new shorter run cannot lower best active time")
	var before := loaded.metrics.duplicate()
	loaded.begin_run(true)
	for i in range(50): loaded.record_kill(true)
	loaded.observe_time(100000, 100000)
	loaded.end_run()
	check(loaded.metrics == before, "practice produces zero achievement credit")
	loaded.begin_run(false)
	loaded.observe_time(NAN, 1)
	loaded.observe_time(INF, 1)
	loaded.observe_time(-999, 1)
	check(loaded.metrics == before, "invalid/negative time cannot alter earned best")
	loaded.end_run()
	check(loaded.flush() == OK and loaded.flush() == OK, "repeated exit flush is idempotent")
	var backup := profile("backup")
	backup.begin_run(false)
	for i in range(20): backup.record_kill(false)
	for i in range(5): backup.record_kill(false)
	backup.end_run()
	var file := FileAccess.open(backup.save_path, FileAccess.WRITE)
	file.store_string('{"version":1,"metrics":')
	file.close()
	var recovered := profile("backup")
	check(recovered.metrics.kills == 20 and recovered.completed.has("first_flame"), "truncated primary recovers previous valid backup")
	write_json(work + "/future.json", {"version": 999, "metrics":{"kills":999,"survival":999,"bosses":999},"completed":[]})
	var future := profile("future")
	var original := FileAccess.get_file_as_string(future.save_path)
	future.begin_run(false)
	future.record_kill(false)
	future.end_run()
	check(future.completed.is_empty() and FileAccess.get_file_as_string(future.save_path) == original, "future schema is not arbitrarily granted or overwritten")
	write_json(work + "/unknown.json", {"version":1,"metrics":{"kills":0,"survival":0,"bosses":0},"completed":["unknown_achievement"]})
	check(profile("unknown").completed.is_empty(), "unknown achievement identifiers confer nothing")
	write_json(work + "/invalid.json", {"version":1,"metrics":{"kills":-1,"survival":0,"bosses":0},"completed":["first_flame"]})
	check(profile("invalid").completed.is_empty(), "invalid counters cannot grant rewards")
	var invalid_definition := ProgressionDefinition.new()
	invalid_definition.save_interval = NAN
	invalid_definition.notification_duration = INF
	invalid_definition.rows_per_page = -1
	var bad_achievement := AchievementDefinition.new()
	bad_achievement.achievement_id = "bad"
	bad_achievement.metric = "unknown"
	bad_achievement.target = -1
	invalid_definition.achievements.append(bad_achievement)
	var valid_definition := invalid_definition.validated_copy()
	check(is_finite(valid_definition.save_interval) and is_finite(valid_definition.notification_duration) and valid_definition.rows_per_page > 0 and valid_definition.achievements.is_empty(), "invalid progression resource fields sanitize without arbitrary grants")
	var catalog := UpgradeCatalog.new()
	catalog.progression = null
	check(catalog.eligible({}).size() >= 3 and not catalog.eligible({}).has("fire_enchant"), "missing profile fails closed to playable starter pool")
	catalog.progression = profile("fresh")
	var ranks := catalog.apply_choice({}, "fire_enchant")
	check(not ranks.has("element_type"), "locked upgrade cannot be selected outside offer UI")
	var family := profile("family")
	family.begin_run(false)
	for i in range(60): family.record_kill(false)
	catalog.progression = family
	ranks = catalog.apply_choice({}, "fire_enchant")
	ranks = catalog.apply_choice(ranks, "fire_bow")
	check(family.is_unlocked("fire_bow") and family.is_unlocked("lightning_bow") and family.is_unlocked("ice_bow") and family.is_unlocked("dark_bow"), "shared exclusive-rank family unlocks coherently together")
	check(not catalog.eligible(ranks).has("lightning_enchant") and catalog.apply_choice(ranks, "lightning_enchant") == ranks, "family unlock cannot bypass separately locked enchantment")
	for i in range(60): family.record_kill(false)
	var switched := catalog.apply_choice(ranks, "lightning_enchant")
	check(switched.element_type == "lightning" and switched.element_skill_rank == 1 and family.is_unlocked("lightning_bow"), "later element switch inherits exclusive rank only into unlocked shared family")
	family.end_run()

func ui_campaign_contracts() -> void:
	var game := load("res://scenes/main.tscn").instantiate() as Node
	game.progression = profile("game")
	root.add_child(game)
	await process_frame
	await process_frame
	game.start_run(false)
	game.arena.process_mode = Node.PROCESS_MODE_DISABLED
	var arena: RageArena = game.arena
	game.show_upgrades()
	await process_frame
	var old_offers := offers(game)
	check(old_offers.size() == 3 and old_offers[0] != old_offers[1] and old_offers[1] != old_offers[2] and old_offers[0] != old_offers[2], "fresh profile has three distinct playable offers")
	var old_ranks: Dictionary = arena.ranks.duplicate(true)
	for i in range(20): game.progression.record_kill(false)
	check(arena.ranks == old_ranks and offers(game) == old_offers, "unlock only expands future pool, never grants ability or rerolls open offers")
	var focus := root.gui_get_focus_owner()
	game.set_language("zh_CN")
	await process_frame
	check(offers(game) == old_offers and root.gui_get_focus_owner() == focus, "locale refresh preserves offer identities and focus")
	game.choose_upgrade(old_offers[0])
	var normal := arena.spawn_enemy("chaser", Vector2(1000,700))
	var prior := int(game.progression.metrics.kills)
	normal.receive_damage(normal.max_health * 2)
	arena._on_enemy_killed(normal)
	check(game.progression.metrics.kills == prior + 1, "duplicate corpse/death callback credits one unique kill")
	var victory_events := [0]
	arena.victory_reached.connect(func() -> void: victory_events[0] += 1)
	for i in range(2):
		kill_boss(arena)
		check(arena.run_phase == "campaign" and game.current_mode == "campaign", "boss %d does not end campaign" % (i+1))
	arena.xp = arena.xp_needed * 3
	var hp := arena.stats.hp
	var shields := arena.stats.shields
	var xp := arena.xp
	var elapsed := arena.director.elapsed
	var third := kill_boss(arena)
	check(victory_events[0] == 1 and game.current_mode == "victory" and paused, "third boss opens exactly one paused victory modal")
	arena._on_enemy_killed(third)
	arena._physics_process(30)
	game.show_upgrades()
	check(victory_events[0] == 1 and arena.director.elapsed == elapsed and game.current_mode == "victory", "repeated death and queued level-up cannot replace victory or advance clock")
	await process_frame
	var endless_button: Button
	for node in game.overlay.find_children("*", "Button", true, false):
		if node.get_meta("action", "") == "endless_mode": endless_button = node
	check(endless_button != null and endless_button.text == "无尽模式", "victory uses exact Chinese Endless Mode caption")
	if endless_button != null:
		endless_button.grab_focus()
		game.set_language("en")
		await process_frame
		check(endless_button.text == "Endless Mode" and root.gui_get_focus_owner() == endless_button, "victory locale update preserves actionable focused button")
		press_pad(JOY_BUTTON_A)
		await process_frame
	check(arena.run_phase == "endless" and game.current_mode == "endless" and not paused, "raw controller Confirm enters endless")
	check(arena.stats.hp == hp and arena.stats.shields == shields and arena.xp == xp and arena.director.elapsed == elapsed, "continuing preserves health shields queued XP and clock")
	check(is_equal_approx(arena.director.next_boss_at - elapsed, 120), "next boss scheduled 120 active seconds after defeat")
	arena._physics_process(0.01)
	check(game.current_mode == "upgrade" and arena.xp > 0, "queued multiple-level XP remains available after victory decision")
	game.choose_upgrade(offers(game)[0])
	kill_boss(arena)
	check(victory_events[0] == 1 and arena.run_phase == "endless", "later endless boss does not repeat campaign victory")
	game.show_pause()
	game.open_achievements()
	await process_frame
	check(game.current_mode == "achievements" and paused and root.gui_get_focus_owner() != null, "achievement screen supports focus without hover")
	var rows := 0
	for node in game.overlay.find_children("*", "Button", true, false):
		if node.has_meta("achievement_id"):
			rows += 1
			check(not node.text.contains("ACH_") and node.text.contains("/"), "achievement row has translated condition progress")
	check(rows > 0, "achievement progress rows are visible")
	focus = root.gui_get_focus_owner()
	game.set_language("zh_CN")
	await process_frame
	check(root.gui_get_focus_owner() == focus, "achievement locale update preserves row focus")
	for node in game.overlay.find_children("*", "Button", true, false):
		if node.has_meta("achievement_id"):
			check(node.text.contains("解锁：") and (node.text.contains("已完成") or node.text.contains("未解锁")), "achievement locale update translates current reward/state rows in place")
	press_pad(JOY_BUTTON_B)
	await process_frame
	check(game.current_mode == "pause", "raw controller Back restores prior pause screen")
	game.start_run(true)
	game.arena.process_mode = Node.PROCESS_MODE_DISABLED
	var snapshot: Dictionary = game.progression.metrics.duplicate()
	for i in range(3): kill_boss(game.arena)
	check(game.progression.metrics == snapshot and game.current_mode == "practice" and not paused, "practice bosses neither win nor unlock")
	check(game.arena.stats.catalog.all_unlocked, "practice catalog explicitly grants full access")
	game.show_menu()
	game.start_run(false)
	game.arena.process_mode = Node.PROCESS_MODE_DISABLED
	check(game.arena.director.boss_count == 0 and game.progression.completed.has("first_flame"), "restart resets campaign but retains permanent unlocks")
	# Resolve a reentrant player death inside the lethal damage event, before killed emits.
	var terminal_arena: RageArena = game.arena
	terminal_arena.director.boss_count = 2
	terminal_arena.director.boss_alive = true
	var terminal_boss := terminal_arena.spawn_enemy("boss", Vector2(1100,700))
	var post_death_target := terminal_arena.spawn_enemy("chaser", Vector2(900,700))
	var next_frame_target := terminal_arena.spawn_enemy("chaser", Vector2(800,700))
	next_frame_target.health = 0.0 # Deliberately delayed killed callback to test sealing.
	var terminal_kills := int(game.progression.metrics.kills)
	var terminal_bosses := int(game.progression.metrics.bosses)
	terminal_boss.damaged.connect(func(_amount: float, _critical: bool, _at: Vector2) -> void: terminal_arena._on_death())
	terminal_boss.receive_damage(terminal_boss.max_health * 2)
	check(game.current_mode == "dead" and terminal_arena.finished, "same-turn player death has stable terminal modal priority")
	check(game.progression.metrics.kills == terminal_kills + 1 and game.progression.metrics.bosses == mini(terminal_bosses + 1, game.progression.definition.metric_cap("bosses")), "same-turn terminal boss death still retains earned achievement credit")
	var credited := int(game.progression.metrics.kills)
	terminal_arena._on_enemy_killed(post_death_target)
	post_death_target.receive_damage(post_death_target.max_health * 2)
	check(game.progression.metrics.kills == credited, "arbitrary callback and new lethal damage after player death cannot earn credit")
	await process_frame
	next_frame_target.is_dead = true
	terminal_arena._on_enemy_killed(next_frame_target)
	check(game.progression.metrics.kills == credited, "next-frame late callback cannot extend terminal reward window")
	game.start_run(false)
	game.arena.process_mode = Node.PROCESS_MODE_DISABLED
	var retiring: RageArena = game.arena
	var reentrant := retiring.spawn_enemy("chaser", Vector2(1000,700))
	reentrant.damaged.connect(func(_amount: float, _critical: bool, _at: Vector2) -> void: retiring._on_death())
	reentrant.receive_damage(reentrant.max_health * 2)
	game.start_run(false) # Begin replacement before old deferred finalization runs.
	game.arena.process_mode = Node.PROCESS_MODE_DISABLED
	await process_frame
	credited = int(game.progression.metrics.kills)
	var replacement := game.arena.spawn_enemy("chaser", Vector2(1000,700)) as EnemyActor
	replacement.receive_damage(replacement.max_health * 2)
	check(game.progression.metrics.kills == credited + 1, "retired terminal arena cannot deactivate replacement run's shared profile")
	game.queue_free()
	paused = false
	await process_frame
	await preload("res://tests/audio_teardown.gd").drain(self)

func run() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() == 2 and arguments[0] == "--verify-profile":
		var restarted := AchievementProfile.new()
		restarted.save_path = arguments[1]
		restarted.load_profile()
		quit(0 if restarted.metrics.kills == 25 and restarted.metrics.survival == 75 and restarted.completed.has("first_flame") else 1)
		return
	DirAccess.make_dir_recursive_absolute(work)
	persistence_contracts()
	await ui_campaign_contracts()
	print("%s: %d independent progression/campaign contracts" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)
