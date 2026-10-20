extends SceneTree
## Engine-driven normal Endless coverage, not a human playtest or balance certificate.
## The harness only seeds RNG, reads state, presses movement/dash actions, and emits
## pressed on offered upgrade Buttons. It never manually calls gameplay callbacks,
## changes HP/ranks/positions, grants invulnerability, or advances the director.
## Default: three distinct seeds/build priorities. Optional user arguments:
## --strategy=split_status --seed=10891 --output=/absolute/results.json
## A focused supplemental run uses exactly the same gameplay/input constraints.

const LIMIT_SECONDS := 240.0
const RUNS := [
	{"seed": 7319, "strategy": "bow"},
	{"seed": 38117, "strategy": "split_status"},
	{"seed": 91073, "strategy": "mobility_defense"},
]
const PRIORITIES := {
	"bow": ["burst", "spread_arrow", "long_draw", "attack_speed", "damage", "pierce", "split", "crit_chance", "crit_damage", "knockback", "poison", "bleed", "poison_crit", "spread", "shield", "regen", "move_speed", "pickup_radius", "bleed_regen", "vitality"],
	"split_status": ["split", "poison", "poison_crit", "bleed", "spread", "bleed_regen", "pierce", "attack_speed", "long_draw", "burst", "spread_arrow", "damage", "crit_chance", "knockback", "regen", "shield", "move_speed", "pickup_radius", "vitality", "crit_damage"],
	"mobility_defense": ["move_speed", "knockback", "shield", "regen", "bleed_regen", "bleed", "vitality", "pickup_radius", "long_draw", "split", "burst", "spread_arrow", "damage", "attack_speed", "pierce", "poison", "crit_chance", "poison_crit", "spread", "crit_damage"],
}
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
var output_path := "user://ranged-normal-results.json"
var selected_runs: Array = RUNS.duplicate(true)
var ranged_spawned := 0
var enemy_shots_spawned := 0
var primary_spawned := 0
var secondary_spawned := 0
var primary_hits := 0
var secondary_hits := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		if not violation_keys.has(message):
			violation_keys[message] = true
			push_error("RANGED NORMAL RUN FAIL: " + message)

func _release_input() -> void:
	for action: String in ACTIONS:
		if InputMap.has_action(action): Input.action_release(action)

func run() -> void:
	start_wall_usec = Time.get_ticks_usec()
	var chosen_strategy := ""
	var chosen_seed := -1
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output_path = argument.trim_prefix("--output=")
		elif argument.begins_with("--strategy="): chosen_strategy = argument.trim_prefix("--strategy=")
		elif argument.begins_with("--seed="): chosen_seed = int(argument.trim_prefix("--seed="))
	if not chosen_strategy.is_empty():
		if not PRIORITIES.has(chosen_strategy):
			push_error("Unknown normal-run strategy: " + chosen_strategy)
			quit(2)
			return
		selected_runs = []
		for specification: Dictionary in RUNS:
			if str(specification.strategy) == chosen_strategy:
				selected_runs.append(specification.duplicate(true))
	if chosen_seed >= 0:
		if selected_runs.size() != 1:
			push_error("--seed requires a single --strategy")
			quit(2)
			return
		selected_runs[0]["seed"] = chosen_seed
	process_frame.connect(_observe_render)
	physics_frame.connect(_observe_physics)
	print("RANGED NORMAL SEEDED RUNS: genuine engine physics; normal Endless; actual offered UI picks; survival is an observation, not a pass condition")
	print("METHOD: perfect-state automated steering, analog WASD and threat-triggered dash; no gameplay state grants; 240 game seconds or death; seeds cover global RNG and arena RNG")
	game = load("res://scenes/main.tscn").instantiate() as Node
	root.add_child(game)
	for specification: Dictionary in selected_runs:
		await _run_one(specification)
	check(results.size() == selected_runs.size(), "All requested normal strategies completed")
	var build_signatures: Dictionary = {}
	for result: Dictionary in results:
		var ranked_keys: Array = result.ranks.keys()
		ranked_keys.sort()
		var signature := ""
		for key: String in ranked_keys: signature += key + ":" + str(result.ranks[key]) + ";"
		build_signatures[signature] = true
	check(build_signatures.size() == selected_runs.size(), "All observed builds are distinct")
	print("RANGED NORMAL SEEDED SUMMARY " + JSON.stringify({"passed": not failed, "checks": checks, "wall_seconds": (Time.get_ticks_usec() - start_wall_usec) / 1000000.0, "runs": results}))
	DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	var output := FileAccess.open(output_path, FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify({"passed": not failed, "checks": checks, "method": "Engine-driven normal Endless, genuine callbacks, no grants or manual ticks. State-aware automated policy, not human gameplay or balance certification.", "game_seconds_limit": LIMIT_SECONDS, "physics_ticks_per_second": Engine.physics_ticks_per_second, "engine_time_scale": Engine.time_scale, "priority_orders": PRIORITIES, "runs": results}, "\t"))
		output.close()
	else:
		check(false, "Could not write " + output_path)
	game.queue_free()
	await process_frame
	quit(1 if failed else 0)

