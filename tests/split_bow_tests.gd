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
func shot(distance: float = 200.0, direction: Vector2 = Vector2.RIGHT) -> CatArrow:
	var arrow := CatArrow.new()
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
func fragments() -> Array[CatArrow]:
	var result: Array[CatArrow] = []
	for node in arena.arrows.get_children():
		if node is CatArrow and node.secondary: result.append(node)
	return result
func run() -> void:
	arena = RageArena.new()
	arena.practice = true
	root.add_child(arena)
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	for rank in range(1,4):
		reset({"split":rank,"damage":2,"pierce":3})
		arena.stats.crit_chance = 1.0
		var trigger := target(Vector2(250,300))
		var source := shot()
		source._physics_process(0.1)
		var parts := fragments()
		check(parts.size()==2,"first impact creates exactly two fragments rank %d" % rank)
		if parts.size()!=2: continue
		var part := parts[0]
		close(part.position.x,243.0,"fragment starts at physical contact, not frame endpoint")
		close(part.traveled,43.0,"fragment inherits consumed distance at contact")
		check(part.ignored_ids.has(trigger.get_instance_id()) and part.hit_ids.is_empty(),"ignored source does not consume fragment hit")
		check(part.max_hits==1,"pierce upgrade does not grant fragment pierce")
		var victim := target(part.position + part.direction*50)
		var behind := target(part.position + part.direction*85)
		var crits_before := arena.crits
		var old_trigger_hp := trigger.health
		part._physics_process(0.1)
		close(victim.max_health-victim.health,15*1.4*[0.0,0.3,0.45,0.6][rank],"fragment damage scales once without inherited crit")
		close(trigger.health,old_trigger_hp,"fragment cannot rehit trigger")
		close(behind.health,behind.max_health,"fragment cannot pierce")
		check(arena.crits==crits_before,"fragment cannot crit even with guaranteed ordinary critical")
		check(fragments().size()==2,"fragment does not recursively split")
		var next_target := target(Vector2(340,300))
		source._physics_process(0.1)
		check(next_target.health<next_target.max_health and fragments().size()==2,"later primary piercing hit cannot split twice")
	# Range inherited even on a huge step and oblique heading.
	for axis: Vector2 in [Vector2.RIGHT,Vector2(1,1).normalized()]:
		reset({"split":3})
		var source := shot(100,axis)
		target(source.position+axis*97)
		source._physics_process(2)
		var parts := fragments()
		check(parts.size()==2,"near-limit impact creates bounded fragments")
		for part: CatArrow in parts:
			close(part.traveled,90,"near-limit fragments inherit ninety traveled")
			var victim := target(part.position+part.direction*18)
			part._physics_process(2)
			close(part.traveled,100,"fragment clamps at original total path limit")
			close(victim.health,victim.max_health,"outside-surface victim beyond remaining range untouched")
			check(part.is_queued_for_deletion(),"fragment expires at inherited range")
	reset({"split":3})
	var endpoint := shot(100)
	target(Vector2(307,300))
	endpoint._physics_process(2)
	check(fragments().is_empty(),"impact exactly at endpoint cannot generate extra-range fragments")
	# Full secondary capacity does not displace a primary fan; freed capacity resumes.
	reset({"split":3,"spread_arrow":3})
	var dummy := target(Vector2(250,300))
	for i in range(BowController.FRAGMENT_LIMIT):
		var part := CatArrow.new()
		part.secondary = true
		arena.arrows.add_child(part)
	arena.bow.shoot()
	check(arena.bow.active_count(false)==7,"fragment cap cannot crowd out primary fan")
	var source := shot()
	source._physics_process(1)
	check(arena.bow.active_count(true)==BowController.FRAGMENT_LIMIT,"fragment capacity is bounded")
	for node in arena.arrows.get_children():
		if node is CatArrow and node.secondary: node.queue_free()
	var retry := shot()
	retry.impact_position = Vector2(200,300)
	retry.impact_traveled = 0
	arena.bow._relay_arrow_hit(retry,dummy)
	check(arena.bow.active_count(true)==2,"queued deletion releases fragment capacity immediately")
	reset({"spread_arrow":3})
	target(arena.player.position+Vector2(100,0))
	for i in range(BowController.PRIMARY_LIMIT): arena.arrows.add_child(CatArrow.new())
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
		close(victim.position.distance_to(origin),45.0*(1.0+0.25*rank),"real knockback scales at rank %d" % rank)
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
	print("SPLIT BOW TESTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
