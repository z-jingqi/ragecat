extends SceneTree
## Controlled, real-engine combat benchmark; not normal-run progression or a balance certificate.
## Run: godot --headless --fixed-fps 60 --script tests/element_balance_bench.gd -- --out=/tmp/element-balance.json
## Filters: --only=boss|dense|dispersed|survival|boss_mobile --element=ice --no-ablation
## --micro runs the isolated wall-adjacent MOB freeze/cadence diagnostic.
## All builds receive equal rank investment. Fixed geometry, five paired seeds, real bow,
## projectile collisions, damage, status clocks, gravity and (survival only) enemy AI.
## Static DPS isolates damage from survival. No production methods are manually ticked.

class MeasuredProcs extends ElementProcController:
	var actual_burn_damage := 0.0
	func _physics_process(delta: float) -> void:
		var before := arena.total_damage
		super._physics_process(delta)
		actual_burn_damage += arena.total_damage - before

class MeasuredArena extends RageArena:
	var attempted_damage := 0.0
	var actual_shock_bonus := 0.0
	var shatters := 0
	var elemental_packets := 0
	var direct_packets := 0
	func deal_damage_packet(enemy: EnemyActor, packet: Dictionary) -> void:
		if not enemy.is_dead:
			var bonus := float(packet.get("elemental_damage", 0)) * (enemy.status.elemental_multiplier() - 1.0)
			var nominal := float(packet.damage) + bonus
			attempted_damage += nominal
			if nominal > 0.0: actual_shock_bonus += minf(enemy.health, nominal) * bonus / nominal
			if bool(packet.get("ice_consumed", false)): shatters += 1
			if packet.has("elemental_precrit"): direct_packets += 1
			else: elemental_packets += 1
		super.deal_damage_packet(enemy, packet)

const SEEDS := [7319, 38117, 91073, 24117, 55103]
const ELEMENTS := ["fire", "lightning", "ice", "dark"]
var results: Array[Dictionary] = []
var arena: MeasuredArena
var elapsed := 0.0
var alive_seconds := 0.0
var frozen_seconds := 0.0
var slowed_seconds := 0.0
var suppressed_seconds := 0.0
var shocked_seconds := 0.0
var burning_seconds := 0.0
var active := false
var only := ""
var only_element := ""
var ablations := true
var out := "/tmp/element-balance.json"

func _initialize() -> void: call_deferred("run")

