extends SceneTree
## Engine-driven campaign/optional-Endless balance observations, not a human playtest.
## Starter/weak begin fresh. Element fixtures pre-unlock only milestones rewarding that
## element; mixed pre-unlocks all milestones. Fixtures do NOT grant any upgrade ranks.
## Synthetic completed flags with zero historical metrics intentionally isolate pools;
## never load these fixture save files as valid player-history evidence.
## The harness only seeds RNG, reads state, presses movement/dash actions, and emits
## pressed on offered upgrade Buttons. It never manually calls gameplay callbacks,
## changes HP/ranks/positions, grants invulnerability, or advances the director.

# Run: isolated HOME/XDG_* godot --headless --fixed-fps 60 --script tests/run_pacing_balance_bench.gd -- --policy=starter --seed=7319 --limit=1800 --out=/tmp/pacing.json
# Fixed FPS removes wall pacing, NOT physics steps: time_scale stays 1, physics 60 Hz.
# State-aware bot is not a human playtest. It knows live enemy/projectile/warning state,
# responsive steers at 10 Hz with no latency; lagged uses 4 Hz decisions +200ms
# simulation input latency. Neither is calibrated to human skill. Censored != dead.
# --objective=boss prioritizes boss proximity over XP during boss fights; default loot
# can under-utilize short-range/slow gravity builds. Record this when comparing builds.
# --choice-policy=emergency: HP<=35% picks heal/refill/vitality/shield/regen in that
# order when offered; otherwise identical fixed upgrade priorities. Not human-calibrated.
var limit_seconds := 1800.0
var output_path := "/tmp/run-pacing-balance.json"
var policy := "starter"
var controller := "responsive"
var objective := "loot"
var choice_policy := "fixed"
var victory_snapshot: Dictionary = {}
var pending_decision: Dictionary = {}
var cap_seconds := 0.0
var boss_fights: Array[Dictionary] = []
var selected_seed := 7319
const POLICIES := ["starter", "weak", "fire", "lightning", "ice", "dark", "mixed"]
const BASE_PRIORITY := ["regen", "damage_flat", "attack_speed", "pierce", "damage", "burst", "spread_arrow", "shield", "knockback", "move_speed", "crit_chance", "crit_damage", "split", "long_draw", "vitality", "pickup_radius"]
var snapshots: Array[Dictionary] = []
var damage_events: Array[Dictionary] = []
var unlocks: Array[Dictionary] = []
var campaign_complete_at := -1.0
var next_steer := 0.0
var damage_sources: Dictionary = {}
var initial_completed: Array[String] = []
var source_snapshot: Dictionary = {}
const ACTIONS := ["move_left", "move_right", "move_up", "move_down", "dash"]
var game: Node
var arena: RageArena
var active := false
var failed := false
var checks := 0
var observations := 0
var physics_observations := 0
var render_observations := 0
var strategy := ""
var run_seed := 0
var peaks: Dictionary = {}
var offers: Array[Dictionary] = []
var boss_spawn_times: Array[float] = []
var boss_ids: Dictionary = {}
var dash_requests := 0
var dash_activations := 0
var prior_dash := 0.0
var previous_direction := Vector2.RIGHT
var movement_distance := 0.0
var previous_position := Vector2.ZERO
var health_hits := 0
var shield_blocks := 0
var next_progress := 30.0
var results: Array[Dictionary] = []
var violation_keys: Dictionary = {}
var start_wall_usec := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		if not violation_keys.has(message):
			violation_keys[message] = true
			push_error("PACING BENCH FAIL: " + message)

func _release_input() -> void:
	for action: String in ACTIONS:
		if InputMap.has_action(action): Input.action_release(action)

