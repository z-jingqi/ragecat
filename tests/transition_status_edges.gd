extends SceneTree
## Real scene/actor/signal regressions. Automated physics is disabled whenever
## actors are manually advanced; deletion/transition checks use actual frames.
var game: Node
var checks := 0
var failures := 0
var late_rock_impacts := 0
var damage_events: Array[Dictionary] = []
var baseline_tree_nodes := 0
var baseline_nodes := 0
var baseline_orphans := 0

func _initialize() -> void:
	call_deferred("run")

func expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)

func near(actual: float, wanted: float, label: String) -> void:
	expect(absf(actual - wanted) < 0.0001, "%s (actual=%.6f expected=%.6f)" % [label, actual, wanted])

func find_button(node: Node, caption: String) -> Button:
	if node is Button and node.text == caption:
		return node as Button
	for child: Node in node.get_children():
		var found := find_button(child, caption)
		if found != null:
			return found
	return null

func press(caption: String) -> void:
	var control := find_button(game.ui, caption)
	expect(control != null, "Real Button exists: " + caption)
	if control != null:
		control.pressed.emit()

func escape() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.physical_keycode = KEY_ESCAPE
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	event = InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.physical_keycode = KEY_ESCAPE
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func disable_automatic(arena: RageArena) -> void:
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	arena.bow.enabled = false
	arena.player.movement_enabled = false

func settle(frames: int = 4) -> void:
	for _i in range(frames):
		await process_frame
		await physics_frame

func remember_subtree(node: Node, result: Array[WeakRef]) -> void:
	result.append(weakref(node))
	for child: Node in node.get_children():
		remember_subtree(child, result)

func remember_current_run() -> Array[WeakRef]:
	var result: Array[WeakRef] = []
	remember_subtree(game.arena, result)
	for child: Node in game.ui.get_children():
		remember_subtree(child, result)
	return result

func expect_freed(retired: Array[WeakRef], label: String) -> void:
	var surviving := 0
	for ref: WeakRef in retired:
		if ref.get_ref() != null:
			surviving += 1
	expect(surviving == 0, "%s: all %d retired nodes freed, survivors=%d" % [label, retired.size(), surviving])

func expect_menu_baseline(label: String) -> void:
	var tree_nodes := get_node_count()
	var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	expect(game.current_mode == "menu" and game.arena == null and not paused, label + ": menu owns no arena and is unpaused")
	expect(tree_nodes == baseline_tree_nodes, "%s: tree nodes=%d baseline=%d" % [label, tree_nodes, baseline_tree_nodes])
	expect(nodes <= baseline_nodes + 2, "%s: total nodes=%d baseline=%d" % [label, nodes, baseline_nodes])
	expect(orphans <= baseline_orphans, "%s: orphan nodes=%d baseline=%d" % [label, orphans, baseline_orphans])
	print("MENU BASELINE %s: tree=%d nodes=%d orphans=%d" % [label, tree_nodes, nodes, orphans])

func on_rock_impact(_center: Vector2, _radius: float) -> void:
	late_rock_impacts += 1

func prepare_pending_rocks() -> Mountainbreaker:
	press("Rocks")
	press(GameLocale.text("NAME_MOUNTAINBREAKER"))
	press(GameLocale.text("LAB_SPAWN_BOSS"))
	var arena: RageArena = game.arena
	var ai_control := find_button(game.ui, "Enemy AI") as CheckButton
	expect(ai_control != null, "Actual Enemy AI toggle exists")
	if ai_control != null:
		ai_control.button_pressed = true
	var boss := arena.enemies.get_child(0) as Mountainbreaker
	expect(boss.ai_enabled and boss.ability_mode == "rocks", "UI selects live rock-pattern boss")
	boss._physics_process(0.81)
	expect(boss.state == "rocks" and boss.rocks.size() == boss.rock_count, "Real boss state machine creates configured warning count")
	for rock: RockWarning in boss.rocks:
		rock.elapsed = rock.warning_duration - 0.02
		rock.impact.connect(on_rock_impact)
	return boss

