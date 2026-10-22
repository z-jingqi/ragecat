extends SceneTree
## Independent numeric oracle: do not derive expected values from production stats.
## Real bow projectiles, swept collisions, Arena damage resolution and fragments.
var checks := 0
var failures := 0
var arena: RageArena
const BURST := [1.0, 0.60, 0.45, 0.38]
const SPLIT := [0.0, 0.30, 0.45, 0.60]

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
	arena.player.position = Vector2(450, 350)
	arena.bow.attack_clock = 0.0
	arena.bow.burst_clock = 0.0
	arena.bow.burst_remaining = 0
func target(at: Vector2) -> EnemyActor:
	var enemy := arena.spawn_enemy("dummy", at)
	enemy.radius = 3.0
	return enemy
func parts() -> Array[CatArrow]:
	var result: Array[CatArrow] = []
	for node in arena.arrows.get_children():
		if node is CatArrow and node.secondary: result.append(node)
	return result
func clear_targets() -> void:
	for node in arena.enemies.get_children(): node.free()
func fire() -> Array[CatArrow]:
	target(arena.player.position + Vector2(150, 0))
	arena.bow.shoot()
	var result: Array[CatArrow] = []
	for node in arena.arrows.get_children():
		if node is CatArrow and not node.secondary: result.append(node)
	clear_targets()
	return result
func hit(arrow: CatArrow, expected: float, label: String) -> EnemyActor:
	var victim := target(arrow.position + arrow.direction * 40.0)
	var before := victim.health
	arrow._physics_process(50.0 / arrow.speed)
	near(before - victim.health, expected, label)
	return victim

func run() -> void:
	arena = RageArena.new()
	arena.practice = true
	root.add_child(arena)
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	# 27 explicit burst x fan x split combinations; independent flat/percent ranks
	# rotate with fan/split, exercising all three damage ranks in the same matrix.
	var combinations := 0
	for burst in range(1, 4):
		for fan in range(1, 4):
			for split in range(1, 4):
				combinations += 1
				var label := "burst%d fan%d split%d" % [burst, fan, split]
				reset({"burst":burst, "spread_arrow":fan, "split":split, "damage_flat":fan, "damage":split})
				var expected: float = (15.0 + 5.0 * fan) * (1.0 + 0.2 * split) * BURST[burst]
				var arrows := fire()
				check(arrows.size() == 1 + 2 * fan, label + " fan arrow count")
				for index: int in [fan, 0]:
					clear_targets()
					var scale := 1.0 if index == fan else 0.55
					var source := arrows[index]
					var old_parts := parts().size()
					hit(source, expected * scale, label + " primary index%d" % index)
					var fragments := parts()
					check(fragments.size() == old_parts + 2, label + " exactly two fragments per primary")
					if fragments.size() <= old_parts: continue
					for part_index in range(old_parts, fragments.size()):
						var fragment := fragments[part_index]
						check(fragment.secondary and fragment.max_hits == 1, label + " fragment is nonpiercing")
						clear_targets()
						hit(fragment, expected * scale * SPLIT[split], label + " fragment source%d part%d" % [index, part_index])
						check(parts().size() == old_parts + 2, label + " no recursive split")
				# Full timing through actual equipped bow, not direct shoot calls.
				reset({"burst":burst, "spread_arrow":fan, "split":split, "attack_speed":3})
				target(arena.player.position + Vector2(150, 0))
				arena.bow._physics_process(0.0)
				for tick in range(37): arena.bow._physics_process(0.01)
				check(arena.bow.active_count(false) == (burst + 1) * (1 + fan * 2), label + " timed volley count")
				check(arena.bow.burst_remaining == 0, label + " volley drains")
	check(combinations == 27, "all 27 level combinations visited")
	# Zero/unselected and all flat/percentage rank pairs: both upgrades are additive
	# to their own category, then multiplicative together; repeated rebuild is stable.
	for flat in range(4):
		for percent in range(4):
			reset({"damage_flat":flat, "damage":percent})
			arena.apply_ranks({"damage_flat":flat, "damage":percent})
			arena.stats.crit_chance = 0.0
			var expected := (15.0 + flat * 5.0) * (1.0 + percent * 0.2)
			hit(fire()[0], expected, "flat%d percent%d no burst" % [flat, percent])
	reset({})
	hit(fire()[0], 15.0, "unselected baseline")
	# Guaranteed ordinary criticals cannot bypass burst cost;
	# fragments carry flat/percent/burst/fan/split exactly once, but no critical/procs.
	for critical_chance: float in [1.0]:
		reset({"damage_flat":1, "damage":1, "burst":1, "spread_arrow":1, "split":3, "pierce":3})
		arena.stats.crit_chance = critical_chance
		var source := fire()[0]
		var victim := target(source.position + source.direction * 40.0)
		var before := victim.health
		var crits := arena.crits
		source._physics_process(50.0 / source.speed)
		near(before - victim.health, 14.4 * 0.55 * 2.0, "critical retains flat/percent/burst/side cost")
		check(arena.crits == crits + 1, "primary critical exercised")
		var fragment := parts()[0]
		clear_targets()
		victim = target(fragment.position + fragment.direction * 40.0)
		var behind := target(fragment.position + fragment.direction * 80.0)
		before = victim.health
		crits = arena.crits
		fragment._physics_process(100.0 / fragment.speed)
		near(before - victim.health, 14.4 * 0.55 * 0.60, "critical-source fragment independent noncritical damage")
		near(behind.health, behind.max_health, "fragment cannot pierce")
		check(arena.crits == crits, "fragment cannot critical even with guaranteed ordinary critical")
		check(parts().size() == 2, "fragment cannot recursively split with full upgrades")
	# Every pierce rank: first target full, every later target retained exactly once.
	for pierce in range(1, 4):
		reset({"damage_flat":1, "damage":1, "burst":1, "pierce":pierce})
		var source := fire()[0]
		var victims: Array[EnemyActor] = []
		for index in range(pierce + 1): victims.append(target(source.position + source.direction * (40.0 + 45.0 * index)))
		source._physics_process(220.0 / source.speed)
		for index in range(victims.size()):
			near(victims[index].max_health - victims[index].health, 14.4 * (1.0 if index == 0 else [0.0, 0.75, 0.85, 0.95][pierce]), "pierce%d target%d one-time retention" % [pierce, index])
	arena.free()
	print("DAMAGE COMBINATIONS: %d combinations, %d checks, %d failures" % [combinations, checks, failures])
	quit(0 if failures == 0 else 1)
