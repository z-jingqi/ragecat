extends SceneTree
## Controlled rank-budget fixtures, NOT normal-run progression or human survival.
## Actual 60-Hz engine projectile, proc, movement, damage and status callbacks.
## No manual gameplay ticks. Static fixtures disable AI, not knockback/gravity.
## Pressure fixtures deliberately use a stationary vulnerable player; campaigns with
## actual offers and moving controllers belong to run_pacing_balance_bench.gd.
## --scenario=static_boss|dense|pressure|mountainbreaker|beastcaller|wildfire
## --seeds=3 --out=/tmp/budget.json ; no filter runs the complete bounded matrix.
## --budget=24 --element=fire --optimize-inactive-pierce runs a paired allocation
## diagnostic: fire replaces inactive pierce with fan; dark replaces it with pull.
## The pressure fixture contains a distant ranged unit: clear can be censored by
## reach, so survival, HP and kills must be reported separately from clear time.
class MeasuredArena extends RageArena:
	var attempted := 0.0
	var physical := 0.0
	var elemental := 0.0
	var damage_sources: Dictionary = {}
	func deal_damage_packet(enemy: EnemyActor, packet: Dictionary, event: FeedbackEvent = null) -> void:
		if not is_instance_valid(enemy) or enemy.is_dead: return
		var before := enemy.health
		var b := float(packet.get("base_damage", 0.0))
		var e := float(packet.get("elemental_damage", 0.0)) * enemy.status.elemental_multiplier()
		var nominal := float(packet.damage) + e - float(packet.get("elemental_damage", 0.0))
		attempted += nominal
		super.deal_damage_packet(enemy, packet, event)
		var actual := before - enemy.health
		if nominal > 0.0:
			physical += actual * b / nominal
			elemental += actual * e / nominal
		var key := str(event.source) if event != null else "unknown"
		damage_sources[key] = float(damage_sources.get(key, 0.0)) + actual

const SEEDS := [7319,38117,91073]
const ELEMENTS := ["physical","fire","lightning","ice","dark"]
const SCENARIOS := ["static_boss","dense","pressure","mountainbreaker","beastcaller","wildfire"]
var results: Array[Dictionary] = []
var arena: MeasuredArena
var out := "/tmp/equal-budget-balance.json"
var scenario_filter := ""
var seed_count := 3
var optimize_inactive_pierce := false
var only_budget := 0
var only_element := ""
var active := false
var elapsed := 0.0
var enemy_seconds := 0.0
var suppressed_seconds := 0.0
var incoming := 0.0
var shield_blocks := 0
var pressure_peak := 0
var failures := 0
var source_snapshot: Dictionary = {}

func _initialize() -> void: call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("BUDGET BENCH: " + message)

func run() -> void:
	source_snapshot = source_hashes()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
		if arg.begins_with("--scenario="): scenario_filter = arg.trim_prefix("--scenario=")
		if arg == "--optimize-inactive-pierce": optimize_inactive_pierce = true
		if arg.begins_with("--budget="): only_budget = int(arg.trim_prefix("--budget="))
		if arg.begins_with("--element="): only_element = arg.trim_prefix("--element=")
		if arg.begins_with("--seeds="): seed_count = clampi(int(arg.trim_prefix("--seeds=")),1,SEEDS.size())
	check(scenario_filter.is_empty() or scenario_filter in SCENARIOS,"valid scenario")
	check(only_budget in [0,6,12,24],"valid budget")
	check(only_element.is_empty() or only_element in ELEMENTS,"valid element")
	if failures: quit(1); return
	physics_frame.connect(observe)
	for scenario: String in SCENARIOS:
		if not scenario_filter.is_empty() and scenario_filter != scenario: continue
		for budget: int in [6,12,24]:
			if only_budget > 0 and only_budget != budget: continue
			var profiles := ["damage"]
			if budget == 12: profiles.append_array(["volley","pierce_crit","defense","mobility"])
			for profile: String in profiles:
				for run_seed: int in SEEDS.slice(0,seed_count):
					for element: String in ELEMENTS:
						if not only_element.is_empty() and only_element != element: continue
						await trial(scenario,budget,profile,run_seed,element)
	var file := FileAccess.open(out,FileAccess.WRITE)
	if file == null: check(false,"output writable")
	else:
		file.store_string(JSON.stringify({"method":"Post-impact-split retirement allocations; not comparable to historical split-enabled profiles. Equal total upgrade ranks including enchant and mastery; all ranks <=3. Practice fixture grants intentionally separate from real offered progression. Stationary vulnerable pressure player, AI-off static isolation retains external forces. Actual engine at fixed60Hz, time_scale1. Explicit per-case caps; null TTK is censored, never assigned cap. Damage excludes overkill; no manual gameplay ticks.","source_hashes":source_snapshot,"engine":Engine.get_version_info(),"failures":failures,"results":results},"\t"))
	print("BUDGET COMPLETE ",results.size()," failures ",failures," ",out)
	quit(1 if failures else 0)