func run() -> void:
	start_wall_usec = Time.get_ticks_usec()
	source_snapshot = _source_hashes()
	process_frame.connect(_observe_render)
	physics_frame.connect(_observe_physics)
	print("PACING BENCH: genuine engine physics; campaign then optional Endless; actual offered UI picks; survival is an observation, not a pass condition")
	print("METHOD: perfect-state automated steering, analog WASD and threat-triggered dash; no gameplay state grants; 30 simulation minutes or death (configurable); seeds cover global RNG and arena RNG")
	game = load("res://scenes/main.tscn").instantiate() as Node
	game.progression.save_path = "/tmp/pacing-unused-" + str(OS.get_process_id()) + ".json"
	root.add_child(game)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--choice-policy="): choice_policy = arg.trim_prefix("--choice-policy=")
		if arg.begins_with("--objective="): objective = arg.trim_prefix("--objective=")
		if arg.begins_with("--controller="): controller = arg.trim_prefix("--controller=")
		if arg.begins_with("--policy="): policy = arg.trim_prefix("--policy=")
		if arg.begins_with("--seed="): selected_seed = int(arg.trim_prefix("--seed="))
		if arg.begins_with("--limit="): limit_seconds = float(arg.trim_prefix("--limit="))
		if arg.begins_with("--out="): output_path = arg.trim_prefix("--out=")
	check(POLICIES.has(policy), "known policy")
	check(controller in ["responsive", "lagged"], "known controller")
	check(objective in ["loot", "boss"], "known objective")
	check(choice_policy in ["fixed", "emergency"], "known choice policy")
	if failed: quit(1); return
	await _run_one({"seed": selected_seed, "strategy": policy})
	var report := {"passed": not failed, "checks": checks, "method": "Engine callbacks only; metadata-selected offered upgrades; state-aware input steering; controller parameters recorded per run; no gameplay grants. Pre-unlocked synthetic profiles have listed completed achievement IDs, zero metrics, and naturally earn subsequent unlocks. Not human survival estimates.", "source_hashes": source_snapshot, "physics_hz": Engine.physics_ticks_per_second, "time_scale": Engine.time_scale, "cmdline": OS.get_cmdline_args(), "runs": results}
	var output := FileAccess.open(output_path, FileAccess.WRITE)
	if output != null: output.store_string(JSON.stringify(report, "\t"))
	else: check(false, "could not write output")
	print("PACING SUMMARY " + JSON.stringify(report))
	await preload("res://tests/audio_teardown.gd").drain(self)
	game.queue_free()
	arena = null
	await process_frame
	await process_frame
	quit(1 if failed else 0)

