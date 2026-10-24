extends SceneTree
## Real collision/real health tests, independent of controller implementation.
var arena: RageArena
var checks := 0
var failures := 0
const ELEMENTS := ["fire", "lightning", "ice", "dark"]
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
	arena.bow.remove_gravity(true)
	arena.apply_ranks(ranks)
	arena.stats.crit_chance = 0.0
	# Keep original packet/chain baselines deterministic; shock has its own suite.
	if arena.stats.element_skill != null:
		arena.stats.element_skill.shock_chance_by_rank = PackedFloat32Array([0, 0, 0, 0])
	arena.player.position = Vector2(350, 350)
	arena.bow.burst_remaining = 0
func target(at: Vector2) -> EnemyActor:
	var enemy := arena.spawn_enemy("dummy", at)
	enemy.radius = 3.0
	enemy.max_health = 10000.0
	enemy.health = 10000.0
	return enemy
func fire(side: bool = false) -> BowArrow:
	var bait := target(arena.player.position + Vector2(150, 0))
	arena.bow.shoot()
	bait.free()
	var result: BowArrow
	for node in arena.arrows.get_children():
		if node is BowArrow and not node.secondary and not node.is_queued_for_deletion():
			if result == null or (not side and node.damage_scale == 1.0): result = node
	return result
func fragments() -> Array[BowArrow]:
	var result: Array[BowArrow] = []
	for node in arena.arrows.get_children():
		if node is BowArrow and node.secondary: result.append(node)
	return result
func step(arrow: BowArrow, distance: float) -> void: arrow._physics_process(distance / arrow.speed)
func damage(enemy: EnemyActor) -> float: return enemy.max_health - enemy.health
func skillless_enchants() -> void:
	for element: String in ELEMENTS:
		reset({element + "_enchant": 3})
		var source := fire()
		var victim := target(source.position + Vector2(40, 0))
		var nearby := target(victim.position + Vector2(0, 35))
		var at := nearby.position
		var before_procs: Dictionary = arena.element_procs.proc_counts.duplicate()
		step(source, 50)
		near(damage(victim), 30.0, element + " enchant adds flat damage only")
		near(damage(nearby), 0.0, element + " no derived damage without skill")
		check(nearby.position == at, element + " no immediate pull without skill")
		near(victim.status.movement_multiplier(), 1.0, element + " no chill without skill")
		check(arena.element_procs.proc_counts == before_procs, element + " enchant alone triggers no skill")

func fire_and_lightning() -> void:
	for element: String in ["fire", "lightning"]:
		for rank in range(1, 4):
			for side: bool in [false, true]:
				reset({element + "_enchant": 2, element + "_bow": rank, "damage_flat": 3, "damage": 2, "burst": 2, "spread_arrow": 1, "pierce": 3})
				arena.stats.combat_definition.total_crit_chance_cap = 1.0 # Isolate critical damage formula, not production chance.
				arena.stats.crit_chance = 1.0
				var source := fire(side)
				var scale := 0.55 if side else 1.0
				var primary := target(source.position + source.direction * 40.0)
				var secondary := target(source.position + source.direction * 100.0)
				var events := [0, 0]
				primary.damaged.connect(func(_amount: float, _crit: bool, _at: Vector2) -> void: events[0] += 1)
				secondary.damaged.connect(func(_amount: float, crit: bool, _at: Vector2) -> void:
					events[1] += 1
					if events[1] == 1: check(not crit, element + " derived never crit"))
				var crits_before := arena.crits
				var hits_before := arena.hits
				step(source, 50)
				var direct := 40.0 * 1.4 * 0.45 * scale * 2.0
				var derived: float = 10.0 * 1.4 * 0.45 * scale * ([0.0, 1.0, 1.5, 2.0][rank] if element == "fire" else 1.0)
				near(damage(primary), direct, element + " excludes primary from derived damage")
				near(damage(secondary), derived, element + " E only with burst/fan once, no crit")
				check(events == [1, 1], element + " exactly one direct plus one derived event")
				check(arena.hits == hits_before + 1 and arena.crits == crits_before + 1, element + " derived does not increment direct proc counters")
				check(source.can_hit(secondary.get_instance_id()) == (element != "fire"), element + " mode controls later direct eligibility")
				# A fresh witness is outside first impact radius / hop range. It becomes
				# adjacent to second direct impact, proving no second blast/chain.
				var witness := target(secondary.position + source.direction.orthogonal() * 35.0)
				step(source, 60)
				near(damage(secondary), derived + (direct * 0.95 if element != "fire" else 0.0), element + " later direct hit retains B+E once")
				near(damage(witness), derived * 0.95 if element == "lightning" else 0.0, element + " lightning chains again on piercing hit")
				check(events == ([2, 2] if element != "fire" else [1, 1]), element + " separated direct and derived dedup")
		# Lethal first direct hit still resolves extra effect at captured hit location.
		reset({element + "_enchant": 1, element + "_bow": 1})
		var source := fire()
		var primary := target(source.position + Vector2(40, 0))
		primary.health = 1.0
		var nearby := target(primary.position + Vector2(0, 35))
		step(source, 50)
		check(primary.is_dead, element + " lethal setup exercised")
		near(damage(nearby), 5.0, element + " lethal first hit still procs")
		reset({element + "_enchant": 3, element + "_bow": 3})
		source = fire()
		nearby = target(source.position + Vector2(0, 50))
		source.max_range = 30.0
		step(source, 100)
		near(damage(nearby), 0.0, element + " range end without hit produces no extras")