func pending_rock_transitions() -> void:
	for transition: String in ["death", "reset"]:
		press("PRACTICE LAB")
		var old_arena: RageArena = game.arena
		disable_automatic(old_arena)
		var boss := prepare_pending_rocks()
		var first_warning := boss.rocks[0]
		var elapsed_before := first_warning.elapsed
		var impacts_before := late_rock_impacts
		old_arena.player.invulnerable = false
		old_arena.process_mode = Node.PROCESS_MODE_PAUSABLE
		if transition == "death":
			old_arena.player.receive_hit(old_arena.stats.max_hp * 2.0)
			expect(game.current_mode != "dead" and old_arena.finished, "Practice death schedules restart without terminal UI")
			await settle(4)
			if is_instance_valid(first_warning):
				near(first_warning.elapsed, elapsed_before, "Lethal practice hit cancels imminent warning clock")
			else:
				expect(true, "Death cancels owned imminent warning")
			expect(late_rock_impacts == impacts_before, "No pending rock impacts across automatic practice reset")
		var retired := remember_current_run()
		press("Reset lab")
		expect(not old_arena.is_inside_tree() and old_arena.is_queued_for_deletion(), transition + ": outgoing arena detached and queued inside UI callback")
		var fresh_arena: RageArena = game.arena
		fresh_arena.bow.enabled = false
		fresh_arena.player.movement_enabled = false
		fresh_arena.player.invulnerable = false
		var hp_before := fresh_arena.stats.hp
		await settle(6)
		expect_freed(retired, transition + " / restart")
		expect(late_rock_impacts == impacts_before, transition + ": retired warning never emits late impact")
		near(fresh_arena.stats.hp, hp_before, transition + ": vulnerable new-run player takes no stale rock damage")
		expect(fresh_arena.enemies.get_child_count() == 0 and not fresh_arena.finished, transition + ": new run has no retired boss or finished state")
		if game.practice_panel_open: game.return_from_practice_navigation()
		escape()
		press("MAIN MENU")
		await settle()
		expect_menu_baseline(transition + " cleanup")

func repeated_menu_transitions() -> void:
	for cycle in range(3):
		for phase: String in ["charge", "rocks", "upgrade", "pause"]:
			press("Start Run" if phase == "upgrade" else "PRACTICE LAB")
			var arena: RageArena = game.arena
			disable_automatic(arena)
			if phase == "charge":
				press("Charge")
				press(GameLocale.text("NAME_MOUNTAINBREAKER"))
				press(GameLocale.text("LAB_SPAWN_BOSS"))
				var toggle := find_button(game.ui, "Enemy AI") as CheckButton
				toggle.button_pressed = true
				var boss := arena.enemies.get_child(0) as Mountainbreaker
				boss._physics_process(0.81)
				boss._physics_process(boss.warning_duration + 0.01)
				expect(boss.state == "charge" and boss.charge_active, "Menu sequence enters committed real boss charge")
			elif phase == "rocks":
				prepare_pending_rocks()
			elif phase == "upgrade":
				arena.pickups.append(arena.player.position)
				arena.xp = arena.xp_needed - 1
				arena._physics_process(0.01)
				expect(game.current_mode == "upgrade" and paused, "Pickup callback opens actual upgrade overlay")
				var upgrade_overlay: WeakRef = weakref(game.overlay)
				escape()
				expect(game.current_mode == "upgrade", "ESC cannot skip a pending upgrade selection")
				var picked := false
				for control: Node in game.overlay.get_node("ModalScroll/ModalContent").get_children():
					if control is Button:
						control.pressed.emit()
						picked = true
						break
				expect(picked and game.current_mode == "campaign" and not paused, "Actual upgrade Button.pressed resumes endless mode")
				await settle()
				expect(upgrade_overlay.get_ref() == null, "Selected upgrade overlay is freed after real frames")
			if game.practice_panel_open: game.return_from_practice_navigation()
			escape()
			expect(game.current_mode == "pause" and paused, "ESC enters pause before menu transition")
			var retired := remember_current_run()
			press("MAIN MENU")
			await settle()
			expect_freed(retired, "cycle %d %s" % [cycle + 1, phase])
			expect_menu_baseline("cycle %d %s" % [cycle + 1, phase])

func seed_for_roll(minimum: float, maximum: float) -> int:
	var probe := RandomNumberGenerator.new()
	for candidate in range(1, 10000):
		probe.seed = candidate
		var roll := probe.randf()
		if roll > minimum and roll < maximum:
			return candidate
	expect(false, "Deterministic roll search finds requested interval")
	return 1