func _run_one(specification: Dictionary) -> void:
	_release_input()
	strategy = str(specification.strategy)
	run_seed = int(specification.seed)
	game.progression.end_run()
	game.progression = AchievementProfile.new()
	game.progression.save_path = output_path + ".profile.json"
	for item in game.progression.definition.achievements:
		var wanted := policy == "mixed"
		if policy in ["fire", "lightning", "ice", "dark"]:
			wanted = item.rewards.has(policy + "_enchant") or item.rewards.has(policy + "_bow")
		if wanted: game.progression.completed.append(item.achievement_id)
	initial_completed = game.progression.completed.duplicate()
	game.progression.unlocked.connect(func(key: String) -> void: unlocks.append({"time": arena.director.elapsed, "id": key}))
	seed(run_seed)
	game.start_run(false, run_seed)
	arena = game.arena
	peaks = {"enemies": 0, "arrows": 0, "pickups": 0, "effects": 0, "rocks": 0, "bullets": 0}
	offers = []
	boss_spawn_times = []
	boss_ids = {}
	observations = 0
	physics_observations = 0
	render_observations = 0
	dash_requests = 0
	dash_activations = 0
	prior_dash = 0.0
	movement_distance = 0.0
	previous_position = arena.player.position
	previous_direction = Vector2.RIGHT
	health_hits = 0
	shield_blocks = 0
	next_progress = 30.0
	arena.player.hit_feedback.connect(func(kind: String, _amount: float) -> void:
		_record_damage(kind, _amount)
		if kind == "block" or kind == "break": shield_blocks += 1
		else: health_hits += 1
	)
	arena.enemies.child_entered_tree.connect(_track_spawn)
	arena.arrows.child_entered_tree.connect(_track_node_peak.bind("arrows", arena.arrows))
	arena.effects.child_entered_tree.connect(_track_node_peak.bind("effects", arena.effects))
	active = true
	var wall_start := Time.get_ticks_usec()
	var engine_start := Engine.get_physics_frames()
	print("RUN START " + JSON.stringify({"strategy": strategy, "seed": run_seed, "hp": arena.stats.hp, "ranks": arena.ranks, "game_seconds": arena.director.elapsed}))
	check(not arena.practice and not arena.player.invulnerable, strategy + ": normal mode without invulnerability")
	check(arena.ranks.is_empty(), strategy + ": starts with no ranks")
	while not arena.finished and arena.director.elapsed < limit_seconds:
		if game.current_mode == "upgrade": _pick_upgrade()
		if game.current_mode == "victory": _continue_victory()
		if not paused and not arena.finished and arena.director.elapsed >= next_steer:
			_steer()
			next_steer = arena.director.elapsed + (0.25 if controller == "lagged" else 0.1)
		if not paused and not pending_decision.is_empty() and arena.director.elapsed >= float(pending_decision.at):
			_apply_decision(pending_decision.direction, pending_decision.dash)
			pending_decision.clear()
		await process_frame
		if Time.get_ticks_usec() - wall_start > 3600000000:
			check(false, strategy + ": real-time watchdog (3600 seconds) expired")
			break
	_observe()
	_release_input()
	active = false
	var terminal := "dead" if arena.finished else ("time_limit" if arena.director.elapsed >= limit_seconds else "watchdog")
	check(terminal != "watchdog", strategy + ": observed a natural terminal state or the defined time limit")
	check(int(peaks.enemies) <= 70, strategy + ": recorded enemy peak <= 70")
	check(int(peaks.pickups) <= 250, strategy + ": recorded pickup peak <= 250")
	check(terminal != "dead" or game.current_mode == "dead", strategy + ": death remains the terminal UI when observed")
	check(arena.director.elapsed > 0.0, strategy + ": genuine game clock advanced")
	check(movement_distance > 0.0, strategy + ": movement actions moved the player")
	check(not arena.player.invulnerable, strategy + ": invulnerability remains disabled")
	var result := {
		"strategy": strategy, "controller": controller, "controller_config": {"decision_seconds": 0.25 if controller == "lagged" else 0.1, "input_latency_seconds": 0.2 if controller == "lagged" else 0.0, "prediction_seconds": 0.35, "candidate_directions": 16}, "objective": objective, "choice_policy": choice_policy, "victory_snapshot": victory_snapshot, "cap_seconds": cap_seconds, "boss_fights": boss_fights, "seed": run_seed, "terminal": terminal, "ui_mode": game.current_mode,
		"game_seconds": arena.director.elapsed, "wall_seconds": (Time.get_ticks_usec() - wall_start) / 1000000.0,
		"engine_physics_frames": Engine.get_physics_frames() - engine_start,
		"physics_observations": physics_observations, "render_observations": render_observations,
		"hp": arena.stats.hp, "max_hp": arena.stats.max_hp, "shields": arena.stats.shields,
		"shield_capacity": arena.stats.shield_capacity, "level": arena.level,
		"xp": arena.xp, "xp_needed": arena.xp_needed, "ranks": arena.ranks.duplicate(),
		"kills": arena.kills, "bosses_defeated": arena.director.boss_count,
		"bosses_spawned": boss_ids.size(), "boss_spawn_times": boss_spawn_times.duplicate(),
		"hits": arena.hits, "crits": arena.crits, "element_procs": arena.element_procs.proc_counts.duplicate(),
		"damage_dealt": arena.total_damage, "healed_total": arena.player.healed_total,
		"health_hit_events": health_hits, "shield_block_events": shield_blocks,
		"dash_requests": dash_requests, "dash_activations": dash_activations,
		"movement_distance": movement_distance, "peaks": peaks.duplicate(), "offers": offers.duplicate(true), "snapshots": snapshots, "damage_events": damage_events,
		"damage_sources": damage_sources, "campaign_complete_at": campaign_complete_at, "first_pick_at": offers[0].game_seconds if not offers.is_empty() else -1.0,
		"censored": terminal == "time_limit", "initial_completed": initial_completed, "unlocks": unlocks,
	}
	results.append(result)
	print("RUN RESULT " + JSON.stringify(result))
	paused = false
	game.show_menu()
	await process_frame
	arena = null