func run() -> void:
	if "--micro" in OS.get_cmdline_user_args():
		await run_micro()
		quit()
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="): out = argument.trim_prefix("--out=")
		if argument.begins_with("--only="): only = argument.trim_prefix("--only=")
		if argument.begins_with("--element="): only_element = argument.trim_prefix("--element=")
		if argument == "--no-ablation": ablations = false
	physics_frame.connect(observe)
	for scenario: String in ["boss", "dense", "dispersed", "survival", "boss_mobile"]:
		if only != "" and scenario != only: continue
		for tier: int in [1, 3]:
			for invested: bool in [false, true]:
				for run_seed: int in SEEDS:
					for element: String in ELEMENTS:
						if only_element != "" and element != only_element: continue
						await trial(scenario, tier, invested, run_seed, element, false)
					# Paired burn/shock-off ablations quantify added status separately.
					for element: String in ["fire", "lightning"]:
						if not ablations or (only_element != "" and element != only_element): continue
						await trial(scenario, tier, invested, run_seed, element, true)
	var file := FileAccess.open(out, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write benchmark output " + out)
		quit(1)
		return
	file.store_string(JSON.stringify({"method":"Real engine fixed-60Hz. AI-off damage trial retains knockback and gravity movement; separate AI-on stationary-player survival. Five paired seeds; same rank cost and geometry; ablation disables only new burn/shock but changes RNG consumption. No hand ticks. TTK censored at cap, actual HP damage excludes overkill. Overkill does not count missed shots.", "engine":Engine.get_version_info(), "results": results}, "\t"))
	print("BALANCE COMPLETE ", results.size(), " trials: ", out)
	quit()

func trial(scenario: String, tier: int, invested: bool, run_seed: int, element: String, ablation: bool) -> void:
	seed(run_seed)
	arena = MeasuredArena.new()
	arena.element_procs.free()
	arena.element_procs = MeasuredProcs.new()
	arena.practice = true
	arena.lab_ai = scenario in ["survival", "boss_mobile"]
	root.add_child(arena)
	arena.rng.seed = run_seed
	var ranks := {element + "_enchant": tier, element + "_bow": tier}
	if invested: ranks.merge({"burst": 2, "spread_arrow": 2, "split": 2, "pierce": 2})
	arena.apply_ranks(ranks)
	# Copy only for ablation; never modify shared production resources.
	if ablation:
		arena.stats.element_skill = arena.stats.element_skill.duplicate(true)
		if element == "fire": arena.stats.element_skill.burn_chance_by_rank = PackedFloat32Array([0,0,0,0])
		else: arena.stats.element_skill.shock_chance_by_rank = PackedFloat32Array([0,0,0,0])
	arena.player.movement_enabled = false
	arena.player.invulnerable = scenario not in ["survival", "boss_mobile"]
	arena.player.position = arena.bounds.get_center() - Vector2(220, 0)
	var count := 1 if scenario in ["boss", "boss_mobile"] else (24 if scenario == "survival" else 12)
	var hp := 800.0 if scenario in ["boss", "boss_mobile"] else (120.0 if scenario == "survival" else 180.0)
	for i in range(count):
		var position: Vector2
		if scenario in ["boss", "boss_mobile"]: position = arena.player.position + Vector2(260,0)
		elif scenario == "dense": position = arena.player.position + Vector2(240 + (i % 4) * 32, (i / 4 - 1) * 32)
		elif scenario == "dispersed": position = arena.player.position + Vector2(190 + (i % 4) * 95, (i / 4 - 1) * 115)
		else: position = arena.bounds.get_center() + Vector2.from_angle(float(i) * TAU / count) * Vector2(350,220)
		var enemy := arena.spawn_enemy("boss" if scenario in ["boss", "boss_mobile"] else "mob", position)
		enemy.max_health = hp
		enemy.health = hp
	elapsed = 0
	alive_seconds = 0
	frozen_seconds = 0
	slowed_seconds = 0
	suppressed_seconds = 0
	shocked_seconds = 0
	burning_seconds = 0
	active = true
	var limit := 30.0 if scenario == "survival" else 45.0
	while elapsed < limit and arena.kills < count and not arena.finished:
		await physics_frame
	active = false
	var record := {"scenario":scenario,"tier":tier,"invested":invested,"seed":run_seed,"element":element,"status_off":ablation,"ranks":ranks,"rank_cost":2*tier+(8 if invested else 0),"freeze_seconds":arena.stats.element_skill.parameter(arena.stats.element_skill.freeze_by_rank,tier) if element == "ice" else 0.0,"elapsed":elapsed,"cleared":arena.kills == count,"ttk":elapsed if arena.kills == count else null,"kills":arena.kills,"count":count,"actual_damage":arena.total_damage,"actual_burn_damage":(arena.element_procs as MeasuredProcs).actual_burn_damage,"actual_shock_bonus":arena.actual_shock_bonus,"attempted_damage":arena.attempted_damage,"overkill_waste":maxf(0,arena.attempted_damage-arena.total_damage),"hp":arena.stats.hp,"dead":arena.finished,"hits":arena.hits,"crits":arena.crits,"shatters":arena.shatters,"direct_packets":arena.direct_packets,"elemental_packets":arena.elemental_packets,"proc_counts":arena.element_procs.proc_counts.duplicate(),"alive_enemy_seconds":alive_seconds,"frozen_enemy_seconds":frozen_seconds,"slowed_enemy_seconds":slowed_seconds,"suppressed_enemy_seconds":suppressed_seconds,"shocked_enemy_seconds":shocked_seconds,"burning_enemy_seconds":burning_seconds}
	results.append(record)
	print("BALANCE ",JSON.stringify(record))
	arena.free()
	arena = null
	await process_frame

func observe() -> void:
	if not active or not is_instance_valid(arena): return
	var delta := 1.0 / 60.0
	elapsed += delta
	for enemy: EnemyActor in arena.enemies.get_children():
		if enemy.is_dead: continue
		alive_seconds += delta
		if enemy.status.is_frozen(): frozen_seconds += delta
		if enemy.status.movement_multiplier() < 1.0: slowed_seconds += delta
		if enemy.contact_damage_suppressed(): suppressed_seconds += delta
		if enemy.status.shock_remaining > 0.0: shocked_seconds += delta
		if arena.element_procs.burns.has(enemy.get_instance_id()): burning_seconds += delta

func run_micro() -> void:
	for tier in [1,3]:
		var arena := MeasuredArena.new()
		arena.practice = true
		root.add_child(arena)
		arena.apply_ranks({"ice_enchant":tier,"ice_bow":tier})
		arena.rng.seed = 7319
		arena.player.position = Vector2(arena.bounds.end.x-350,arena.bounds.get_center().y)
		arena.player.movement_enabled = false
		var enemy := arena.spawn_enemy("mob", Vector2(arena.bounds.end.x-20,arena.player.position.y))
		enemy.health = 10000
		enemy.max_health = 10000
		var frozen_frames := 0
		var freezes := 0
		var was_frozen := false
		for i in range(2700):
			await physics_frame
			if enemy.status.is_frozen():
				frozen_frames += 1
				if not was_frozen: freezes += 1
			was_frozen = enemy.status.is_frozen()
		print("ICE MICRO ", JSON.stringify({"tier":tier,"seconds":45,"shot_interval":1/(arena.stats.arrow_rate*arena.stats.attack_speed),"freeze_duration":arena.stats.element_skill.freeze_by_rank[tier],"direct_hits":arena.hits,"freezes":freezes,"frozen_seconds":frozen_frames/60.0,"shatters":arena.shatters,"actual_hp_damage":arena.total_damage}))
		arena.free()
		await process_frame
