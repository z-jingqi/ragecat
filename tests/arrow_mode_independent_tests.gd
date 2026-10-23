extends SceneTree
## Independent end-to-end collision checks. Direct-hit signals are counted
## separately from health loss, since legitimate splash may hit a later target.
var arena: RageArena
var checks := 0
var failures := 0
var direct: Array[Dictionary] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("ARROW MODE: " + label)
func near(actual: float, expected: float, label: String) -> void:
	check(absf(actual - expected) < 0.02, "%s actual=%s expected=%s" % [label, actual, expected])
func setup(ranks: Dictionary) -> void:
	if is_instance_valid(arena): arena.free()
	arena = RageArena.new()
	arena.practice = true
	root.add_child(arena)
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	arena.apply_ranks(ranks)
	arena.stats.crit_chance = 0.0
	# Isolate original mode damage coefficients; shock is tested independently.
	if arena.stats.element_skill != null:
		arena.stats.element_skill.shock_chance_by_rank = PackedFloat32Array([0, 0, 0, 0])
	arena.player.position = Vector2(300, 350)
	direct.clear()
	arena.bow.arrow_hit.connect(func(arrow: BowArrow, enemy: EnemyActor) -> void:
		direct.append({"arrow": arrow.get_instance_id(), "enemy": enemy.get_instance_id()}))
func target(at: Vector2) -> EnemyActor:
	var enemy := arena.spawn_enemy("dummy", at)
	enemy.position = at
	enemy.radius = 3.0
	enemy.max_health = 100000.0
	enemy.health = enemy.max_health
	return enemy
func shoot() -> BowArrow:
	var bait := target(arena.player.position + Vector2(100, 0))
	arena.bow.shoot()
	bait.free()
	for node in arena.arrows.get_children():
		if node is BowArrow and not node.secondary and not node.retired: return node
	return null
func step(arrow: BowArrow, distance: float) -> void:
	arrow._physics_process(distance / arrow.speed)
func fragments() -> Array[BowArrow]:
	var result: Array[BowArrow] = []
	for node in arena.arrows.get_children():
		if node is BowArrow and node.secondary: result.append(node)
	return result
func loss(enemy: EnemyActor) -> float: return enemy.max_health - enemy.health
func dark_unlimited() -> void:
	for skill in range(1, 4):
		for pierce in range(4):
			setup({"dark_enchant": 1, "dark_bow": skill, "pierce": pierce, "burst": 3, "spread_arrow": 3, "split": 3})
			var arrow := shoot()
			arrow.gravity_field.damage_per_second = 0.0 # Isolate direct B+E.
			var victims: Array[EnemyActor] = []
			for i in range(8): victims.append(target(arrow.position + Vector2(30 + i * 25, 0)))
			step(arrow, 225)
			check(direct.size() == 8, "dark skill%d pierce%d hits all eight" % [skill, pierce])
			for victim in victims: near(loss(victim), 20.0, "every dark direct hit retains full B+E")
			check(not arrow.retired, "dark never retires because of hit count")
			arrow.direction = Vector2.LEFT
			step(arrow, 220)
			check(direct.size() == 8, "return sweep cannot hit same enemy again")
			for victim in victims: near(loss(victim), 20.0, "revisited dark targets take no second packet")
			arena.bow._physics_process(10.0)
			check(arena.bow.active_count(false) == 1 and fragments().is_empty(), "dark has no fan burst or fragments")
			check(int(arena.ranks.get("pierce", 0)) == pierce, "dark preserves purchased pierce rank")
	for ending in ["range", "lifetime", "boundary"]:
		setup({"dark_enchant": 1, "dark_bow": 1, "pierce": 3})
		var arrow := shoot()
		arrow.gravity_field.damage_per_second = 0.0
		var start := arrow.position
		var limit := 80.0
		if ending == "range": arrow.max_range = limit
		elif ending == "lifetime": arrow.lifetime_remaining = limit / arrow.speed
		else: arrow.arena_bounds = Rect2(Vector2.ZERO, Vector2(start.x + limit, 800))
		var inside := target(start + Vector2(40, 0))
		var beyond := target(start + Vector2(limit + arrow.width + 3.1, 0))
		step(arrow, 1000)
		near(loss(inside), 20.0, ending + " resolves valid in-range target")
		near(loss(beyond), 0.0, ending + " does not reach beyond terminal sweep")
		check(arrow.retired and not arrow.gravity_field.is_active(), ending + " removes field and projectile")
		near(arena.bow.gravity_gap_remaining, 0.5, ending + " starts post-arrow gap")
		step(arrow, 1000)
		check(direct.size() == 1, ending + " retired arrow never ghost-hits")