func _track_spawn(node: Node) -> void:
	peaks.enemies = maxi(int(peaks.enemies), arena.enemies.get_child_count())
	if node is BossActor and not boss_ids.has(node.get_instance_id()):
		boss_ids[node.get_instance_id()] = true
		boss_spawn_times.append(arena.director.elapsed)
		var fight := {"spawn": arena.director.elapsed, "hp": node.health, "death": -1.0}
		boss_fights.append(fight)
		node.killed.connect(func(_enemy: EnemyActor) -> void: fight.death = arena.director.elapsed)
		print("BOSS SPAWN " + JSON.stringify({"strategy": strategy, "game_seconds": arena.director.elapsed, "hp": arena.stats.hp, "boss_hp": node.health}))

func _track_node_peak(_node: Node, key: String, container: Node) -> void:
	peaks[key] = maxi(int(peaks[key]), container.get_child_count())

func _observe_render() -> void:
	if active:
		render_observations += 1

func _observe_physics() -> void:
	if active:
		physics_observations += 1
		_observe(true)

func _observe(physics_sample: bool = false) -> void:
	if not active or not is_instance_valid(arena): return
	observations += 1
	var enemy_count := arena.enemies.get_child_count()
	if physics_sample and not paused and enemy_count >= arena.definition.enemy_limit: cap_seconds += 1.0 / Engine.physics_ticks_per_second
	var rock_count := 0
	for node: Node in arena.enemies.get_children():
		if node is BossActor:
			for child: Node in node.get_children():
				if child is RockWarning: rock_count += 1
	peaks.enemies = maxi(int(peaks.enemies), enemy_count)
	peaks.arrows = maxi(int(peaks.arrows), arena.arrows.get_child_count())
	peaks.pickups = maxi(int(peaks.pickups), arena.pickups.size())
	peaks.effects = maxi(int(peaks.effects), arena.effects.get_child_count())
	peaks.rocks = maxi(int(peaks.rocks), rock_count)
	peaks.bullets = maxi(int(peaks.bullets), arena.enemy_bullets.get_child_count())
	check(is_finite(arena.stats.hp) and arena.stats.hp >= 0.0 and arena.stats.hp <= arena.stats.max_hp + 0.001, strategy + ": HP remains within legitimate bounds")
	check(arena.stats.shields >= 0 and arena.stats.shields <= arena.stats.shield_capacity, strategy + ": shields remain within capacity")
	check(enemy_count <= 70, strategy + ": explicit enemy cap <= 70 every observed frame")
	check(arena.pickups.size() <= 250, strategy + ": explicit pickup cap <= 250 every observed frame")
	check(not arena.player.invulnerable, strategy + ": no invulnerability granted")
	movement_distance += previous_position.distance_to(arena.player.position)
	previous_position = arena.player.position
	if arena.player.dash_left > prior_dash + 0.01: dash_activations += 1
	prior_dash = arena.player.dash_left
	if arena.director.elapsed >= next_progress:
		print("RUN PROGRESS " + JSON.stringify({"strategy": strategy, "game_seconds": arena.director.elapsed, "hp": arena.stats.hp, "level": arena.level, "kills": arena.kills, "bosses": arena.director.boss_count, "peaks": peaks}))
		var ranged := 0
		var ranged_in_range := 0
		var alive := 0
		for node in arena.enemies.get_children():
			if not node.is_dead: alive += 1
			if node is RangedEnemy and not node.is_dead:
				ranged += 1
				if node.position.distance_to(arena.player.position) <= arena.ranged_definition.shoot_range: ranged_in_range += 1
		snapshots.append({"time": arena.director.elapsed, "hp": arena.stats.hp, "max_hp": arena.stats.max_hp, "shields": arena.stats.shields, "level": arena.level, "xp": arena.xp, "enemies": enemy_count, "ranged": ranged, "alive": alive, "ranged_in_range": ranged_in_range, "bullets": arena.enemy_bullets.get_child_count(), "kills": arena.kills, "bosses": arena.director.boss_count, "damage": arena.total_damage, "damage_sources": damage_sources.duplicate()})
		next_progress += 30.0

