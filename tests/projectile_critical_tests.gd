extends SceneTree
## Fixed-seed integration contracts: each actual arrow owns one crit decision.
var arena: RageArena
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)
func near(actual: float, expected: float, label: String) -> void:
	check(absf(actual - expected) < 0.001, "%s: actual=%s expected=%s" % [label, actual, expected])
func reset(ranks: Dictionary = {}) -> void:
	arena.clear_enemies()
	for node in arena.arrows.get_children(): node.free()
	arena.apply_ranks(ranks)
	arena.stats.crit_chance = 0.5
	arena.stats.shields = 0
	arena.player.position = Vector2(350, 350)
	arena.bow.attack_clock = 0.0
	arena.bow.burst_remaining = 0
	arena.bow.burst_clock = 0.0
func target(at: Vector2) -> EnemyActor:
	var enemy := arena.spawn_enemy("dummy", at)
	enemy.radius = 3.0
	enemy.max_health = 10000.0
	enemy.health = 10000.0
	return enemy
func arrows(secondary: bool = false) -> Array[BowArrow]:
	var result: Array[BowArrow] = []
	for node in arena.arrows.get_children():
		if node is BowArrow and node.secondary == secondary and not node.is_queued_for_deletion(): result.append(node)
	return result
func seed_for(pattern: Array) -> int:
	var probe := RandomNumberGenerator.new()
	for seed_value in range(1000):
		probe.seed = seed_value
		var matches := true
		for expected: bool in pattern:
			if (probe.randf() < 0.5) != expected: matches = false
		if matches: return seed_value
	check(false, "find reproducible seed")
	return 0
func relay(arrow: BowArrow, enemy: EnemyActor) -> float:
	arrow.impact_position = enemy.position
	arrow.impact_traveled = arrow.traveled
	var before := enemy.health
	arrow.enemy_hit.emit(arrow, enemy)
	return before - enemy.health

func firing_patterns_are_independent() -> void:
	for ranks: Dictionary in [{"spread_arrow": 1}, {"burst": 2}]:
		for pattern: Array in [[true, false, true], [false, true, false]]:
			reset(ranks)
			var victim := target(arena.player.position + Vector2(140, 0))
			arena.bow._physics_process(0.0)
			arena.bow.attack_clock = 100.0
			arena.bow._physics_process(arena.stats.burst_spacing * 2 + 0.001)
			var batch := arrows()
			check(batch.size() == 3, "scatter alone and burst alone each emit three arrows")
			arena.rng.seed = seed_for(pattern)
			var expected_rng := RandomNumberGenerator.new()
			expected_rng.state = arena.rng.state
			for index in range(batch.size()):
				var arrow := batch[index]
				check(not arrow.critical_resolved, "each fired projectile starts without inherited crit")
				var expected := expected_rng.randf() < 0.5
				var uncritical := 15.0 * (0.45 if ranks.has("burst") else 1.0) * arrow.damage_scale
				near(relay(arrow, victim), uncritical * (2.0 if expected else 1.0), "independent firing-pattern critical damage")
				check(arrow.critical_result == pattern[index], "individual seeded critical result")
			check(arena.rng.state == expected_rng.state, "one roll per fired arrow")
			check(arrows(true).is_empty(), "impact emits no secondary projectiles")

func burst_and_fan_are_independent() -> void:
	reset({"burst": 1, "spread_arrow": 3, "ice_enchant": 1})
	var victim := target(arena.player.position + Vector2(180, 0))
	arena.bow._physics_process(0.001)
	check(arrows().size() == 7, "first actual scheduled fan")
	arena.bow._physics_process(arena.stats.burst_spacing + 0.001)
	var batch := arrows()
	check(batch.size() == 14, "second actual burst fan")
	arena.rng.seed = 7319
	var expected_rng := RandomNumberGenerator.new()
	expected_rng.state = arena.rng.state
	var criticals := 0
	for arrow: BowArrow in batch:
		var expected := expected_rng.randf() < 0.5
		var expected_damage := 20.0 * 0.6 * arrow.damage_scale * (2.0 if expected else 1.0)
		near(relay(arrow, victim), expected_damage, "burst/fan direct B+E uses this projectile roll")
		check(arrow.critical_result == expected, "burst/fan independent seeded result")
		if arrow.critical_result: criticals += 1
	check(criticals > 0 and criticals < batch.size(), "same volley sequence has mixed outcomes")
	check(arena.rng.state == expected_rng.state, "fourteen projectiles consume fourteen rolls")

