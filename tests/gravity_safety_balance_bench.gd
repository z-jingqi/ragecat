extends SceneTree
## Sustained pressure observations. NOT a claim of indefinite safety/human balance.
## Continuous spawns use real actors/projectiles and actual60Hz engine callbacks.
## Contact counters are opportunity-steps, NOT fabricated prevented damage: only
## overlaps that would be eligible without gravity and without health iframes count.
## --scenario=lane|surround|mixed|charge|rocks --budget=12|24 --element=dark
## --seeds=2 --seconds=180 --out=/tmp/gravity-safety.json
## --late-20min uses current director HP, mean cadence, enemy/ranged caps at
## 1200 active seconds with Endless enabled; fixture positions remain controlled.
## Live caps throttle spawns. These are equal-budget rule sets, not identical
## realized enemy counts, a pure suppression ablation, or a normal campaign.
class SafetyArena extends RageArena:
	var clock := 0.0
	var observed := false
	var failures := 0
	var metrics := {"contact_overlap_steps":0,"suppressed_overlap_steps":0,"gravity_only_eligible_steps":0,"iframe_overlap_steps":0,"eligible_unsuppressed_steps":0,"enemy_alive_seconds":0.0,"affected_enemy_seconds":0.0,"suppressed_enemy_seconds":0.0,"player_in_field_seconds":0.0,"gravity_flight_seconds":0.0,"gravity_absent_seconds":0.0,"boss_committed_steps":0}
	var per_enemy: Dictionary = {}
	var damage_sources: Dictionary = {}
	var flights: Array[Dictionary] = []
	var gaps: Array[Dictionary] = []
	var active_id := 0
	var flight_start := 0.0
	var gap_start := -1.0
	var feedback_health_damage := 0.0
	func _physics_process(delta: float) -> void:
		if observed and not finished:
			clock += delta
			var current := 0
			var field: GravityField
			var gravity_count := 0
			for projectile in arrows.get_children():
				if projectile is BowArrow and is_instance_valid(projectile.gravity_field) and projectile.gravity_field.is_active():
					gravity_count += 1
					current = projectile.get_instance_id()
					field = projectile.gravity_field
			if gravity_count > 1: _fail("multiple gravity arrows")
			if current != active_id:
				if active_id != 0:
					flights.append({"start":flight_start,"end":clock,"duration":clock-flight_start})
					gap_start = clock
				if current != 0:
					if gap_start >= 0.0:
						var duration := clock-gap_start
						gaps.append({"start":gap_start,"end":clock,"duration":duration,"configured":stats.gravity_gap})
						if duration < stats.gravity_gap - 2.0/60.0: _fail("post-arrow gap shorter than configured gate")
					flight_start = clock
				active_id = current
			if current != 0:
				metrics.gravity_flight_seconds += delta
				if player.position.distance_to(field.global_position) <= field.outer_radius: metrics.player_in_field_seconds += delta
			else: metrics.gravity_absent_seconds += delta
			for enemy: EnemyActor in enemies.get_children():
				if enemy.is_dead: continue
				var id := str(enemy.get_instance_id())
				if not per_enemy.has(id): per_enemy[id] = {"alive":0.0,"affected":0.0,"suppressed":0.0,"eligible_suppressed_steps":0}
				var affected := enemy.is_gravity_affected()
				var suppressed := enemy.contact_damage_suppressed()
				metrics.enemy_alive_seconds += delta
				per_enemy[id].alive += delta
				if affected:
					metrics.affected_enemy_seconds += delta
					per_enemy[id].affected += delta
				if suppressed:
					metrics.suppressed_enemy_seconds += delta
					per_enemy[id].suppressed += delta
				if enemy is Mountainbreaker and enemy.state in ["warning","charge"]:
					metrics.boss_committed_steps += 1
					if affected or suppressed: _fail("committed boss charge suppressed by gravity")
				if enemy is BossActor or enemy.is_dummy: continue
				if enemy.position.distance_to(player.position) >= enemy.radius+player.radius: continue
				metrics.contact_overlap_steps += 1
				if suppressed: metrics.suppressed_overlap_steps += 1
				var iframe := player.health_state.invulnerability > 0.0 or player.invulnerable or player.dash_left > 0.0
				if iframe: metrics.iframe_overlap_steps += 1
				elif suppressed:
					metrics.gravity_only_eligible_steps += 1
					per_enemy[id].eligible_suppressed_steps += 1
				else: metrics.eligible_unsuppressed_steps += 1
			super._physics_process(delta)
		else: super._physics_process(delta)
	func _fail(message: String) -> void:
		failures += 1
		if failures <= 3: push_error("GRAVITY SAFETY: "+message)
	func _on_player_hit_feedback(kind: String, amount: float) -> void:
		var source := "unknown"
		for frame in get_stack():
			var path := str(frame.get("source",""))
			var function := str(frame.get("function",""))
			if path.ends_with("enemy_bullet.gd"): source = "projectile"; break
			if path.ends_with("mountainbreaker.gd"):
				source = "rock" if function == "_impact_rock" or "rock" in function else "charge"
				break
			if path.ends_with("arena.gd") and function == "_physics_process": source = "contact"
		var key := source + ("_shield" if kind in ["block","break"] else "_health")
		damage_sources[key] = int(damage_sources.get(key,0))+1
		if kind not in ["block","break"]: feedback_health_damage += amount
		super._on_player_hit_feedback(kind,amount)