func _button_key(item: Button) -> String:
	return str(item.get_meta("upgrade_key", "continue"))

func _priority() -> Array:
	var order: Array = BASE_PRIORITY.duplicate()
	if policy in ["fire", "lightning", "ice", "dark"]:
		order.push_front(policy + "_bow")
		order.push_front(policy + "_enchant")
	elif policy == "mixed":
		order.push_front("lightning_bow")
		order.push_front("lightning_enchant")
	if policy == "weak": order.reverse()
	return order

func _continue_victory() -> void:
	_release_input()
	if campaign_complete_at < 0: campaign_complete_at = arena.director.elapsed
	for node in game.overlay.find_children("*", "Button", true, false):
		if str(node.get_meta("action", "")) == "endless_mode":
			victory_snapshot = {"time": arena.director.elapsed, "hp": arena.stats.hp, "max_hp": arena.stats.max_hp, "shields": arena.stats.shields, "ranks": arena.ranks.duplicate(), "level": arena.level, "regen": arena.stats.regen, "effective_crit": arena.stats.effective_crit_chance()}
			var hp := arena.stats.hp
			var ranks: Dictionary = arena.ranks.duplicate()
			var transition := {"arena_id": arena.get_instance_id(), "elapsed": arena.director.elapsed, "arrows": arena.arrows.get_child_count(), "bullets": arena.enemy_bullets.get_child_count(), "dash": arena.player.dash_cooldown, "level": arena.level, "xp": arena.xp}
			node.pressed.emit()
			check(arena.get_instance_id() == transition.arena_id and arena.director.elapsed == transition.elapsed, "Endless preserves arena and elapsed time")
			check(arena.arrows.get_child_count() == transition.arrows and arena.enemy_bullets.get_child_count() == transition.bullets, "Endless preserves projectiles")
			check(arena.player.dash_cooldown == transition.dash and arena.level == transition.level and arena.xp == transition.xp, "Endless preserves cooldown and experience")
			check(arena.stats.hp == hp and arena.ranks == ranks, "Endless preserves HP and build")
			return
	check(false, "victory has semantic endless button")

func _record_damage(kind: String, amount: float) -> void:
	var source := "unknown"
	for frame in get_stack():
		var path := str(frame.source)
		if path.ends_with("enemy_bullet.gd"): source = "projectile"; break
		if path.ends_with("rock_warning.gd"): source = "boss_rock"; break
		if path.ends_with("boss.gd"): source = "boss_charge"; break
		if path.ends_with("arena.gd"): source = "contact"; break
	damage_sources[source] = int(damage_sources.get(source, 0)) + 1
	damage_events.append({"time": arena.director.elapsed, "source": source, "kind": kind, "amount": amount, "hp": arena.stats.hp})

