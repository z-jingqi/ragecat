extends SceneTree
## Geometry contracts for the edge-to-edge logical playfield. No UI or balance tuning.
const FIELD := Rect2(0, 0, 1280, 800)
const DIRECTIONS: Array[Vector2] = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]
var checks := 0
var failures := 0
var arena: RageArena

func _initialize() -> void: call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func inside_with_margin(at: Vector2, margin: float) -> bool:
	var safe := FIELD.grow(-margin)
	# Rect2.has_point excludes the bottom/right boundary; collision clamps include it.
	return at.x >= safe.position.x - 0.001 and at.y >= safe.position.y - 0.001 and at.x <= safe.end.x + 0.001 and at.y <= safe.end.y + 0.001

func edge_point(direction: Vector2, inset: float) -> Vector2:
	return FIELD.get_center() + direction * (FIELD.size * 0.5 - Vector2.ONE * inset)

func run() -> void:
	arena = RageArena.new()
	arena.definition = ArenaDefinition.new()
	arena.definition.normal_bounds = FIELD
	arena.definition.practice_bounds = FIELD
	arena.sound_enabled = false
	arena.run_seed_override = 13017
	root.add_child(arena)
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	arena.bow.enabled = false
	arena.player.movement_enabled = false
	arena.player.invulnerable = true
	check(arena.bounds == FIELD and arena.player.arena_bounds == FIELD and arena.bow.bounds == FIELD, "run passes full logical bounds to player and bow")
	check(arena.player.position == FIELD.get_center(), "player begins at full playfield center")
	for direction in DIRECTIONS:
		arena.player.position = edge_point(direction, -100)
		arena.player._physics_process(0.0)
		check(inside_with_margin(arena.player.position, arena.stats.arena_padding), "player clamps at each full playfield edge")
		check(arena.player.position.is_equal_approx(edge_point(direction, arena.stats.arena_padding)), "no previous HUD strip remains as player movement boundary")
		for i in range(40):
			var at := arena._safe_spawn_position()
			check(at.is_finite() and inside_with_margin(at, arena.definition.spawn_inset), "edge player retains valid bounded random spawn")
			check(at.distance_to(arena.player.position) >= arena.definition.spawn_player_clearance, "edge spawn respects player clearance")
		for kind in ["mob", "ranged", "swiftfang", "elite_hornling", "mountainbreaker", "beastcaller", "wildfire"]:
			var enemy := arena.spawn_enemy(kind, edge_point(direction, 1))
			check(enemy != null and enemy.arena_bounds == FIELD and inside_with_margin(enemy.position, enemy.radius), "each actor receives full bounds and stays inside: " + kind)
			arena.clear_enemies()
		projectiles_at_edge(direction)
		test_pickup(direction)
	arena.player.position = FIELD.get_center()
	test_mountainbreaker()
	test_beastcaller()
	test_wildfire()
	arena.free()
	await process_frame
	print("Full playfield boundaries: %d checks, %d failures" % [checks, failures])
	await preload("res://tests/audio_teardown.gd").drain(self)
	quit(1 if failures else 0)

func projectiles_at_edge(direction: Vector2) -> void:
	var player := arena.player
	player.position = FIELD.get_center()
	var bullet := EnemyBullet.new()
	var settings := SpitterDefinition.new()
	settings.bullet_range = 5000
	bullet.setup(edge_point(direction, 30), direction, settings, player)
	bullet.arena_bounds = FIELD
	arena.enemy_bullets.add_child(bullet)
	bullet._physics_process(1.0)
	check(bullet.consumed and inside_with_margin(bullet.position, settings.bullet_radius), "enemy projectile stops at each new wall without offscreen lingering")
	arena.enemy_bullets.remove_child(bullet)
	bullet.free()
	var arrow := BowArrow.new()
	arrow.position = edge_point(direction, 20)
	arrow.direction = direction
	arrow.arena_bounds = FIELD
	arrow.max_range = 5000
	arrow.enemies = arena.enemies
	arena.arrows.add_child(arrow)
	arrow._physics_process(1.0)
	check(arrow.retired, "ordinary outgoing arrow retires after leaving full playfield")
	arena.arrows.remove_child(arrow)
	arrow.free()

func test_pickup(direction: Vector2) -> void:
	arena.player.position = edge_point(direction, arena.stats.arena_padding)
	arena.pickups.clear()
	arena.xp = 0
	arena.pickups.append(arena.player.position)
	arena._physics_process(0.0)
	check(arena.pickups.is_empty() and arena.xp == arena.definition.pickup_value, "experience remains collectible at each new edge")