const SEEDS := [7319,38117]
const ELEMENTS := ["physical","fire","lightning","ice","dark_plain","dark"]
var results: Array[Dictionary] = []
var scenario_filter := ""
var element_filter := ""
var budget_filter := 0
var seed_count := 2
var duration := 180.0
var out := "/tmp/gravity-safety.json"
var failures := 0
var late_20min := false
var source_snapshot: Dictionary = {}

func _initialize() -> void: call_deferred("run")
func run() -> void:
	_hash_directory("res://scripts",source_snapshot)
	_hash_directory("res://resources",source_snapshot)
	_hash_directory("res://scenes",source_snapshot)
	source_snapshot["project.godot"] = FileAccess.get_sha256("res://project.godot")
	source_snapshot["tests/gravity_safety_balance_bench.gd"] = FileAccess.get_sha256("res://tests/gravity_safety_balance_bench.gd")
	for arg in OS.get_cmdline_user_args():
		if arg == "--late-20min": late_20min = true
		if arg.begins_with("--scenario="): scenario_filter = arg.trim_prefix("--scenario=")
		if arg.begins_with("--element="): element_filter = arg.trim_prefix("--element=")
		if arg.begins_with("--budget="): budget_filter = int(arg.trim_prefix("--budget="))
		if arg.begins_with("--seeds="): seed_count = clampi(int(arg.trim_prefix("--seeds=")),1,2)
		if arg.begins_with("--seconds="): duration = clampf(float(arg.trim_prefix("--seconds=")),1,180)
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
	if (not scenario_filter.is_empty() and scenario_filter not in ["lane","surround","mixed","charge","rocks"]) or (not element_filter.is_empty() and element_filter not in ELEMENTS) or budget_filter not in [0,12,24]:
		push_error("Invalid safety benchmark filter")
		quit(1)
		return
	for scenario: String in ["lane","surround","mixed","charge","rocks"]:
		if not scenario_filter.is_empty() and scenario_filter != scenario: continue
		for budget: int in [12,24]:
			if budget_filter > 0 and budget_filter != budget: continue
			for element: String in ELEMENTS:
				if not element_filter.is_empty() and element_filter != element: continue
				if scenario in ["charge","rocks"] and element != "dark": continue
				for run_seed: int in SEEDS.slice(0,seed_count): await trial(scenario,budget,element,run_seed)
	var file := FileAccess.open(out,FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify({"source_hashes":source_snapshot,"engine":Engine.get_version_info(),"method":"Actual60Hz engine. Stationary vulnerable player; continuous finite-rate reinforcements, bounded live pool. Purchased rank cost matched, including enchants/mastery. Dark_plain has enchant but no exclusive and reallocates that cost. Boss diagnostics hold boss health high and forcephase2 to test threat bypass, not TTK. A surviving180s case is censored, never indefinite immunity. Opportunity-steps are contact overlaps without ordinary iframes, NOT inferred prevented HP. Separate per-enemy clocks, flight/gap timeline and accepted damage types.","failures":failures,"results":results},"\t"))
	else: failures += 1
	print("SAFETY COMPLETE ",results.size()," failures ",failures," ",out)
	quit(1 if failures else 0)

func build(element: String,budget: int) -> Dictionary:
	if budget == 12:
		if element == "physical": return {"damage_flat":3,"damage":3,"burst":2,"spread_arrow":2,"regen":2}
		if element == "dark_plain": return {"dark_enchant":2,"damage":3,"burst":2,"spread_arrow":3,"regen":2}
		return {element+"_enchant":2,element+"_bow":2,"damage":2,"burst":2,"spread_arrow":2,"regen":2}
	if element == "physical": return {"damage_flat":3,"damage":3,"attack_speed":3,"burst":3,"spread_arrow":3,"split":3,"pierce":3,"regen":3}
	if element == "dark_plain": return {"dark_enchant":3,"damage":3,"attack_speed":3,"burst":3,"spread_arrow":3,"split":3,"damage_flat":3,"regen":3}
	if element == "dark": return {"dark_enchant":3,"dark_bow":3,"damage":3,"burst":3,"spread_arrow":3,"split":3,"attack_speed":3,"regen":3}
	return {element+"_enchant":3,element+"_bow":3,"damage":3,"burst":3,"spread_arrow":3,"split":3,"damage_flat":3,"regen":3}

