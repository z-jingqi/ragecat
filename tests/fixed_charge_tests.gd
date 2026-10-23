extends SceneTree

class Target:
	extends Node2D
	var radius: float = 16.0

var checks := 0
var failures := 0
var hits := 0
var world: Node2D
var boss: BossActor
var target: Target

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func prepare(origin: Vector2, destination: Vector2, bounds := Rect2(0, 0, 4000, 4000)) -> void:
	boss.reset_state()
	boss.arena_bounds = bounds
	boss.position = origin
	target.position = destination
	boss.target = target
	boss._start_charge_warning()

func finish_charge() -> void:
	boss._physics_process(boss.warning_duration)
	boss._physics_process(2.0)

func run() -> void:
	world = Node2D.new()
	root.add_child(world)
	target = Target.new()
	world.add_child(target)
	boss = preload("res://scenes/bosses/arena_boss.tscn").instantiate() as BossActor
	world.add_child(boss)
	boss.set_physics_process(false)
	boss.attack_player.connect(func(_damage: float) -> void: hits += 1)
	check(boss.charge_distance == 2.0 * 470.0, "authored scene distance is exactly twice previous 470 px")
	var standalone := BossActor.new()
	check(standalone.charge_distance == boss.charge_distance, "standalone and scene charge defaults agree")
	standalone.free()
	check(boss.charge_width == 66.0 and boss.charge_speed == 680.0, "baseline width and speed unchanged")
	check(is_equal_approx(boss.warning_duration, 0.95) and is_equal_approx(boss.recovery_duration, 1.15) and boss.attack_damage == 22.0, "warning recovery damage unchanged")
	for range_to_player: float in [1.0, 2000.0]:
		prepare(Vector2(1000, 1000), Vector2(1000 + range_to_player, 1000))
		check(boss.charge_end == Vector2(1940, 1000), "near and far targets give identical full endpoint")
		var endpoint := boss.charge_end
		target.position = Vector2(1000, 2000)
		boss._physics_process(0.2)
		check(boss.charge_direction == Vector2.RIGHT and boss.charge_end == endpoint, "warning heading ignores later player movement")
		boss._physics_process(boss.warning_duration)
		target.position = Vector2(1000, 0)
		boss._physics_process(2.0)
		check(boss.position == endpoint and boss.state == "recovery" and not boss.charge_active, "large delta finishes exact fixed distance without chasing or overshoot")
	prepare(Vector2(1000, 1000), Vector2(1000, 1000))
	check(boss.charge_direction == Vector2.RIGHT and boss.charge_end == Vector2(1940, 1000), "coincident player uses finite deterministic heading")
	boss.charge_distance = 123.0
	prepare(Vector2(1000, 1000), Vector2(3000, 1000))
	check(boss.charge_end == Vector2(1123, 1000), "exported override remains authoritative instead of hardcoded doubling")
	boss.charge_distance = 940.0
	var bounds := Rect2(0, 0, 800, 600)
	prepare(Vector2(200, 300), Vector2(700, 300), bounds)
	check(boss.charge_end == Vector2(766, 300), "wall endpoint uses boss radius not player radius")
	var end := boss.charge_end
	finish_charge()
	check(boss.position == end and boss.state == "recovery", "wall ends charge immediately in recovery")
	boss._physics_process(0.1)
	check(boss.position == end and not boss.charge_active, "wall collision cannot rebound slide or restart")
	boss.radius = 50.0
	prepare(Vector2(200, 300), Vector2(700, 300), bounds)
	check(boss.charge_end == Vector2(750, 300), "custom boss radius determines wall center limits")
	boss.radius = 34.0
	for direction: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		prepare(Vector2(400, 300), Vector2(400, 300) + direction * 1000.0, bounds)
		var expected_distance := 366.0 if direction.x != 0.0 else 266.0
		var expected_end := Vector2(400, 300) + direction * expected_distance
		check(boss.charge_end == expected_end, "each arena wall clips the fixed ray at the radius inset")
		finish_charge()
		check(boss.position == expected_end and boss.state == "recovery", "each wall terminates charge cleanly")
	prepare(Vector2(400, 300), Vector2(766, 566), bounds)
	check(boss.charge_end.is_equal_approx(Vector2(766, 566)), "diagonal charge reaches corner with center limits")
	finish_charge()
	check(boss.position.is_equal_approx(Vector2(766, 566)), "corner charge ends without diagonal overshoot")
	prepare(Vector2(766, 300), Vector2(766, 500), bounds)
	check(boss.charge_end == Vector2(766, 566), "exact wall tangent remains valid")
	prepare(Vector2(766, 300), Vector2(766.05, 500), bounds)
	check(boss.charge_end == boss.charge_start, "near-tangent outward ray stops at existing wall contact")
	finish_charge()
	check(boss.position == Vector2(766, 300) and not boss.charge_active, "zero-length wall charge cleans up")
	prepare(Vector2(200, 300), Vector2(700, 300), bounds)
	var count_before := hits
	finish_charge()
	check(hits == count_before + 1, "large delta swept collision catches crossed target once")
	target.position = boss.charge_end + Vector2(target.radius + 1.0, 0)
	check(not boss._charge_hits_target(boss.charge_start, boss.charge_end), "no phantom hit beyond wall endpoint plus player extent")
	prepare(Vector2(1000, 1000), Vector2(3000, 1000))
	target.position = boss.charge_end + Vector2(target.radius + 1.0, 0)
	check(not boss._charge_hits_target(boss.charge_start, boss.charge_end), "no phantom hit beyond full distance endpoint")
	target.position = boss.charge_start + Vector2(400, boss.charge_width * 0.5 + target.radius + 1.0)
	check(not boss._charge_hits_target(boss.charge_start, boss.charge_end), "collision uses exact warning rectangle width")
	target.position = boss.charge_start + Vector2(400, boss.charge_width * 0.5 + target.radius - 1.0)
	check(boss._charge_hits_target(boss.charge_start, boss.charge_end), "player circle touching warning width is hit")
	check(not boss.gravity_eligible() and not boss.contact_damage_suppressed(), "warning retains priority over gravity immunity")
	boss._physics_process(boss.warning_duration)
	check(not boss.gravity_eligible() and not boss.contact_damage_suppressed(), "charge retains priority over gravity immunity")
	var before_position := boss.position
	var before_time := boss.phase_time
	boss.ai_enabled = false
	boss._physics_process(1.0)
	check(boss.position == before_position and boss.phase_time == before_time, "AI pause freezes charge position and clock")
	boss.ai_enabled = true
	for invalid_delta: float in [-1.0, INF, NAN]:
		boss._physics_process(invalid_delta)
		check(boss.position == before_position and boss.phase_time == before_time, "invalid physics delta cannot corrupt charge")
	boss.reset_state()
	check(not boss.charge_active and not boss.charge_hit and boss.state == "recovery" and boss.rocks.is_empty(), "reset clears committed charge state")
	test_player_defenses()
	world.free()
	print("Fixed charge tests: %d checks, %d failures" % [checks, failures])
	await preload("res://tests/audio_teardown.gd").drain(self)
	quit(1 if failures else 0)