func test_mountainbreaker() -> void:
	var boss := arena.spawn_enemy("mountainbreaker", FIELD.get_center()) as Mountainbreaker
	for direction in DIRECTIONS:
		boss.reset_state()
		boss.position = FIELD.get_center()
		arena.player.position = edge_point(direction, arena.stats.arena_padding)
		boss._start_charge_warning()
		var endpoint := edge_point(direction, boss.radius)
		check(boss.charge_end.is_equal_approx(endpoint), "fixed distance charge warning clips to new wall with body radius")
		boss.ai_enabled = true
		boss._physics_process(boss.warning_duration)
		boss._physics_process(2.0)
		check(boss.position.is_equal_approx(endpoint) and boss.state == "recovery", "charge reaches new wall and stops")
		boss.reset_state()
		boss._start_rocks()
		check(not boss.rocks.is_empty(), "rocks have warning at each edge")
		for rock in boss.rocks:
			check(inside_with_margin(rock.global_position, rock.radius), "phase one rock warning fits full playfield")
			check_clip(rock)
		boss.force_phase_for_practice(2)
		boss._start_rocks()
		check(boss.rocks[0].global_position == arena.player.global_position, "tracking rock locks true edge position without old HUD offset")
		check_clip(boss.rocks[0])
		boss.force_phase_for_practice(1)
	arena.clear_enemies()

func test_beastcaller() -> void:
	var boss := arena.spawn_enemy("beastcaller", FIELD.get_center()) as Beastcaller
	boss.choice_rng.seed = 9221
	for direction in DIRECTIONS:
		arena.player.position = edge_point(direction, arena.stats.arena_padding)
		boss.force_phase_for_practice(1)
		var cluster := boss._summon_candidates()
		check(cluster.size() == 3, "full playfield admits three clustered summons")
		for at in cluster:
			check(inside_with_margin(at, boss.boss_definition.summon_body_radius), "cluster spawn remains visible within full playfield")
			check(at.distance_to(arena.player.position) >= boss.boss_definition.summon_clearance, "cluster preserves player safety distance")
		boss.force_phase_for_practice(2)
		var ring := boss._summon_candidates()
		check(not ring.is_empty() and ring.size() < 8, "edge summon ring omits out-of-bounds slots rather than crowding them")
		for at in ring:
			check(inside_with_margin(at, boss.boss_definition.summon_body_radius), "ring summons inside full playfield")
			check(is_equal_approx(at.distance_to(arena.player.position), boss.boss_definition.summon_ring_radius), "edge summons preserve radius rather than clamping into wall")
		boss.position = edge_point(direction, boss.radius)
		arena.player.position = boss.position - direction * 70
		boss.ai_enabled = true
		boss._move_ai(2.0)
		check(inside_with_margin(boss.position, boss.radius), "retreating summoner remains inside new wall")
	arena.clear_enemies()

func test_wildfire() -> void:
	var boss := arena.spawn_enemy("wildfire", FIELD.get_center()) as Wildfire
	boss.force_phase_for_practice(2)
	for direction in DIRECTIONS:
		arena.player.position = edge_point(direction, arena.stats.arena_padding)
		var hazard := boss._create_skyfire(arena.player.global_position, false)
		check(hazard.global_position == arena.player.global_position and hazard.contains(arena.player.global_position, arena.player.radius), "edge skyfire retains damage center matching its warning")
		check_clip(hazard)
		boss._main_impact(hazard)
		for item in boss.hazards:
			if item.splash: check(inside_with_margin(item.global_position, item.radius), "splash warnings remain inside full playfield")
		boss._start_rings()
		check(boss.hazards.is_empty(), "rings clear existing edge fireground")
		boss._release_ring()
		var ring: BossFireRing
		for child in boss.get_children():
			if child is BossFireRing: ring = child
		check(ring != null and ring.maximum_radius == FIELD.size.length(), "ring lifetime uses expanded playfield diagonal")
		check_clip(ring)
		var hit_count := [0]
		ring.hit.connect(func(_amount: float) -> void: hit_count[0] += 1)
		ring.ring_radius = 40
		ring._physics_process(8.0)
		check(hit_count[0] == 1, "swept ring hits edge player once despite long frame")
		boss.reset_state()
	arena.clear_enemies()

func check_clip(hazard: Node2D) -> void:
	var material := hazard.material as ShaderMaterial
	check(material != null and material.get_shader_parameter("arena_rect") == Vector4(0, 0, 1280, 800), "world hazard shader clips to full playfield without legacy HUD margins")