func piercing_reuses_decision() -> void:
	for expected_crit: bool in [false, true]:
		reset({"pierce": 3, "lightning_enchant": 2})
		var victims: Array[EnemyActor] = []
		for offset in [80, 160, 240, 320]: victims.append(target(arena.player.position + Vector2(offset, 0)))
		arena.bow.shoot()
		var source := arrows()[0]
		arena.rng.seed = seed_for([expected_crit, not expected_crit])
		var expected_rng := RandomNumberGenerator.new()
		expected_rng.state = arena.rng.state
		expected_rng.randf()
		source._physics_process(400.0 / source.speed)
		for i in range(victims.size()):
			var expected_damage := 25.0 * (2.0 if expected_crit else 1.0) * (1.0 if i == 0 else 0.95)
			near(10000.0 - victims[i].health, expected_damage, "piercing stable crit and one-time retention")
		check(source.hit_ids.size() == 4, "real swept piercing reaches all four victims")
		check(arena.rng.state == expected_rng.state, "piercing consumes no extra crit rolls")

func boundaries_and_packet_components() -> void:
	for chance in [0.0, 1.0]:
		reset({"dark_enchant": 2})
		arena.stats.combat_definition.total_crit_chance_cap = 1.0 # Test boundary only, production cap stays 0.6.
		arena.stats.crit_chance = chance
		for secondary: bool in [false, true]:
			var arrow := BowArrow.new()
			arrow.secondary = secondary
			arrow.damage_scale = 0.45 if secondary else 1.0
			var packet := CombatRules.resolve_projectile(arena.stats, null, arrow, arena.rng)
			var multiplier := 2.0 if chance == 1.0 else 1.0
			check(packet.crit == (chance == 1.0), "primary/custom-secondary probability boundary")
			near(packet.base_damage, 15.0 * arrow.damage_scale * multiplier, "base exactly one multiplier")
			near(packet.elemental_damage, 10.0 * arrow.damage_scale * multiplier, "element shares same result")
			near(packet.elemental_precrit, 10.0 * arrow.damage_scale, "derived source remains uncritical")
			var state := arena.rng.state
			arena.stats.crit_chance = 1.0 - chance
			var again := CombatRules.resolve_projectile(arena.stats, null, arrow, arena.rng)
			check(again.crit == packet.crit and arena.rng.state == state, "cached outcome cannot change with later chance")
			arena.stats.crit_chance = chance
			arrow.free()
	near((load("res://resources/characters/archer.tres") as CharacterDefinition).create_stats().combat_definition.total_crit_chance_cap, 0.6, "production cap not changed")

func invalid_hits_do_not_roll() -> void:
	reset()
	var victim := target(arena.player.position + Vector2(200, 0))
	arena.bow.shoot()
	var source := arrows()[0]
	var state := arena.rng.state
	source.max_range = 20.0
	source._physics_process(1.0)
	check(not source.critical_resolved and arena.rng.state == state, "miss and range expiry do not roll")
	var orphan := BowArrow.new()
	victim.is_dead = true
	arena._on_arrow_hit(orphan, victim)
	check(not orphan.critical_resolved and arena.rng.state == state, "dead target does not roll")
	victim.is_dead = false
	arena.finished = true
	arena._on_arrow_hit(orphan, victim)
	check(not orphan.critical_resolved and arena.rng.state == state, "finished run does not roll")
	arena.finished = false
	orphan.free()

func run() -> void:
	arena = RageArena.new()
	arena.practice = true
	arena.sound_enabled = false
	root.add_child(arena)
	arena.set_physics_process(false)
	arena.player.set_physics_process(false)
	arena.bow.set_physics_process(false)
	firing_patterns_are_independent()
	burst_and_fan_are_independent()
	piercing_reuses_decision()
	boundaries_and_packet_components()
	invalid_hits_do_not_roll()
	arena.free()
	await preload("res://tests/audio_teardown.gd").drain(self)
	print("PROJECTILE CRITICAL TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