func fire_matrix() -> void:
	var combinations := 0
	for pierce in range(4):
		for burst in range(4):
			for fan in range(4):
				for split in range(4):
					combinations += 1
					setup({"fire_enchant": 2, "fire_bow": 3, "pierce": pierce, "burst": burst, "spread_arrow": fan, "split": split, "damage_flat": 3, "damage": 2})
					arena.stats.combat_definition.total_crit_chance_cap = 1.0 # Isolate critical damage formula, not production chance.
					arena.stats.crit_chance = 1.0
					var arrow := shoot()
					var primary := target(arrow.position + arrow.direction * 40)
					var second := target(arrow.position + arrow.direction * 85)
					var scale := arena.stats.burst_damage_multiplier * arrow.damage_scale
					var expected_direct := 40.0 * 1.4 * scale * 2.0
					var expected_blast := 10.0 * 1.4 * scale * 2.0
					step(arrow, 150)
					check(direct.size() == 1 and direct[0].enemy == primary.get_instance_id(), "fire first direct only p%d b%d f%d s%d" % [pierce, burst, fan, split])
					near(loss(primary), expected_direct, "fire excludes direct primary from its blast")
					near(loss(second), expected_blast, "second aligned target takes only E blast, no B or crit")
					check(arrow.retired and arena.element_procs.proc_counts.fire == 1, "one main blast then removal")
					check(int(arena.ranks.get("pierce", 0)) == pierce, "fire preserves pierce purchase")
					step(arrow, 150)
					check(direct.size() == 1 and arena.element_procs.proc_counts.fire == 1, "retired fire cannot repeat impact or blast")
					var children := fragments()
					check(children.size() == (0 if split == 0 else 2), "only original main impact spawns fragments")
					if split == 0: continue
					var fragment := children[0]
					second.position = Vector2(1200, 700)
					# Parent primary is directly in the fragment path. Ignore it for
					# collision, but retain it as an ordinary recipient of the blast.
					primary.position = fragment.position + fragment.direction * 15
					var hp := primary.health
					var victim := target(fragment.position + fragment.direction * 45)
					var later := target(fragment.position + fragment.direction * 80)
					var fragment_scale := scale * arena.stats.split_damage
					step(fragment, 130)
					check(direct.size() == 2 and direct[1].enemy == victim.get_instance_id(), "fragment ignores parent primary and stops at first eligible target")
					near(loss(victim), 40.0 * 1.4 * fragment_scale * 2.0, "fragment direct B+E has own crit and no self-blast")
					near(loss(later), 10.0 * 1.4 * fragment_scale * 2.0, "fragment blast applies burst fan split once")
					near(hp - primary.health, 10.0 * 1.4 * fragment_scale * 2.0, "fragment blast can hit original parent primary")
					check(fragment.retired and arena.element_procs.proc_counts.fire == 2, "fragment explodes once and retires")
					check(fragments().size() == 2, "blast and fragment cannot recursively split")
					step(fragment, 130)
					check(direct.size() == 2 and arena.element_procs.proc_counts.fire == 2, "no ghost fragment proc")
	check(combinations == 256, "all pierce burst fan split combinations tested")
