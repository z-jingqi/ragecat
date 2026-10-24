extends SceneTree
var checks := 0
var failures := 0
var arena: RageArena
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)
func close(actual: float, expected: float, label: String) -> void:
	check(is_equal_approx(actual, expected), "%s actual=%s expected=%s" % [label,actual,expected])
func reset(ranks: Dictionary = {}) -> void:
	arena.clear_enemies()
	arena.apply_ranks(ranks)
	arena.stats.crit_chance = 0.0
	arena.bow.attack_clock = 0.0
	arena.bow.burst_clock = 0.0
	arena.bow.burst_remaining = 0
func target(at: Vector2) -> EnemyActor:
	var enemy := arena.spawn_enemy("dummy",at)
	enemy.radius = 5.0
	return enemy
func shot(distance: float = 200.0, direction: Vector2 = Vector2.RIGHT) -> BowArrow:
	var arrow := BowArrow.new()
	arrow.position = Vector2(200,300)
	arrow.direction = direction
	arrow.speed = 1000
	arrow.max_range = distance
	arrow.max_hits = arena.stats.pierce_max_hits
	arrow.decay = arena.stats.pierce_retention
	arrow.width = 2
	arrow.enemies = arena.enemies
	arrow.arena_bounds = arena.bounds
	arrow.enemy_hit.connect(arena.bow._relay_arrow_hit)
	arena.arrows.add_child(arrow)
	return arrow
func fragments() -> Array[BowArrow]:
	var result: Array[BowArrow] = []
	for node in arena.arrows.get_children():
		if node is BowArrow and node.secondary: result.append(node)
	return result
func run() -> void:
	arena = RageArena.new()
	arena.practice = true
	root.add_child(arena)
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	# Legacy ranks are ignored, never converted to another buff.
	for rank in range(4):
		reset({"split":rank,"damage":2,"pierce":3,"spread_arrow":2,"burst":1})
		check(not arena.stats.ranks.has("split"), "legacy split rank omitted")
		check(arena.stats.ranks.get("damage") == 2 and arena.stats.ranks.get("pierce") == 3, "unrelated ranks preserved")
		var first := target(Vector2(250,300))
		var later := target(Vector2(340,300))
		var source := shot()
		source._physics_process(0.2)
		check(first.health < first.max_health and later.health < later.max_health, "normal piercing still reaches later target")
		check(fragments().is_empty(), "first and later piercing impacts create no arrows")
	for element: String in ["fire", "lightning", "ice", "dark"]:
		reset({"element_type":element,"enchant_rank":3,"element_skill_rank":3,"split":3,"spread_arrow":3,"burst":3})
		var with_legacy := arena.stats.gravity_inner_radius
		var clean_ranks := arena.stats.ranks.duplicate()
		check(not clean_ranks.has("split"), element + " retired skill normalized away")
		arena.apply_ranks(clean_ranks)
		close(arena.stats.gravity_inner_radius, with_legacy, "legacy rank grants no hidden radius bonus")
		if element == "dark":
			close(with_legacy, arena.stats.element_skill.gravity.parameter(arena.stats.element_skill.gravity.inner_radius_by_rank, 3), "dark inner radius uses only its configured skill rank")
	var catalog := arena.stats.catalog
	check(catalog.definition("split") == null, "retired skill absent from catalog")
	check(not catalog.eligible({}).has("split"), "retired skill absent from upgrade pool")
	check(not arena.definition.practice_presets.has("preset_split"), "retired practice preset absent")
	# Swept collision still respects original range for straight and oblique shots.
	for axis: Vector2 in [Vector2.RIGHT, Vector2(1,1).normalized()]:
		reset({"pierce":3})
		var source := shot(100, axis)
		var inside := target(source.position + axis * 97)
		var beyond := target(source.position + axis * 108)
		source._physics_process(2)
		close(source.traveled, 100, "large step clamps to configured range")
		check(inside.health < inside.max_health, "near endpoint collision remains valid")
		close(beyond.health, beyond.max_health, "beyond endpoint remains untouched")
		check(fragments().is_empty(), "range endpoint cannot spawn arrows")
	reset({"spread_arrow":3})
	target(arena.player.position+Vector2(100,0))
	for i in range(BowController.PRIMARY_LIMIT): arena.arrows.add_child(BowArrow.new())
	arena.bow.shoot()
	check(arena.bow.active_count(false)==BowController.PRIMARY_LIMIT,"full primary budget skips whole fan without overflow")
	for i in range(7): arena.arrows.get_child(i).queue_free()
	arena.bow.shoot()
	check(arena.bow.active_count(false)==BowController.PRIMARY_LIMIT,"released primary capacity permits complete fan immediately")
	# Knockback upgrade changes actual normal-enemy displacement, not boss movement.
	for rank in range(4):
		reset({"knockback":rank})
		var victim := target(Vector2(350,300))
		victim.is_dummy = false
		var origin := victim.position
		arena.bow._relay_arrow_hit(shot(),victim)
		check(victim.position == origin,"upgraded knockback begins without teleporting")
		victim._physics_process(victim.feedback_definition.knockback_duration)
		close(victim.position.distance_to(origin),15.0*rank,"real knockback scales at rank %d" % rank)
		var boss := arena.spawn_enemy("boss",Vector2(500,400))
		origin = boss.position
		arena.bow._relay_arrow_hit(shot(),boss)
		check(boss.position==origin,"boss remains immune to upgraded knockback")
	# Maximum speed must finish every volley at different tick sizes.
	for delta: float in [1.0/60.0,1.0/30.0,0.01]:
		reset({"burst":3,"attack_speed":3})
		target(arena.player.position+Vector2(100,0))
		arena.bow._physics_process(0.0)
		var loops := ceili(0.365/delta)
		for i in range(loops): arena.bow._physics_process(delta)
		check(arena.bow.active_count(false)==4,"all four volley shots emitted before next attack at delta %s" % delta)
		check(arena.bow.burst_remaining==0,"volley queue fully drains")
	arena.free()
	print("FIRING PATTERN REGRESSIONS: %d checks, %d failures" % [checks,failures])
	await preload("res://tests/audio_teardown.gd").drain(self)
	quit(0 if failures==0 else 1)