func _pick_upgrade() -> void:
	_release_input()
	var buttons: Array[Button] = []
	var option_keys: Array[String] = []
	var option_text: Array[String] = []
	for node: Node in game.overlay.get_node("ModalScroll/ModalContent").get_children():
		if node is Button:
			buttons.append(node)
			option_keys.append(_button_key(node))
			option_text.append(node.text)
	check(not buttons.is_empty(), strategy + ": upgrade UI has an actual offered button")
	if buttons.is_empty(): return
	var best := 0
	var best_score := -INF
	for i in range(buttons.size()):
		var key := option_keys[i]
		if key not in ["heal", "refill", "continue"]: check(game.progression.is_unlocked(key), "all offered upgrades unlocked")
		check(not key.is_empty(), strategy + ": offered UI card maps to a known upgrade")
		var order: Array = _priority()
		var score := float(order.size() - order.find(key)) if order.has(key) else -10.0
		if key == "heal": score = 100.0 if arena.stats.hp < arena.stats.max_hp * 0.55 else -2.0
		if key == "refill": score = 80.0 if arena.stats.hp < arena.stats.max_hp * 0.45 else (18.0 if strategy == "defense" else 0.0)
		if key.ends_with("_enchant") and not order.has(key): score = -100.0
		# Predeclared emergency variant: only offered choices, no changed steering.
		# At HP <=35%, heal > refill > vitality > shield > regen, then fixed order.
		if choice_policy == "emergency" and arena.stats.hp <= arena.stats.max_hp * 0.35:
			var emergency_order := ["heal", "refill", "vitality", "shield", "regen"]
			if emergency_order.has(key): score = 110.0 - emergency_order.find(key)
		if score > best_score:
			best = i
			best_score = score
	var record := {"game_seconds": arena.director.elapsed, "level": arena.level, "offered": option_keys, "card_text": option_text, "picked": option_keys[best], "hp_before": arena.stats.hp, "ranks_before": arena.ranks.duplicate(), "offer_transaction": arena.offer_state.pending.duplicate(true)}
	buttons[best].pressed.emit()
	check(arena.stats.catalog.progression == game.progression, "catalog preserves run profile after choice")
	record["hp_after"] = arena.stats.hp
	record["ranks_after"] = arena.ranks.duplicate()
	offers.append(record)
	print("UPGRADE " + JSON.stringify({"strategy": strategy, "selection": record}))
	check(game.current_mode in ["campaign", "endless"] and not paused, strategy + ": offered button resumes normal Endless")