func trial(scenario: String,budget: int,element: String,run_seed: int) -> void:
	seed(run_seed)
	var arena := SafetyArena.new()
	arena.practice = true
	arena.lab_ai = true
	arena.sound_enabled = false
	arena.run_seed_override = run_seed
	root.add_child(arena)
	var ranks := build(element,budget)
	var cost := 0
	for rank in ranks.values(): cost += int(rank)
	if cost != budget: arena._fail("equal budget")
	arena.apply_ranks(ranks)
	arena.stats.hp = arena.stats.max_hp
	arena.player.invulnerable = false
	arena.player.movement_enabled = false
	arena.player.position = arena.bounds.get_center()
	var spawn_rng := RandomNumberGenerator.new()
	spawn_rng.seed = run_seed
	if late_20min:
		arena.director.elapsed = 1200.0
		arena.director.endless = true
	var interval := arena.director.base_spawn_interval() if late_20min else 0.5
	var live_cap := arena.definition.enemy_limit if late_20min else 16
	var spawned := 0
	var next_spawn := 0.0
	if scenario in ["charge","rocks"]:
		arena.boss_mode = scenario
		var boss := arena.spawn_enemy("mountainbreaker",arena.player.position+Vector2(240,0)) as Mountainbreaker
		boss.max_health = 1000000.0
		boss.health = boss.max_health
		boss.force_phase_for_practice(2)
	arena.observed = true
	var wall_start := Time.get_ticks_msec()
	var watchdog := false
	while arena.clock < duration and not arena.finished:
		if arena.clock >= next_spawn:
			var live := arena.enemies.get_child_count()
			if live < live_cap:
				var angle := spawn_rng.randf_range(-0.15,0.15) if scenario == "lane" else spawn_rng.randf()*TAU
				var radius := 240.0
				var at := arena.player.position + Vector2.from_angle(angle)*radius
				var kind := "ranged" if scenario == "mixed" and spawned%4 == 3 else "mob"
				if late_20min and scenario == "mixed":
					var ranged_count := 0
					for actor in arena.enemies.get_children():
						if actor is Spitter and not actor.is_dead: ranged_count += 1
					kind = "ranged" if spawn_rng.randf() < arena.definition.ranged_fraction and ranged_count < arena.director.ranged_admission_limit() else "mob"
				# Mixed projectiles must start within their actual firing range.
				if kind == "ranged": at = arena.player.position + Vector2.from_angle(angle)*320.0
				var enemy := arena.spawn_enemy(kind,at)
				if enemy != null:
					if not late_20min:
						enemy.max_health = 120.0 * (0.6 if kind == "ranged" else 1.0)
						enemy.health = enemy.max_health
					spawned += 1
			# No queued burst when capped; constant0.5s pressure is fixture policy.
			next_spawn = arena.clock+interval
		await physics_frame
		if Time.get_ticks_msec()-wall_start > 240000:
			watchdog = true
			arena._fail("wall watchdog")
			break
	arena.observed = false
	if absf(100.0+arena.player.healed_total-arena.feedback_health_damage-arena.stats.hp) > 0.001: arena._fail("health accounting")
	var censored_timeline: Dictionary = {}
	if arena.active_id != 0: censored_timeline = {"kind":"flight","start":arena.flight_start,"end":arena.clock,"duration":arena.clock-arena.flight_start,"censored":true}
	elif arena.gap_start >= 0.0: censored_timeline = {"kind":"gap","start":arena.gap_start,"end":arena.clock,"duration":arena.clock-arena.gap_start,"censored":true}
	var record := {"scenario":scenario,"censored_timeline":censored_timeline,"late_20min":late_20min,"reference_melee_hp":arena.definition.melee_health*arena.director.mob_health_multiplier() if late_20min else 120.0,"spawn_interval":interval,"live_cap":live_cap,"budget":budget,"element":element,"seed":run_seed,"ranks":ranks,"elapsed":arena.clock,"limit":duration,"terminal":"watchdog" if watchdog else ("dead" if arena.finished else "time_limit"),"hp":arena.stats.hp,"healed":arena.player.healed_total,"damage_taken":arena.feedback_health_damage,"damage_sources":arena.damage_sources,"kills":arena.kills,"spawned":spawned,"damage_dealt":arena.total_damage,"metrics":arena.metrics,"per_enemy":arena.per_enemy,"flights":arena.flights,"gaps":arena.gaps,"configured_gap":arena.stats.gravity_gap if arena.stats.gravity_mode() else null,"failures":arena.failures}
	results.append(record)
	failures += arena.failures
	# Keep console bounded; complete per-enemy/timeline data is in the output file.
	var brief := record.duplicate()
	brief.erase("per_enemy"); brief.erase("flights"); brief.erase("gaps")
	print("SAFETY ",JSON.stringify(brief))
	arena.free()
	await process_frame

func _hash_directory(path: String, hashes: Dictionary) -> void:
	for name: String in DirAccess.get_files_at(path):
		var full := path.path_join(name)
		hashes[full.trim_prefix("res://")] = FileAccess.get_sha256(full)
	for name: String in DirAccess.get_directories_at(path):
		_hash_directory(path.path_join(name), hashes)
