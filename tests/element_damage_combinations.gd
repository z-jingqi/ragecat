extends SceneTree
## Independent integration oracle: exercises equipped bow and swept projectiles.
## Expected values are authored from the design, never read back from runtime stats.
var arena: RageArena
var checks := 0
var failures := 0
var combinations := 0
const ELEMENTS := ["fire", "lightning", "ice", "dark"]
const BURST := [1.0, 0.60, 0.45, 0.38]
const SPLIT := [0.0, 0.30, 0.45, 0.60]
const RETAIN := [1.0, 0.75, 0.85, 0.95]

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)
func near(actual: float, expected: float, label: String) -> void:
	check(absf(actual - expected) < 0.001, "%s: actual=%s expected=%s" % [label, actual, expected])
func reset(ranks: Dictionary) -> void:
	arena.clear_enemies()
	arena.apply_ranks(ranks)
	arena.stats.crit_chance = 0.0
	arena.player.position = Vector2(350, 350)
	arena.bow.attack_clock = 0.0
	arena.bow.burst_clock = 0.0
	arena.bow.burst_remaining = 0
func target(at: Vector2) -> EnemyActor:
	var enemy := arena.spawn_enemy("dummy", at)
	enemy.radius = 3.0
	enemy.max_health = 10000.0
	enemy.health = 10000.0
	return enemy
func clear_targets() -> void:
	for node in arena.enemies.get_children(): node.free()
func parts() -> Array[CatArrow]:
	var result: Array[CatArrow] = []
	for node in arena.arrows.get_children():
		if node is CatArrow and node.secondary: result.append(node)
	return result
func fire() -> Array[CatArrow]:
	target(arena.player.position + Vector2(150, 0))
	arena.bow.shoot()
	var result: Array[CatArrow] = []
	for node in arena.arrows.get_children():
		if node is CatArrow and not node.secondary and not node.is_queued_for_deletion(): result.append(node)
	clear_targets()
	return result
func hit(arrow: CatArrow, expected: float, label: String) -> EnemyActor:
	var victim := target(arrow.position + arrow.direction * 40.0)
	var before := victim.health
	var events := [0]
	victim.damaged.connect(func(_amount: float, _critical: bool, _at: Vector2) -> void: events[0] += 1)
	var hits_before := arena.hits
	var expected_rng := RandomNumberGenerator.new()
	expected_rng.state = arena.rng.state
	expected_rng.randf()
	arrow._physics_process(50.0 / arrow.speed)
	near(before - victim.health, expected, label)
	check(events[0] == 1, label + " single damage event for B+E")
	check(arena.hits == hits_before + 1, label + " one direct hit event")
	if not arrow.secondary: check(arena.rng.state == expected_rng.state, label + " exactly one RNG roll for whole packet")
	return victim

func rank_contracts() -> void:
	for element: String in ELEMENTS:
		var enchant := element + "_enchant"
		var skill := element + "_bow"
		reset({})
		check(arena.stats.catalog.eligible({}).has(enchant), enchant + " initially offered")
		check(not arena.stats.catalog.eligible({}).has(skill), skill + " initially gated")
		for rank in range(1, 4):
			reset({enchant: rank, "damage_flat": 2, "damage": 3})
			near(arena.stats.base_damage, 40.0, enchant + " B independent of E")
			near(arena.stats.element_damage, 8.0 * rank, enchant + " global percent scales E")
			check(arena.stats.element_skill_rank == 0, enchant + " does not grant bow skill")
			check(arena.stats.catalog.eligible(arena.stats.ranks).has(skill), skill + " unlocked separately")
			check(arena.stats.catalog.eligible(arena.stats.ranks).has(enchant) == (rank < 3), enchant + " cap3")
			for other: String in ELEMENTS:
				if other != element:
					check(arena.stats.catalog.eligible(arena.stats.ranks).has(other + "_enchant"), "other enchant remains available for switching: " + other)
			reset({enchant: rank, skill: 3})
			check(not arena.stats.catalog.eligible(arena.stats.ranks).has(skill), skill + " cap3")
		reset({skill: 3})
		check(arena.stats.element_skill_rank == 0, skill + " cannot activate without enchant")
	for removed: String in ["poison", "bleed", "poison_crit", "spread", "bleed_regen"]:
		check(not arena.stats.catalog.definitions.has(removed), removed + " removed from card catalog")