func build(element: String,budget: int,profile: String) -> Dictionary:
	var ranks: Dictionary
	if element == "physical":
		match budget:
			6: ranks = {"damage_flat":3,"attack_speed":3}
			12: ranks = {"damage_flat":3,"attack_speed":3,"damage":3,"crit_chance":3}
			_: ranks = {"damage_flat":3,"attack_speed":3,"damage":3,"crit_chance":3,"burst":3,"spread_arrow":3,"crit_damage":3,"pierce":3}
		if profile != "damage": ranks = {"damage_flat":3,"attack_speed":3,"damage":2}
	else:
		match budget:
			6: ranks = {element+"_enchant":1,element+"_bow":1,"damage_flat":2,"attack_speed":2}
			12: ranks = {element+"_enchant":2,element+"_bow":2,"damage_flat":3,"attack_speed":3,"damage":2}
			_: ranks = {element+"_enchant":3,element+"_bow":3,"damage_flat":3,"attack_speed":3,"damage":3,"burst":3,"long_draw":3,"pierce":3}
		if profile != "damage": ranks = {element+"_enchant":2,element+"_bow":2,"damage_flat":2,"attack_speed":2}
	match profile:
		"volley": ranks.merge({"burst":2,"spread_arrow":2})
		"pierce_crit": ranks.merge({"pierce":2,"crit_damage":2})
		"defense": ranks.merge({"shield":2,"regen":2})
		"mobility": ranks.merge({"knockback":2,"move_speed":2})
	# Paired swap: inactive penetration is retained in the compatibility matrix,
	# but not falsely treated as an optimal fire/dark damage allocation.
	if optimize_inactive_pierce and element in ["fire","dark"] and ranks.has("pierce"):
		var replacement := "spread_arrow" if element == "fire" else "knockback"
		ranks[replacement] = ranks.pierce
		ranks.erase("pierce")
	var catalog := UpgradeCatalog.new()
	for key: String in ranks: check(catalog.definition(key) != null, "valid allocated upgrade: " + key)
	var cost := 0
	for value in ranks.values():
		cost += int(value)
		check(int(value) >= 1 and int(value) <= 3,"legal rank")
	check(cost == budget,"equal investment: "+element+" "+profile)
	return ranks