func test_player_defenses() -> void:
	var player := CatPlayer.new()
	var stats := CombatStats.new()
	stats.max_hp = 100.0
	stats.hp = 100.0
	stats.collision_radius = 16.0
	stats.hit_immunity = 0.5
	player.setup(stats)
	world.add_child(player)
	player.set_physics_process(false)
	boss.attack_player.connect(player.receive_hit)
	for defense: String in ["invulnerable", "shield", "iframe"]:
		prepare(Vector2(1000, 1000), Vector2(1020, 1000))
		player.position = target.position
		boss.target = player
		player.invulnerable = defense == "invulnerable"
		stats.shields = 1 if defense == "shield" else 0
		stats.hp = 100.0
		player.health_state.invulnerability = 0.5 if defense == "iframe" else 0.0
		boss._physics_process(boss.warning_duration)
		var count_before := hits
		boss._physics_process(0.05)
		check(boss.charge_hit and hits == count_before + 1 and stats.hp == 100.0, "%s absorbs first contact without changing charge window" % defense)
		check(stats.shields == 0, "%s preserves shield consumption semantics" % defense)
		player.invulnerable = false
		player.health_state.invulnerability = 0.0
		player.position = boss.position + Vector2(10, 0)
		boss._physics_process(0.05)
		check(hits == count_before + 1 and stats.hp == 100.0, "%s expiration cannot cause second charge hit" % defense)
	boss.attack_player.disconnect(player.receive_hit)
	player.free()
