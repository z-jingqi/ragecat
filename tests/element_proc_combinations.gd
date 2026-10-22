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
	arena.apply_ranks(ranks)
	arena.stats.crit_chance = 0.0
	arena.player.position = Vector2(350, 350)
	arena.bow.burst_remaining = 0
func target(at: Vector2) -> EnemyActor:
	var enemy := arena.spawn_enemy("dummy", at)
	enemy.radius = 3.0
	enemy.max_health = 10000.0
	enemy.health = 10000.0
	return enemy
func fire(side: bool = false) -> CatArrow:
	var bait := target(arena.player.position + Vector2(150, 0))
	arena.bow.shoot()
	bait.free()
	var result: CatArrow
	for node in arena.arrows.get_children():
		if node is CatArrow and not node.secondary and not node.is_queued_for_deletion():
			if result == null or (not side and node.damage_scale == 1.0): result = node
	return result
func fragments() -> Array[CatArrow]:
	var result: Array[CatArrow] = []
	for node in arena.arrows.get_children():
		if node is CatArrow and node.secondary: result.append(node)
	return result
func step(arrow: CatArrow, distance: float) -> void: arrow._physics_process(distance / arrow.speed)
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
				check(source.can_hit(secondary.get_instance_id()), element + " derived target remains eligible for direct arrow")
				# A fresh witness is outside first impact radius / hop range. It becomes
				# adjacent to second direct impact, proving no second blast/chain.
				var witness := target(secondary.position + source.direction.orthogonal() * 35.0)
				step(source, 60)
				near(damage(secondary), derived + direct * 0.95, element + " later direct hit retains B+E once")
				near(damage(witness), 0.0, element + " no repeated proc on piercing hit")
				check(events == [1, 2], element + " separated direct and derived dedup")
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

func fragment_suppression() -> void:
	for element: String in ELEMENTS:
		reset({element + "_enchant": 3, element + "_bow": 3, "split": 3})
		var source := fire()
		target(source.position + Vector2(40, 0))
		step(source, 50)
		var fragments_now := fragments()
		check(fragments_now.size() == 2, element + " fragments created")
		if fragments_now.is_empty(): continue
		for node in arena.enemies.get_children(): node.free()
		var fragment := fragments_now[0]
		var victim := target(fragment.position + fragment.direction * 40.0)
		var witness := target(victim.position + fragment.direction.orthogonal() * 35.0)
		var before_procs: Dictionary = arena.element_procs.proc_counts.duplicate()
		step(fragment, 50)
		check(arena.element_procs.proc_counts == before_procs, element + " fragment never triggers any skill")
		near(damage(victim), 18.0, element + " fragment retains B+E")
		near(damage(witness), 0.0, element + " fragment never causes derived damage")
		near(victim.status.movement_multiplier(), 1.0, element + " fragment never chills")
		check(fragments().size() == 2, element + " fragment never recursively splits")

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
	arena.element_procs.dark_cooldown = 1.0
	var source := fire()
	var first := target(source.position + Vector2(40, 0))
	var second := target(source.position + Vector2(100, 0))
	var old_count: int = arena.element_procs.proc_counts.dark
	step(source, 50)
	near(damage(first), 20.0, "dark cooldown still allows ordinary damage")
	check(arena.element_procs.proc_counts.dark == old_count, "dark first hit denied by shared cooldown")
	arena.element_procs.dark_cooldown = 0.0
	step(source, 60)
	near(damage(second), 19.0, "dark piercing direct damage retained")
	check(arena.element_procs.proc_counts.dark == old_count, "dark cannot fall back to later piercing hit")
	check(not is_instance_valid(arena.element_procs.active_vortex), "denied arrow creates no later vortex")
	for node in arena.enemies.get_children(): node.free()
	# Remove the old still-piercing arrow before acquiring the next real shot.
	for node in arena.arrows.get_children(): node.free()
	source = fire()
	var primary := target(source.position + Vector2(40, 0))
	step(source, 50)
	check(arena.element_procs.proc_counts.dark == old_count + 1, "fresh arrow can proc after cooldown")
	var vortex = arena.element_procs.active_vortex
	check(is_instance_valid(vortex), "fresh dark hit creates vortex")
	near(damage(primary), 20.0, "dark vortex itself adds no damage")
	var fixed_at: Vector2 = vortex.position
	primary.position += Vector2(35, 0)
	check(vortex.position == fixed_at, "dark vortex remains at original hit position")
	near(arena.element_procs.dark_cooldown, 2.5, "dark skill starts shared2.5s cooldown")
	arena.element_procs.dark_cooldown = 0.0
	for node in arena.arrows.get_children(): node.free()
	source = fire()
	for node in arena.enemies.get_children(): node.free()
	target(source.position + Vector2(40, 0))
	step(source, 50)
	check(arena.element_procs.proc_counts.dark == old_count + 1, "active vortex prevents another even if cooldown expired")
	check(arena.element_procs.active_vortex == vortex, "only original vortex remains")
	arena.select_upgrade("fire_enchant")
	check(not is_instance_valid(arena.element_procs.active_vortex), "switch clears active vortex")

func dark_fragment_knockback_policy() -> void:
	for has_skill: bool in [false, true]:
		reset({"dark_enchant": 3, "dark_bow": 3 if has_skill else 0, "split": 3})
		var source := fire()
		target(source.position + Vector2(40, 0))
		step(source, 50)
		var fragment := fragments()[0]
		for node in arena.enemies.get_children(): node.free()
		var victim := target(fragment.position + fragment.direction * 40.0)
		victim.is_dummy = false
		var before := victim.position
		var old_count: int = arena.element_procs.proc_counts.dark
		step(fragment, 50)
		near(damage(victim), 18.0, "dark fragment damage with skill%s" % has_skill)
		if has_skill:
			check(victim.position == before, "dark skill suppresses fragment outward knockback build-wide")
		else:
			check((victim.position - before).dot(fragment.direction) > 0.0, "dark enchant alone retains fragment knockback")
		check(arena.element_procs.proc_counts.dark == old_count, "dark fragment never creates its own vortex")

func run() -> void:
	arena = RageArena.new()
	arena.practice = true
	root.add_child(arena)
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	skillless_enchants()
	fire_and_lightning()
	chain_geometry()
	fragment_suppression()
	dark_first_hit_and_cleanup()
	fire_radius_and_custom_resources()
	dark_fragment_knockback_policy()
	arena.free()
	print("ELEMENT PROC COMBINATIONS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