func collision_matrix() -> void:
	for element: String in ELEMENTS:
		for burst in range(1, 4):
			for fan in range(1, 4):
				for split in range(1, 4):
					combinations += 1
					var label := "%s burst%d fan%d split%d" % [element, burst, fan, split]
					reset({element + "_enchant": fan, "burst": burst, "spread_arrow": fan, "split": split, "damage_flat": fan, "damage": split})
					var expected: float = (15.0 + 5.0 * fan + 5.0 * fan) * (1.0 + 0.2 * split) * BURST[burst]
					var arrows := fire()
					check(arrows.size() == 1 + 2 * fan, label + " fan count")
					for index: int in [fan, 0]:
						clear_targets()
						var scale := 1.0 if index == fan else 0.55
						var old_parts := parts().size()
						hit(arrows[index], expected * scale, label + " primary index%d" % index)
						var fragments := parts()
						check(fragments.size() == old_parts + 2, label + " two fragments")
						for part_index in range(old_parts, fragments.size()):
							var fragment := fragments[part_index]
							check(fragment.secondary and fragment.max_hits == 1, label + " nonpiercing fragment")
							clear_targets()
							hit(fragment, expected * scale * SPLIT[split], label + " fragment%d" % part_index)
							check(parts().size() == old_parts + 2, label + " no recursive split")
	check(combinations == 108, "all 108 element/burst/fan/split cases visited")

func critical_and_pierce() -> void:
	for element: String in ELEMENTS:
		for critical: bool in [false, true]:
			for pierce in range(1, 4):
				reset({element + "_enchant": 2, "damage_flat": 1, "damage": 1, "burst": 1, "pierce": pierce})
				arena.stats.crit_chance = 1.0 if critical else 0.0
				var source := fire()[0]
				var victims: Array[EnemyActor] = []
				for index in range(pierce + 1): victims.append(target(source.position + Vector2(40.0 + 45.0 * index, 0)))
				var crits_before := arena.crits
				var hits_before := arena.hits
				source._physics_process(220.0 / source.speed)
				for index in range(victims.size()):
					var expected: float = 21.6 * (2.0 if critical else 1.0) * (1.0 if index == 0 else RETAIN[pierce])
					near(victims[index].max_health - victims[index].health, expected, "%s crit%s pierce%d target%d" % [element, critical, pierce, index])
				check(arena.hits == hits_before + victims.size(), "B+E counted once per pierced target")
				check(arena.crits == crits_before + (victims.size() if critical else 0), "B+E uses one crit result")
		# Forced critical on main arrow cannot make its fragments critical.
		reset({element + "_enchant": 3, "damage": 2, "burst": 2, "spread_arrow": 1, "split": 3})
		arena.stats.crit_chance = 1.0
		var source := fire()[0]
		hit(source, 30.0 * 1.4 * 0.45 * 0.55 * 2.0, element + " side packet crit")
		var fragment := parts()[0]
		clear_targets()
		var old_crits := arena.crits
		hit(fragment, 30.0 * 1.4 * 0.45 * 0.55 * 0.60, element + " fragment packet not crit")
		check(arena.crits == old_crits, element + " fragment no crit event")

func run() -> void:
	arena = RageArena.new()
	arena.practice = true
	root.add_child(arena)
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	rank_contracts()
	collision_matrix()
	critical_and_pierce()
	arena.free()
	print("ELEMENT DAMAGE COMBINATIONS: %d combinations, %d checks, %d failures" % [combinations, checks, failures])
	await preload("res://tests/audio_teardown.gd").drain(self)
	quit(0 if failures == 0 else 1)
