extends SceneTree
var checks := 0
var failures := 0
var arena: RageArena
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + message)
func close(actual: float, expected: float, message: String) -> void:
	check(is_equal_approx(actual, expected), message + " actual=%s expected=%s" % [actual, expected])
func _initialize() -> void: call_deferred("run")
func reset() -> void:
	arena.clear_enemies()
	arena.apply_ranks({})
	arena.stats.crit_chance = 0.0
func target(x: float, radius: float = 16.0) -> EnemyActor:
	var enemy := arena.spawn_enemy("dummy",Vector2(x,300))
	enemy.radius = radius
	return enemy
func arrow(hit_limit: int, retained: float = 0.75, distance: float = 500.0) -> CatArrow:
	var projectile := CatArrow.new()
	projectile.position = Vector2(200,300)
	projectile.direction = Vector2.RIGHT
	projectile.speed = 1000.0
	projectile.width = 7.0
	projectile.max_hits = hit_limit
	projectile.decay = retained
	projectile.max_range = distance
	projectile.arena_bounds = arena.bounds
	projectile.enemies = arena.enemies
	projectile.enemy_hit.connect(arena._on_arrow_hit)
	arena.arrows.add_child(projectile)
	return projectile
func loss(enemy: EnemyActor) -> float: return enemy.max_health - enemy.health
func run() -> void:
	arena = RageArena.new()
	arena.practice = true
	root.add_child(arena)
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	arena.bow.enabled = false
	reset()
	var far := target(350)
	var near := target(300)
	var shot := arrow(1)
	shot._physics_process(1.0)
	close(loss(near),15.0,"No pierce hits nearest despite reversed enemy order")
	close(loss(far),0.0,"No pierce cannot hit second target in same large step")
	check(shot.hit_ids.size()==1 and shot.is_queued_for_deletion(),"No pierce stops after first collision")
	reset()
	far=target(301)
	near=target(300)
	shot=arrow(1)
	shot._physics_process(1.0)
	close(loss(near),15.0,"Overlapping circles still prioritize first contact")
	close(loss(far),0.0,"Overlap does not bypass no-pierce limit")
	reset()
	var third := target(440)
	var second := target(360)
	var first := target(280)
	shot=arrow(3)
	shot._physics_process(1.0)
	close(loss(first),15.0,"Pierce first hit has full damage")
	close(loss(second),11.25,"Pierce second hit uses percentage once")
	close(loss(third),11.25,"Third hit retains same percentage, not compounded")
	check(shot.hit_ids.size()==3,"Pierce respects configured target limit")
	reset()
	first=target(245)
	second=target(360)
	shot=arrow(4,0.75,100.0)
	shot._physics_process(0.05)
	close(loss(first),15.0,"In-range first hit resolves")
	shot._physics_process(10.0)
	close(loss(second),0.0,"Huge step cannot hit a fully out-of-range second enemy")
	close(shot.traveled,100.0,"Total traveled never resets on hit and clamps at range")
	close(shot.position.x,300.0,"Arrow stops at total-range endpoint")
	check(shot.is_queued_for_deletion(),"Arrow expires at range endpoint")
	reset()
	first=target(323.0)
	shot=arrow(4,0.75,100.0)
	shot._physics_process(10.0)
	close(loss(first),15.0,"Physical arrow+target radii touching at range endpoint can collide")
	reset()
	first=target(323.1)
	shot=arrow(4,0.75,100.0)
	shot._physics_process(10.0)
	close(loss(first),0.0,"Physical hitbox wholly beyond range cannot collide")
	reset()
	near=target(320,10)
	far=target(360,80)
	shot=arrow(1)
	shot._physics_process(1.0)
	close(loss(far),15.0,"Collision ordering uses earliest surface contact, not center distance")
	close(loss(near),0.0,"A later surface does not overtake earlier larger hitbox")
	reset()
	first=target(230)
	shot=arrow(4)
	shot._physics_process(0.02)
	shot._physics_process(0.01)
	close(loss(first),15.0,"Same arrow cannot hit overlapping same enemy again next frame")
	check(shot.hit_ids.size()==1,"One identity recorded once")
	for retained in [0.75,0.85,0.95]:
		reset()
		first=target(280)
		second=target(360)
		third=target(440)
		shot=arrow(3,retained)
		for delta in [0.03,0.08,0.001,0.189]: shot._physics_process(delta)
		close(loss(first),15.0,"Irregular steps preserve full first hit for retained="+str(retained))
		close(loss(second),15.0*retained,"Irregular steps preserve second hit percentage")
		close(loss(third),15.0*retained,"All pierce ranks retain same later percentage across frames")
	reset()
	first=target(280)
	first.position.y=323.0
	shot=arrow(1)
	shot._physics_process(0.1)
	close(loss(first),15.0,"Exact tangent to combined radii hits")
	reset()
	first=target(280)
	first.position.y=323.01
	shot=arrow(1)
	shot._physics_process(0.1)
	close(loss(first),0.0,"Just outside tangent misses")
	reset()
	var diagonal:=Vector2(1,1).normalized()
	first=target(280)
	first.position=Vector2(200,300)+diagonal*122.9
	shot=arrow(4,0.75,100.0)
	shot.direction=diagonal
	shot._physics_process(1.0)
	close(loss(first),15.0,"Diagonal sweep hits a surface just inside total-range endpoint")
	close(shot.traveled,100.0,"Diagonal distance still respects absolute range")
	reset()
	first=target(280)
	first.position=Vector2(200,300)+diagonal*123.1
	shot=arrow(4,0.75,100.0)
	shot.direction=diagonal
	shot._physics_process(1.0)
	close(loss(first),0.0,"Diagonal sweep cannot hit wholly beyond-range surface")
	reset()
	first=target(280)
	second=target(280)
	shot=arrow(1)
	shot._physics_process(0.1)
	close(loss(first)+loss(second),15.0,"Exactly overlapping targets still share only one no-pierce hit")
	arena.queue_free()
	await process_frame
	print("PIERCE/RANGE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