func normal_modes() -> void:
	for element in ["fire", "dark", "lightning", "ice"]:
		for pierce in range(4):
			var skill := 1 if element in ["lightning", "ice"] else 0
			setup({element + "_enchant": 1, element + "_bow": skill, "pierce": pierce})
			var arrow := shoot()
			var victims: Array[EnemyActor] = []
			for i in range(5): victims.append(target(arrow.position + Vector2(30 + 30 * i, 0)))
			step(arrow, 200)
			if skill == 0:
				for i in range(5):
					var expected := 0.0
					if i == 0: expected = 20.0
					elif i <= pierce: expected = 20.0 * [0.70, 0.75, 0.85, 0.95][pierce]
					near(loss(victims[i]), expected, element + " skill0 normal direct damage and decay")
			check(direct.size() == 1 + pierce, element + " keeps finite normal pierce")
			check(arrow.retired, element + " expires at normal pierce budget")
			near(arrow.retention, [0.70, 0.75, 0.85, 0.95][pierce], element + " normal retention unchanged")
			check(arena.element_procs.proc_counts.fire == 0, element + " has no fire blast")
func fire_misses_and_volleys() -> void:
	setup({"fire_enchant": 1, "fire_bow": 3, "split": 3, "pierce": 3})
	var arrow := shoot()
	var witness := target(arrow.position + Vector2(20, 30))
	arrow.max_range = 50
	step(arrow, 100)
	check(arrow.retired and direct.is_empty() and arena.element_procs.proc_counts.fire == 0, "fire miss and range end never explode")
	near(loss(witness), 0, "miss has no proximity damage")
	check(fragments().is_empty(), "miss never splits")
	setup({"fire_enchant": 1, "fire_bow": 3, "split": 3, "pierce": 3, "burst": 3, "spread_arrow": 3})
	var bait := target(arena.player.position + Vector2(200, 0))
	arena.bow._physics_process(0.0)
	arena.bow.attack_clock = 100.0
	arena.bow._physics_process(arena.stats.burst_spacing * 3 + 0.001)
	bait.free()
	var mains: Array[BowArrow] = []
	for node in arena.arrows.get_children():
		if node is BowArrow and not node.secondary: mains.append(node)
	check(mains.size() == arena.stats.burst_count * arena.stats.spread_arrow_count, "real maximum burst scheduler emits every fan arrow")
	for main in mains:
		for enemy in arena.enemies.get_children(): enemy.free()
		target(main.position + main.direction * 40)
		step(main, 50)
	check(direct.size() == mains.size(), "each maximum-volley original arrow hits once")
	check(arena.element_procs.proc_counts.fire == mains.size(), "every original burst/fan arrow independently explodes")
	check(fragments().size() == mains.size() * 2, "maximum original volley creates exactly two fragments per main")
	# All fragments then get a distinct eligible collision, without other
	# targets or remaining main arrows contributing damage.
	var children := fragments()
	for fragment in children:
		for enemy in arena.enemies.get_children(): enemy.free()
		target(fragment.position + fragment.direction * 30)
		step(fragment, 40)
	check(arena.element_procs.proc_counts.fire == mains.size() + children.size(), "every maximum-volley fragment explodes independently")
	check(fragments().size() == children.size(), "maximum fragment chain terminates without extra children")
func fire_edges() -> void:
	for rank in range(1, 4):
		setup({"fire_enchant": 1, "fire_bow": rank, "pierce": 3, "split": 3})
		var arrow := shoot()
		var primary := target(arrow.position + Vector2(40, 0))
		primary.health = 1.0
		var witness := target(primary.position + Vector2(0, 35))
		step(arrow, 100)
		check(primary.is_dead and arrow.retired, "lethal fire primary still retires")
		near(loss(witness), 5.0 * [0.0, 1.0, 1.5, 2.0][rank], "lethal first impact still blasts at each skill rank")
		check(fragments().size() == 2, "lethal primary retains original split")
		var fragment := fragments()[0]
		for enemy in arena.enemies.get_children(): enemy.free()
		var remaining := fragment.max_range - fragment.traveled
		check(remaining < arrow.max_range, "fragment inherits consumed main range")
		var outside := target(fragment.position + fragment.direction * (remaining + fragment.width + 3.1))
		var count: int = arena.element_procs.proc_counts.fire
		step(fragment, remaining + 100)
		check(fragment.retired and arena.element_procs.proc_counts.fire == count, "fragment missing until inherited range ends never explodes")
		near(loss(outside), 0, "fragment cannot reach wholly beyond inherited range")
		check(direct.size() == 1, "out-of-range fragment makes no direct packet")
	for starting in ["fire", "dark"]:
		for pierce in range(4):
			setup({starting + "_enchant": 1, starting + "_bow": 1, "pierce": pierce})
			var old := shoot()
			arena.select_upgrade("ice_enchant")
			check(old.retired or old.is_queued_for_deletion(), "element switch clears former special arrow")
			check(int(arena.ranks.get("pierce", 0)) == pierce, "switch retains exact purchased pierce")
			var normal := shoot()
			for i in range(5): target(normal.position + Vector2(30 + i * 30, 0))
			step(normal, 200)
			check(direct.size() == 1 + pierce, "switch to ice actually restores normal collision budget")
			near(normal.retention, [0.70, 0.75, 0.85, 0.95][pierce], "switch restores original retention")