func _steer() -> void:
	if controller == "responsive": Input.action_release("dash")
	var position := arena.player.position
	var target := arena.bounds.get_center() + Vector2(cos(arena.director.elapsed * 0.18), sin(arena.director.elapsed * 0.18)) * Vector2(330.0, 170.0)
	var best_pickup := INF
	# Prefer nearby experience unless it is visibly covered by a live enemy.
	for pickup: Vector2 in arena.pickups:
		var cost := position.distance_to(pickup)
		for node: Node in arena.enemies.get_children():
			var enemy := node as EnemyActor
			if enemy.is_dead or enemy is BossActor: continue
			cost += maxf(0.0, 100.0 - enemy.position.distance_to(pickup)) * 3.0
		if cost < best_pickup:
			best_pickup = cost
			target = pickup
	if objective == "boss":
		for node in arena.enemies.get_children():
			if node is BossActor and not node.is_dead:
				target = node.position
				break
	var desired := position.direction_to(target)
	var best_direction := desired
	var best_score := -INF
	var nearest_enemy := INF
	var imminent_hazard := false
	for node: Node in arena.enemies.get_children():
		var enemy := node as EnemyActor
		if enemy.is_dead: continue
		if not enemy is BossActor: nearest_enemy = minf(nearest_enemy, position.distance_to(enemy.position))
		else:
			var boss := enemy as BossActor
			if (boss.state == "warning" and boss.phase_time < 0.35) or boss.state == "charge":
				if _segment_distance(position, boss.charge_start, boss.charge_end) < boss.charge_width * 0.5 + 35.0: imminent_hazard = true
			for rock: RockWarning in boss.rocks:
				if is_instance_valid(rock) and not rock.impacted and rock.warning_duration - rock.elapsed < 0.35 and position.distance_to(rock.global_position) < rock.radius + 35.0: imminent_hazard = true
	for bullet: EnemyBullet in arena.enemy_bullets.get_children():
		if _segment_distance(position, bullet.position, bullet.position + bullet.direction * bullet.definition.bullet_speed * 0.25) < arena.player.radius + bullet.definition.bullet_radius + 12.0: imminent_hazard = true
	for i in range(16):
		var direction := Vector2.from_angle(float(i) * TAU / 16.0)
		var future := position + direction * arena.stats.move_speed * 0.35
		var score := direction.dot(desired) * 2.0 + direction.dot(previous_direction) * 0.3
		var safe := arena.bounds.grow(-40.0)
		if not safe.has_point(future): score -= 12.0 + future.distance_to(future.clamp(safe.position, safe.end)) * 0.08
		for node: Node in arena.enemies.get_children():
			var enemy := node as EnemyActor
			if enemy.is_dead: continue
			if enemy is BossActor:
				var boss := enemy as BossActor
				if boss.state == "warning" or boss.state == "charge":
					var distance := _segment_distance(future, boss.charge_start, boss.charge_end)
					score -= maxf(0.0, boss.charge_width * 0.5 + 45.0 - distance) * 0.16
				for rock: RockWarning in boss.rocks:
					if is_instance_valid(rock) and not rock.impacted:
						score -= maxf(0.0, rock.radius + 42.0 - future.distance_to(rock.global_position)) * 0.18
			else:
				var predicted := enemy.position + enemy.position.direction_to(position) * enemy.speed * 0.35
				var distance := future.distance_to(predicted)
				score -= maxf(0.0, 110.0 - distance) * 0.10
				score -= maxf(0.0, 44.0 - _segment_distance(enemy.position, position, future)) * 0.18
		for bullet: EnemyBullet in arena.enemy_bullets.get_children():
			var rel_start := bullet.position - position
			var rel_end := rel_start + bullet.direction * bullet.definition.bullet_speed * 0.35 - direction * arena.stats.move_speed * 0.35
			var separation := _segment_distance(Vector2.ZERO, rel_start, rel_end)
			score -= maxf(0.0, arena.player.radius + bullet.definition.bullet_radius + 30.0 - separation) * 0.3
		if score > best_score:
			best_score = score
			best_direction = direction
	previous_direction = best_direction
	var dash := arena.player.dash_cooldown <= 0.0 and (nearest_enemy < 74.0 or imminent_hazard)
	if controller == "lagged":
		pending_decision = {"at": arena.director.elapsed + 0.2, "direction": best_direction, "dash": dash}
	else: _apply_decision(best_direction, dash)

func _apply_decision(direction: Vector2, dash: bool) -> void:
	Input.action_release("dash")
	_set_axis("move_left", "move_right", direction.x)
	_set_axis("move_up", "move_down", direction.y)
	if dash:
		Input.action_press("dash")
		dash_requests += 1

func _set_axis(negative: String, positive: String, value: float) -> void:
	Input.action_release(negative)
	Input.action_release(positive)
	if value < -0.001: Input.action_press(negative, -value)
	elif value > 0.001: Input.action_press(positive, value)

func _segment_distance(point: Vector2, start: Vector2, finish: Vector2) -> float:
	return point.distance_to(Geometry2D.get_closest_point_to_segment(point, start, finish))

func _source_hashes() -> Dictionary:
	var result := {}
	for path in ["tests/run_pacing_balance_bench.gd", "scripts/combat/combat_stats.gd", "scripts/combat/combat_definition.gd", "scripts/combat/combat_rules.gd", "resources/upgrades/shield.tres", "scripts/upgrades/upgrade_offer_engine.gd", "scripts/upgrades/offer_run_state.gd", "scripts/upgrades/offer_weight_profile.gd", "resources/settings/offer_weights.tres", "scripts/upgrades/upgrade_catalog.gd", "scripts/systems/arena.gd", "scripts/systems/run_director.gd", "scripts/systems/arena_definition.gd", "scripts/bosses/boss.gd", "scripts/main.gd", "scripts/progression/achievement_profile.gd", "resources/progression/default.tres", "resources/settings/arena.tres"]:
		result[path] = FileAccess.get_sha256("res://" + path)
	return result