func _run_one(specification: Dictionary) -> void:
	_release_input()
	strategy = str(specification.strategy)
	run_seed = int(specification.seed)
	seed(run_seed)
	game.start_run(false)
	arena = game.arena
	arena.rng.seed = run_seed
	peaks = {"enemies": 0, "arrows": 0, "pickups": 0, "effects": 0, "rocks": 0, "primary_live": 0, "secondary_live": 0, "ranged": 0, "enemy_bullets": 0}
	offers = []
	boss_spawn_times = []
	boss_ids = {}
	observations = 0
	physics_observations = 0
	render_observations = 0
	ranged_spawned = 0
	enemy_shots_spawned = 0
	primary_spawned = 0
	secondary_spawned = 0
	primary_hits = 0
	secondary_hits = 0
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
		if kind == "block" or kind == "break": shield_blocks += 1
		else: health_hits += 1
	)
	arena.enemies.child_entered_tree.connect(_track_spawn)
	arena.enemy_bullets.child_entered_tree.connect(func(_bullet:Node)->void: enemy_shots_spawned += 1)
	arena.arrows.child_entered_tree.connect(_track_projectile_spawn)
	arena.effects.child_entered_tree.connect(_track_node_peak.bind("effects", arena.effects))
	arena.bow.arrow_hit.connect(_track_projectile_hit)
	active = true
	var wall_start := Time.get_ticks_usec()
	var engine_start := Engine.get_physics_frames()
	print("RUN START " + JSON.stringify({"strategy": strategy, "seed": run_seed, "hp": arena.stats.hp, "ranks": arena.ranks, "game_seconds": arena.director.elapsed}))
	check(not arena.practice and not arena.player.invulnerable, strategy + ": normal mode without invulnerability")
	check(arena.ranks.is_empty(), strategy + ": starts with no ranks")
	while not arena.finished and arena.director.elapsed < LIMIT_SECONDS:
		if game.current_mode == "upgrade": _pick_upgrade()
		if not paused and not arena.finished: _steer()
		await process_frame
		if Time.get_ticks_usec() - wall_start > 180000000:
			check(false, strategy + ": real-time watchdog (180 seconds) expired")
			break
	_observe()
	_release_input()
	active = false
	var terminal := "dead" if arena.finished else ("time_limit" if arena.director.elapsed >= LIMIT_SECONDS else "watchdog")
	check(terminal != "watchdog", strategy + ": observed a natural terminal state or the defined time limit")
	check(int(peaks.enemies) <= 70, strategy + ": recorded enemy peak <= 70")
	check(int(peaks.pickups) <= 250, strategy + ": recorded pickup peak <= 250")
	check(terminal != "dead" or game.current_mode == "dead", strategy + ": death remains the terminal UI when observed")
	check(arena.director.elapsed > 0.0, strategy + ": genuine game clock advanced")
	check(movement_distance > 0.0, strategy + ": movement actions moved the player")
	check(not arena.player.invulnerable, strategy + ": invulnerability remains disabled")
	var result := {
		"strategy": strategy, "seed": run_seed, "terminal": terminal, "ui_mode": game.current_mode,
		"game_seconds": arena.director.elapsed, "wall_seconds": (Time.get_ticks_usec() - wall_start) / 1000000.0,
		"engine_physics_frames": Engine.get_physics_frames() - engine_start,
		"physics_observations": physics_observations, "render_observations": render_observations,
		"hp": arena.stats.hp, "max_hp": arena.stats.max_hp, "shields": arena.stats.shields,
		"shield_capacity": arena.stats.shield_capacity, "level": arena.level,
		"xp": arena.xp, "xp_needed": arena.xp_needed, "ranks": arena.ranks.duplicate(),
		"kills": arena.kills, "bosses_defeated": arena.director.boss_count,
		"bosses_spawned": boss_ids.size(), "boss_spawn_times": boss_spawn_times.duplicate(),
		"hits": arena.hits, "crits": arena.crits, "poison_hits": arena.poison_hits, "bleed_hits": arena.bleed_hits,
		"damage_dealt": arena.total_damage, "healed_total": arena.player.healed_total,
		"health_hit_events": health_hits, "shield_block_events": shield_blocks,
		"dash_requests": dash_requests, "dash_activations": dash_activations,
		"ranged_spawned": ranged_spawned, "enemy_shots_spawned": enemy_shots_spawned,
		"primary_projectiles_spawned": primary_spawned, "secondary_projectiles_spawned": secondary_spawned,
		"primary_hit_events": primary_hits, "secondary_hit_events": secondary_hits,
		"movement_distance": movement_distance, "peaks": peaks.duplicate(), "offers": offers.duplicate(true),
	}
	results.append(result)
	print("RUN RESULT " + JSON.stringify(result))
	paused = false
	game.show_menu()
	await process_frame
	arena = null