func lightning_matrix() -> void:
	var combinations := 0
	for pierce in range(4):
		for burst in range(4):
			for fan in range(4):
				for split in range(4):
					combinations += 1
					setup({"lightning_enchant": 2, "lightning_bow": 3, "pierce": pierce, "burst": burst, "spread_arrow": fan, "split": split, "damage_flat": 3, "damage": 2})
					arena.stats.combat_definition.total_crit_chance_cap = 1.0 # Isolate critical damage formula, not production chance.
					arena.stats.crit_chance = 1.0
					var arrow := shoot()
					var scale := arena.stats.burst_damage_multiplier * arrow.damage_scale
					# The same witness is eligible for successive independent chains.
					var witness := target(arrow.position + arrow.direction.orthogonal() * 35)
					var events := [0, 0]
					witness.damaged.connect(func(_amount: float, crit: bool, _at: Vector2) -> void:
						events[0] += 1
						if crit: events[1] += 1)
					var expected_witness := 0.0
					for impact in range(1 + pierce):
						var primary := target(arrow.position + arrow.direction * 30)
						witness.position = primary.position + arrow.direction.orthogonal() * 35
						var retention: float = 1.0 if impact == 0 else [0.70, 0.75, 0.85, 0.95][pierce]
						step(arrow, 40)
						expected_witness += 10.0 * 1.4 * scale * retention
						near(loss(primary), 40.0 * 1.4 * scale * retention * 2.0, "lightning main direct uses same once-only retention")
						near(loss(witness), expected_witness, "every lightning piercing hit chains with its own E retention")
						check(arena.element_procs.proc_counts.lightning == impact + 1, "one chain per main direct hit p%d b%d f%d s%d" % [pierce, burst, fan, split])
						check(events[0] == impact + 1 and events[1] == 0, "same witness may receive different noncritical chains")
						primary.free()
					check(arrow.retired and direct.size() == 1 + pierce, "lightning retains normal finite direct pierce budget")
					var children := fragments()
					check(children.size() == (0 if split == 0 else 2), "later chains and pierce hits do not resplit")
					if split == 0: continue
					var fragment := children[0]
					var primary := target(fragment.position + fragment.direction * 35)
					witness.position = primary.position + fragment.direction.orthogonal() * 35
					var hp := witness.health
					var fragment_scale := scale * arena.stats.split_damage
					var before_hits := direct.size()
					step(fragment, 45)
					near(loss(primary), 40.0 * 1.4 * fragment_scale * 2.0, "lightning fragment direct independently crits")
					near(hp - witness.health, 10.0 * 1.4 * fragment_scale, "fragment chain E inherits burst fan split exactly once")
					check(arena.element_procs.proc_counts.lightning == pierce + 2, "fragment direct triggers one chain")
					check(fragment.retired and direct.size() == before_hits + 1, "fragment still has one direct hit only")
					check(fragments().size() == 2, "fragment chain never creates extra fragments")
					step(fragment, 100)
					check(arena.element_procs.proc_counts.lightning == pierce + 2, "retired fragment does not repeatedly chain")
	check(combinations == 256, "all lightning pierce burst fan split combinations tested")
func run() -> void:
	dark_unlimited()
	fire_matrix()
	normal_modes()
	fire_misses_and_volleys()
	fire_edges()
	lightning_matrix()
	arena.free()
	print("ARROW MODE INDEPENDENT: %d checks, %d failures" % [checks, failures])
	await preload("res://tests/audio_teardown.gd").drain(self)
	quit(0 if failures == 0 else 1)
