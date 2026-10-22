extends SceneTree

class Target:
	extends Node2D
	var radius: float = 16.0

var failures: int = 0
var checks: int = 0
var hits: int = 0
var impact_count: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func on_attack(_damage: float) -> void:
	hits += 1

func on_impact(_center: Vector2, _radius: float) -> void:
	impact_count += 1

func run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var player := Target.new()
	world.add_child(player)
	var boss := BossActor.new()
	world.add_child(boss)
	boss.set_physics_process(false)
	boss.target = player
	boss.arena_bounds = Rect2(0, 0, 800, 600)
	boss.position = Vector2(200, 300)
	player.position = Vector2(500, 300)
	boss.charge_distance = 700
	boss.attack_player.connect(on_attack)
	boss._start_charge_warning()
	var end: Vector2 = boss.charge_end
	var direction: Vector2 = boss.charge_direction
	check(end == Vector2(766, 300), "charge ends at inset arena wall")
	player.position = Vector2(500, 450)
	boss._physics_process(0.2)
	check(boss.charge_end == end and boss.charge_direction == direction, "telegraph locks and never follows target")
	var remaining: float = boss.phase_time
	boss.ai_enabled = false
	boss.status.apply_ice(load("res://resources/elements/ice.tres") as ElementSkillDefinition, 3, true)
	var before_health: float = boss.health
	boss._physics_process(0.5)
	check(boss.phase_time == remaining, "AI toggle freezes ability clock")
	check(boss.health == before_health and is_equal_approx(boss.status.chill_remaining, 1.5), "AI-off still ticks harmless chill")
	boss.ai_enabled = true
	player.position = Vector2(500, 300)
	boss._physics_process(1.0)
	for i: int in range(20):
		boss._physics_process(0.05)
	check(hits == 1, "charge deals at most one hit")
	check(boss.position == end and not boss.charge_active, "charge stops exactly at wall")
	player.position = end + Vector2(17, 0)
	check(not boss._charge_hits_target(boss.charge_start, end), "no capsule hit beyond endpoint plus player extent")
	player.position = boss.charge_start - Vector2(17, 0)
	check(not boss._charge_hits_target(boss.charge_start, end), "no capsule hit behind origin plus player extent")
	player.position = boss.charge_start + Vector2(100, boss.charge_width * 0.5 + 17)
	check(not boss._charge_hits_target(boss.charge_start, end), "no hit outside exact width plus player extent")
	boss.reset_state()
	player.position = Vector2(400, 300)
	boss._start_rocks()
	check(boss.rocks.size() == 5, "rock attack has five individual circles")
	var locations: Array[Vector2] = []
	for rock: RockWarning in boss.rocks:
		rock.set_physics_process(false)
		locations.append(rock.global_position)
		check(rock.get_parent() == boss, "rock warnings stay outside enemy actor container")
		for other: RockWarning in boss.rocks:
			if other != rock:
				check(rock.global_position.distance_to(other.global_position) > rock.radius + other.radius + 15, "rock circles have clear dodge gaps")
	player.position += Vector2(140, 100)
	boss._physics_process(0.1)
	for i: int in range(boss.rocks.size()):
		check(boss.rocks[i].global_position == locations[i], "rock circles snapshot instead of tracking")
	var count_before: int = hits
	boss._rock_impact(Vector2(400, 300), boss.rock_radius)
	check(hits == count_before, "rock hit has no enclosing outer area")
	var warning: RockWarning = boss.rocks[0]
	warning.impact.connect(on_impact)
	warning._physics_process(warning.warning_duration)
	warning._physics_process(0.1)
	check(impact_count == 1, "rock impact fires only once")
	boss.reset_state()
	check(boss.rocks.is_empty() and boss.state == "recovery", "reset clears all warnings")
	player.position = Vector2(400, 300)
	boss._start_rocks()
	check(boss.rocks[1].global_position != locations[1], "successive rock patterns vary with seeded RNG")
	boss.reset_state()
	player.position = Vector2(20, 20)
	boss._start_rocks()
	check(boss.rocks.size() == 5, "corner snapshot still generates five separated circles")
	boss.reset_state()
	var dummy := EnemyActor.new()
	world.add_child(dummy)
	dummy.set_physics_process(false)
	dummy.ai_enabled = false
	dummy.status.apply_ice(load("res://resources/elements/ice.tres") as ElementSkillDefinition, 1)
	dummy._physics_process(0.5)
	check(dummy.health == dummy.max_health and is_equal_approx(dummy.status.chill_remaining, 1.5), "Disabled AI still expires chill without DOT")
	world.free()
	print("Boss tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