func _track_spawn(node: Node) -> void:
	if node is RangedEnemy: ranged_spawned += 1
	peaks.enemies = maxi(int(peaks.enemies), arena.enemies.get_child_count())
	if node is BossActor and not boss_ids.has(node.get_instance_id()):
		boss_ids[node.get_instance_id()] = true
		boss_spawn_times.append(arena.director.elapsed)
		print("BOSS SPAWN " + JSON.stringify({"strategy": strategy, "game_seconds": arena.director.elapsed, "hp": arena.stats.hp, "boss_hp": node.health}))

func _track_projectile_spawn(node: Node) -> void:
	if node is CatArrow:
		if node.secondary: secondary_spawned += 1
		else: primary_spawned += 1
	_track_projectile_peaks()

func _track_projectile_hit(arrow: CatArrow, _enemy: EnemyActor) -> void:
	if arrow.secondary: secondary_hits += 1
	else: primary_hits += 1

func _track_projectile_peaks() -> void:
	var primary_live := arena.bow.active_count(false)
	var secondary_live := arena.bow.active_count(true)
	peaks.arrows = maxi(int(peaks.arrows), arena.arrows.get_child_count())
	peaks.primary_live = maxi(int(peaks.primary_live), primary_live)
	peaks.secondary_live = maxi(int(peaks.secondary_live), secondary_live)
	check(primary_live <= BowController.PRIMARY_LIMIT, strategy + ": primary live projectile cap respected")
	check(secondary_live <= BowController.FRAGMENT_LIMIT, strategy + ": fragment live projectile cap respected")

func _track_node_peak(_node: Node, key: String, container: Node) -> void:
	peaks[key] = maxi(int(peaks[key]), container.get_child_count())

func _observe_render() -> void:
	if active:
		render_observations += 1
		_observe()

func _observe_physics() -> void:
	if active:
		physics_observations += 1
		_observe()

func _observe() -> void:
	if not active or not is_instance_valid(arena): return
	observations += 1
	var enemy_count := arena.enemies.get_child_count()
	var rock_count := 0
	var ranged_count := 0
	for node: Node in arena.enemies.get_children():
		if node is RangedEnemy:
			ranged_count += 1
			check(arena.bounds.has_point(node.position), strategy + ": ranged stays inside arena")
		if node is BossActor:
			for child: Node in node.get_children():
				if child is RockWarning: rock_count += 1
	peaks.enemies = maxi(int(peaks.enemies), enemy_count)
	_track_projectile_peaks()
	peaks.pickups = maxi(int(peaks.pickups), arena.pickups.size())
	peaks.effects = maxi(int(peaks.effects), arena.effects.get_child_count())
	peaks.rocks = maxi(int(peaks.rocks), rock_count)
	peaks.ranged = maxi(int(peaks.ranged),ranged_count)
	peaks.enemy_bullets = maxi(int(peaks.enemy_bullets),arena.enemy_bullets.get_child_count())
	check(ranged_count <= arena.definition.ranged_limit, strategy + ": ranged live cap respected")
	check(arena.enemy_bullets.get_child_count() <= arena.definition.enemy_projectile_limit, strategy + ": enemy bullet budget respected")
	check(is_finite(arena.stats.hp) and arena.stats.hp >= 0.0 and arena.stats.hp <= arena.stats.max_hp + 0.001, strategy + ": HP remains within legitimate bounds")
	check(arena.stats.shields >= 0 and arena.stats.shields <= arena.stats.shield_capacity, strategy + ": shields remain within capacity")
	check(enemy_count <= 70, strategy + ": explicit enemy cap <= 70 every observed frame")
	check(arena.pickups.size() <= 250, strategy + ": explicit pickup cap <= 250 every observed frame")
	check(not arena.player.invulnerable, strategy + ": no invulnerability granted")
	for key: String in arena.ranks:
		check(int(arena.ranks[key]) >= 1 and int(arena.ranks[key]) <= 3, strategy + ": all selected upgrade ranks remain within 1..3")
	movement_distance += previous_position.distance_to(arena.player.position)
	previous_position = arena.player.position
	if arena.player.dash_left > prior_dash + 0.01: dash_activations += 1
	prior_dash = arena.player.dash_left
	if arena.director.elapsed >= next_progress:
		print("RUN PROGRESS " + JSON.stringify({"strategy": strategy, "game_seconds": arena.director.elapsed, "hp": arena.stats.hp, "level": arena.level, "kills": arena.kills, "bosses": arena.director.boss_count, "peaks": peaks}))
		next_progress += 30.0