func trial(scenario: String,budget: int,profile: String,run_seed: int,element: String) -> void:
	seed(run_seed)
	arena = MeasuredArena.new()
	arena.practice = true
	arena.sound_enabled = false
	arena.run_seed_override = run_seed
	arena.lab_ai = scenario not in ["static_boss","dense"]
	root.add_child(arena)
	var ranks := build(element,budget,profile)
	arena.apply_ranks(ranks)
	var normalized_cost := 0
	for key: String in arena.ranks:
		if key != "element_type": normalized_cost += int(arena.ranks[key])
	check(normalized_cost == budget,"normalized ranks preserve purchased budget")
	# Fixture starts with purchased shield charges, as acquisition would grant them.
	arena.stats.shields = arena.stats.shield_capacity
	arena.stats.hp = arena.stats.max_hp
	arena.player.movement_enabled = false
	arena.player.invulnerable = not arena.lab_ai
	arena.player.position = arena.bounds.get_center() - Vector2(220,0)
	elapsed = 0.0
	enemy_seconds = 0.0
	suppressed_seconds = 0.0
	incoming = 0.0
	shield_blocks = 0
	pressure_peak = 0
	arena.player.hit_feedback.connect(func(kind: String,amount: float) -> void:
		if kind in ["block","break"]: shield_blocks += 1
		else: incoming += amount
	)
	# Campaign identities have their real encounter-index health scaling.
	if scenario == "beastcaller": arena.director.boss_count = 1
	if scenario == "wildfire": arena.director.boss_count = 2
	var initial_target_hp := 0.0
	var target: EnemyActor
	var count := 1 if scenario not in ["dense","pressure"] else (24 if scenario == "pressure" else 12)
	for i in range(count):
		var location := arena.player.position + Vector2(260,0)
		var kind := scenario if scenario in ["mountainbreaker","beastcaller","wildfire"] else "mountainbreaker"
		if scenario == "dense":
			location = arena.player.position + Vector2(240+(i%4)*32,(i/4-1)*32)
			kind = "mob"
		elif scenario == "pressure":
			location = arena.bounds.get_center() + Vector2.from_angle(float(i)*TAU/count)*Vector2(350,220)
			kind = "ranged" if i%6 == 0 else ("swiftfang" if i%4 == 0 else "mob")
		var enemy := arena.spawn_enemy(kind,location)
		check(enemy != null,"fixture spawned")
		if enemy == null: continue
		# Same HP across build comparisons; density uses mature-wave HP, not one-hit strawmen.
		if scenario in ["dense","pressure"]:
			enemy.max_health = 120.0 * (0.6 if kind == "ranged" else (0.55 if kind == "swiftfang" else 1.0))
			enemy.health = enemy.max_health
		else:
			target = enemy
			# Restore natural half-health transition after practice's default forced phase.
			(enemy as BossActor)._forced_phase = 0
			if scenario == "static_boss":
				enemy.max_health = 1200.0
				enemy.health = enemy.max_health
		initial_target_hp += enemy.health
	var cap := 30.0 if scenario in ["dense","pressure"] else 60.0
	var wall_start := Time.get_ticks_msec()
	active = true
	var cleared := false
	while elapsed < cap and not arena.finished:
		await physics_frame
		cleared = (not is_instance_valid(target) or target.is_dead) if count == 1 else arena.kills >= count
		if cleared: break
		if Time.get_ticks_msec()-wall_start > 180000:
			check(false,"wall watchdog")
			break
	active = false
	check(is_equal_approx(arena.physical+arena.elemental,arena.total_damage),"damage component conservation")
	var record := {"scenario":scenario,"initial_target_hp":initial_target_hp,"budget":budget,"profile":profile,"seed":run_seed,"element":element,"ranks":ranks,"optimized_inactive_pierce":optimize_inactive_pierce,"elapsed":elapsed,"cap":cap,"cleared":cleared,"ttk":elapsed if cleared else null,"dead":arena.finished,"kills":arena.kills,"actual_damage":arena.total_damage,"physical_damage":arena.physical,"elemental_damage":arena.elemental,"attempted_damage":arena.attempted,"overkill":maxf(0,arena.attempted-arena.total_damage),"damage_sources":arena.damage_sources,"hp":arena.stats.hp,"max_hp":arena.stats.max_hp,"incoming_damage":incoming,"healed":arena.player.healed_total,"shield_blocks":shield_blocks,"remaining_shields":arena.stats.shields,"alive_enemy_seconds":enemy_seconds,"suppressed_enemy_seconds":suppressed_seconds,"pressure_peak":pressure_peak,"hits":arena.hits,"crits":arena.crits,"proc_counts":arena.element_procs.proc_counts.duplicate(),"boss_phase":target.phase_number if is_instance_valid(target) else 0}
	results.append(record)
	print("BUDGET ",JSON.stringify(record))
	arena.free()
	arena = null
	await process_frame

func observe() -> void:
	if not active or not is_instance_valid(arena): return
	var delta := 1.0/60.0
	elapsed += delta
	var living := 0
	for enemy: EnemyActor in arena.enemies.get_children():
		if enemy.is_dead: continue
		living += 1
		enemy_seconds += delta
		if enemy.contact_damage_suppressed(): suppressed_seconds += delta
	pressure_peak = maxi(pressure_peak,living)

func source_hashes() -> Dictionary:
	var hashes: Dictionary = {}
	for directory: String in ["scripts","resources","scenes"]:
		_hash_directory("res://"+directory, hashes)
	hashes["project.godot"] = FileAccess.get_sha256("res://project.godot")
	hashes["tests/equal_budget_balance_bench.gd"] = FileAccess.get_sha256("res://tests/equal_budget_balance_bench.gd")
	return hashes

func _hash_directory(path: String, hashes: Dictionary) -> void:
	for name: String in DirAccess.get_files_at(path):
		var full := path.path_join(name)
		hashes[full.trim_prefix("res://")] = FileAccess.get_sha256(full)
	for name: String in DirAccess.get_directories_at(path):
		_hash_directory(path.path_join(name), hashes)