func fire_real_arrow(arena: RageArena, target: EnemyActor, seed_value: int, critical: bool, label: String) -> void:
	arena.rng.seed = seed_value
	var projectile := preload("res://scenes/projectiles/bow_arrow.tscn").instantiate() as BowArrow
	projectile.position = target.position - Vector2(80, 0)
	projectile.direction = Vector2.RIGHT
	projectile.speed = 500.0
	projectile.max_range = 300.0
	projectile.arena_bounds = arena.bounds
	projectile.enemies = arena.enemies
	projectile.enemy_hit.connect(arena._on_arrow_hit)
	arena.arrows.add_child(projectile)
	var before := target.health
	var events_before := damage_events.size()
	var hits_before := arena.hits
	var crits_before := arena.crits
	projectile._physics_process(0.2)
	var wanted := arena.stats.arrow_damage * (arena.stats.crit_multiplier if critical else 1.0)
	near(before - target.health, wanted, label + ": real arrow damage uses current shield count")
	expect(damage_events.size() == events_before + 1 and bool(damage_events.back().critical) == critical, label + ": damage signal critical flag matches remaining shields")
	expect(arena.hits == hits_before + 1 and arena.crits == crits_before + (1 if critical else 0), label + ": direct counters increment exactly once")
	expect(projectile.hit_ids.size() == 1 and projectile.is_queued_for_deletion(), label + ": one real projectile collision occurred")

func shield_status_interleaving() -> void:
	press("PRACTICE LAB")
	var arena: RageArena = game.arena
	disable_automatic(arena)
	arena.apply_ranks({"shield": 3})
	arena.stats.crit_chance = 0.0
	arena.stats.hp = 30.0
	arena.player.invulnerable = false
	press("Refill shield")
	var target := arena.spawn_enemy("dummy", Vector2(400, 400))
	var neighbor := arena.spawn_enemy("dummy", Vector2(440, 400))
	var chained := arena.spawn_enemy("dummy", Vector2(480, 400))
	target.damaged.connect(func(amount: float, critical: bool, _at: Vector2) -> void:
		damage_events.append({"amount": amount, "critical": critical})
	)
	# Each roll lies between the current and next depleted shield bonus (3pp each).
	var rolls: Array[int] = [seed_for_roll(0.07, 0.08), seed_for_roll(0.04, 0.05), seed_for_roll(0.01, 0.02)]
	for remaining in [3, 2, 1]:
		var seed_value := rolls[3 - remaining]
		fire_real_arrow(arena, target, seed_value, true, "%d shields before block" % remaining)
		var hp_before := arena.stats.hp
		arena.player.receive_hit(25.0)
		expect(arena.stats.shields == remaining - 1, "Real Archer hit consumes exactly one live shield")
		near(arena.stats.hp, hp_before, "Consumed shield absorbs whole hit")
		fire_real_arrow(arena, target, seed_value, false, "%d shields after block" % (remaining - 1))
		arena.player._physics_process(0.5)
	press("Refill shield")
	expect(arena.stats.shields == 3, "Actual refill button restores remaining shields without rebuilding actors")
	fire_real_arrow(arena, target, rolls[0], true, "Three shields restored by UI")
	arena.player._physics_process(3.0)
	var hp_before := arena.stats.hp
	var total_before := arena.total_damage
	target.status.apply_ice(load("res://resources/elements/ice.tres") as ElementSkillDefinition, 1)
	target._physics_process(0.5)
	near(arena.total_damage, total_before, "Status ticking never generates damage or proc")
	near(arena.stats.hp, hp_before, "Status ticking never heals player")
	if game.practice_panel_open: game.return_from_practice_navigation()
	escape()
	var retired := remember_current_run()
	press("MAIN MENU")
	await settle()
	expect_freed(retired, "shield and status cleanup")
	expect_menu_baseline("shield and status cleanup")

func run() -> void:
	game = preload("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	# Caption-based fixture has an explicit locale, independent of prior saved settings.
	TranslationServer.set_locale("en")
	GameLocale.refresh_tree(game)
	await settle()
	baseline_tree_nodes = get_node_count()
	baseline_nodes = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	baseline_orphans = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	print("INITIAL MENU BASELINE: tree=%d nodes=%d orphans=%d" % [baseline_tree_nodes, baseline_nodes, baseline_orphans])
	await pending_rock_transitions()
	await repeated_menu_transitions()
	await shield_status_interleaving()
	game.queue_free()
	await settle()
	print("TRANSITION STATUS EDGES: %d checks, %d failures" % [checks, failures])
	await preload("res://tests/audio_teardown.gd").drain(self)
	quit(1 if failures > 0 else 0)