func _button_key(item: Button) -> String:
	if item.text.begins_with("SECOND WIND"): return "refill"
	if item.text.begins_with("CAT NAP"): return "heal"
	if item.text.begins_with("KEEP FIGHTING"): return "continue"
	for key: String in game.catalog.definitions:
		if item.text.begins_with(str(game.catalog.definitions[key].name) + "  ["): return key
	return ""

func _pick_upgrade() -> void:
	_release_input()
	var buttons: Array[Button] = []
	var option_keys: Array[String] = []
	var option_text: Array[String] = []
	for node: Node in game.overlay.get_child(1).get_children():
		if node is Button:
			buttons.append(node)
			option_keys.append(_button_key(node))
			option_text.append(node.text)
	check(not buttons.is_empty(), strategy + ": upgrade UI has an actual offered button")
	if buttons.is_empty(): return
	var eligible_keys: Array[String] = game.catalog.eligible(arena.ranks, arena.stats)
	if arena.stats.shields < arena.stats.shield_capacity: eligible_keys.append("refill")
	if arena.stats.hp < arena.stats.max_hp: eligible_keys.append("heal")
	if eligible_keys.is_empty(): eligible_keys.append("continue")
	check(buttons.size() == mini(3, eligible_keys.size()), strategy + ": exact eligible choice count")
	var unique_keys: Dictionary = {}
	for key: String in option_keys:
		check(eligible_keys.has(key), strategy + ": every actual offered card is eligible")
		check(not unique_keys.has(key), strategy + ": offered upgrade cards are distinct")
		unique_keys[key] = true
	var best := 0
	var best_score := -INF
	for i in range(buttons.size()):
		var key := option_keys[i]
		check(not key.is_empty(), strategy + ": offered UI card maps to a known upgrade")
		var order: Array = PRIORITIES[strategy]
		var score := float(order.size() - order.find(key)) if order.has(key) else -10.0
		if key == "heal": score = 100.0 if arena.stats.hp < arena.stats.max_hp * 0.55 else -2.0
		if key == "refill": score = 80.0 if arena.stats.hp < arena.stats.max_hp * 0.45 else (18.0 if strategy == "mobility_defense" else 0.0)
		if score > best_score:
			best = i
			best_score = score
	var record := {"game_seconds": arena.director.elapsed, "level": arena.level, "offered": option_keys, "card_text": option_text, "picked": option_keys[best], "hp_before": arena.stats.hp, "ranks_before": arena.ranks.duplicate()}
	buttons[best].pressed.emit()
	record["hp_after"] = arena.stats.hp
	record["ranks_after"] = arena.ranks.duplicate()
	var picked: String = option_keys[best]
	if game.catalog.definitions.has(picked):
		check(int(arena.ranks.get(picked, 0)) == int(record.ranks_before.get(picked, 0)) + 1, strategy + ": offered upgrade advances exactly one rank")
		for other_key: String in game.catalog.definitions:
			if other_key != picked:
				check(int(arena.ranks.get(other_key, 0)) == int(record.ranks_before.get(other_key, 0)), strategy + ": selecting a card does not grant unrelated ranks")
	offers.append(record)
	print("UPGRADE " + JSON.stringify({"strategy": strategy, "selection": record}))
	check(game.current_mode == "endless" and not paused, strategy + ": offered button resumes normal Endless")

func _steer() -> void:
	Input.action_release("dash")
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
		if score > best_score:
			best_score = score
			best_direction = direction
	previous_direction = best_direction
	_set_axis("move_left", "move_right", best_direction.x)
	_set_axis("move_up", "move_down", best_direction.y)
	if arena.player.dash_cooldown <= 0.0 and (nearest_enemy < 74.0 or imminent_hazard):
		Input.action_press("dash")
		dash_requests += 1

func _set_axis(negative: String, positive: String, value: float) -> void:
	Input.action_release(negative)
	Input.action_release(positive)
	if value < -0.001: Input.action_press(negative, -value)
	elif value > 0.001: Input.action_press(positive, value)

func _segment_distance(point: Vector2, start: Vector2, finish: Vector2) -> float:
	return point.distance_to(Geometry2D.get_closest_point_to_segment(point, start, finish))