func chain_geometry() -> void:
	for rank in range(1, 4):
		reset({"lightning_enchant": 1, "lightning_bow": rank})
		var source := fire()
		var primary := target(source.position + Vector2(40, 0))
		var victims: Array[EnemyActor] = []
		for index in range(6): victims.append(target(primary.position + Vector2(100.0 * (index + 1), 0)))
		step(source, 50)
		near(damage(primary), 20.0, "chain origin is not an extra target")
		for index in range(victims.size()):
			near(damage(victims[index]), 5.0 if index < rank + 1 else 0.0, "chain rank%d unique hop%d" % [rank, index])
	reset({"lightning_enchant": 1, "lightning_bow": 3})
	var source := fire()
	var primary := target(source.position + Vector2(40, 0))
	var outside := target(primary.position + Vector2(0, 141))
	step(source, 50)
	near(damage(outside), 0.0, "chain cannot cross >140 first hop")

func impact_spawning_removed() -> void:
	for element: String in ELEMENTS:
		reset({element + "_enchant": 3, element + "_bow": 3, "spread_arrow": 3, "burst": 3})
		var source := fire()
		target(source.position + source.direction * 40)
		step(source, 50)
		check(fragments().is_empty(), element + " impact and element proc create no arrows")

func fire_radius_and_custom_resources() -> void:
	for rank in range(1, 4):
		reset({"fire_enchant": 1, "fire_bow": rank})
		var source := fire()
		var primary := target(source.position + Vector2(40, 0))
		var contact := primary.position - Vector2(primary.radius + source.width, 0)
		var radius: float = [0.0, 70.0, 85.0, 100.0][rank]
		var inside := target(contact + Vector2(0, radius - 0.01))
		var outside := target(contact + Vector2(0, -radius - 0.01))
		step(source, 50)
		near(damage(inside), 5.0 * [0.0, 1.0, 1.5, 2.0][rank], "fire rank%d radius includes inside" % rank)
		near(damage(outside), 0.0, "fire rank%d radius excludes outside" % rank)
		near(damage(primary), 20.0, "fire radius still excludes primary")
	var original: CharacterDefinition = arena.stats.character
	var custom := original.duplicate(true) as CharacterDefinition
	custom.upgrades = []
	for definition: UpgradeDefinition in UpgradeCatalog.UPGRADES:
		var item := definition.duplicate(true) as UpgradeDefinition
		if definition.element_skill != null: item.element_skill = definition.element_skill.duplicate(true) as ElementSkillDefinition
		if item.upgrade_id == "fire_enchant": item.values = PackedFloat32Array([0, 7, 14, 21])
		if item.upgrade_id == "fire_bow":
			item.element_skill.radius_by_rank = PackedFloat32Array([0, 25, 30, 35])
			item.element_skill.damage_by_rank = PackedFloat32Array([0, 2, 3, 4])
		custom.upgrades.append(item)
	arena.stats.character = custom
	reset({"fire_enchant": 1, "fire_bow": 1})
	var source := fire()
	var primary := target(source.position + Vector2(40, 0))
	var contact := primary.position - Vector2(primary.radius + source.width, 0)
	var inside := target(contact + Vector2(0, 24))
	var outside := target(contact + Vector2(0, -26))
	step(source, 50)
	near(damage(primary), 22.0, "custom enchant resource alters actual direct packet")
	near(damage(inside), 14.0, "custom fire multiplier alters actual derived damage")
	near(damage(outside), 0.0, "custom radius alters actual targeting")
	arena.stats.character = original
	reset({"fire_enchant": 1, "fire_bow": 1})
	near(arena.stats.element_damage, 5.0, "custom run does not mutate original enchant")
	near(arena.stats.element_skill.radius_by_rank[1], 70.0, "custom run does not mutate original skill")

func dark_first_hit_and_cleanup() -> void:
	reset({"dark_enchant": 1, "dark_bow": 1, "pierce": 3})
	var source := fire()
	check(is_instance_valid(source.gravity_field), "gravity field exists from launch without a hit")
	var start := source.gravity_field.global_position
	step(source, 20)
	check(source.gravity_field.global_position.x > start.x, "field follows arrow tip")
	arena.bow.shoot()
	check(arena.bow.active_count(false) == 1, "only one gravity arrow")
	arena.select_upgrade("fire_enchant")
	check(source.retired, "switch retires gravity arrow")
	near(arena.bow.gravity_gap_remaining, 0.5, "removal starts full gap")

func dark_knockback_policy() -> void:
	for has_skill: bool in [false, true]:
		reset({"dark_enchant": 3, "dark_bow": 3 if has_skill else 0, "knockback": 3})
		var source := fire()
		if has_skill: source.gravity_field.damage_per_second = 0.0
		var victim := target(source.position + source.direction * 40.0)
		victim.is_dummy = false
		var before := victim.position
		step(source, 50)
		near(damage(victim), 30.0, "dark direct damage skill=%s" % has_skill)
		if has_skill:
			near(victim.knockback_remaining, 0.0, "dark skill suppresses outward direct knockback without disabling gravity")
		else:
			victim._physics_process(victim.feedback_definition.knockback_duration)
			check((victim.position - before).dot(source.direction) > 0.0, "dark enchant alone retains direct knockback")
		check(fragments().is_empty(), "dark impact never creates arrows")

func run() -> void:
	arena = RageArena.new()
	arena.practice = true
	root.add_child(arena)
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	skillless_enchants()
	fire_and_lightning()
	chain_geometry()
	impact_spawning_removed()
	dark_first_hit_and_cleanup()
	fire_radius_and_custom_resources()
	dark_knockback_policy()
	arena.free()
	print("ELEMENT PROC COMBINATIONS: %d checks, %d failures" % [checks, failures])
	await preload("res://tests/audio_teardown.gd").drain(self)
	quit(0 if failures == 0 else 1)
