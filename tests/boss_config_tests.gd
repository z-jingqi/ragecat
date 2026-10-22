extends SceneTree

class Target:
	extends Node2D
	var radius: float = 16.0

var failures: int = 0
var checks: int = 0
var damage_received: float = 0.0
var impact_count: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func has_export(object: Object, property_name: String) -> bool:
	for info: Dictionary in object.get_property_list():
		if info.name == property_name:
			return (int(info.usage) & PROPERTY_USAGE_EDITOR) != 0 and (int(info.usage) & PROPERTY_USAGE_STORAGE) != 0
	return false

func on_attack(damage: float) -> void:
	damage_received += damage

func on_impact(_center: Vector2, _radius: float) -> void:
	impact_count += 1

func disable_rocks(boss: BossActor) -> void:
	for rock: RockWarning in boss.rocks:
		rock.set_physics_process(false)

func rock_centers(boss: BossActor) -> Array[Vector2]:
	var centers: Array[Vector2] = []
	for rock: RockWarning in boss.rocks:
		centers.append(rock.global_position)
	return centers

func run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var player := Target.new()
	world.add_child(player)
	var boss := BossActor.new()
	check(boss.max_health == 1500.0 and boss.health == 1500.0, "standalone boss retains baseline HP")
	check(boss.radius == 34.0 and boss.speed == 32.0 and boss.tint == Color("#e88b64"), "standalone boss retains baseline body defaults")
	check(is_equal_approx(boss.phase_time, 0.8) and is_equal_approx(boss.recovery_duration, 1.15), "baseline initial and recovery timers are preserved")
	check(boss.charge_timeout == 5.0 and boss.rock_count == 5, "baseline timeout and rock count are preserved")
	check(is_equal_approx(boss.rock_min_warning_duration, 0.7) and is_equal_approx(boss.rock_warning_offset, 0.3) and is_equal_approx(boss.rock_recovery_delay, 0.3), "baseline rock timing is preserved")
	check(is_equal_approx(boss.rock_damage_multiplier, 0.8) and is_equal_approx(boss.rock_aftermath_duration, 0.28), "baseline impact and aftermath are preserved")
	for property_name: String in [
		"max_health", "radius", "speed", "tint",
		"ability_mode", "start_with_charge", "attack_damage", "fallback_target_radius",
		"initial_recovery_duration", "recovery_duration", "warning_duration", "charge_timeout",
		"charge_distance", "charge_width", "charge_speed", "charge_stop_tolerance",
		"rock_radius", "rock_count", "rock_min_warning_duration", "rock_warning_offset",
		"rock_recovery_delay", "rock_aftermath_duration", "rock_damage_multiplier",
		"rock_pattern_seed", "rock_ring_offset", "rock_min_separation",
		"rock_spacing_random_min", "rock_spacing_random_max", "rock_search_rings", "rock_angular_samples"
	]:
		check(has_export(boss, property_name), "%s is an editable serialized boss property" % property_name)
	boss.max_health = 333.0
	check(boss.health == 333.0, "fresh standalone max-health override initializes full HP")
	boss.health = 111.0
	boss.initial_recovery_duration = 2.4
	boss.start_with_charge = false
	boss.radius = 24.0
	boss.speed = 50.0
	boss.tint = Color.GREEN
	boss.set_physics_process(false)
	world.add_child(boss)
	check(boss.max_health == 333.0 and boss.health == 111.0, "adding to tree preserves explicit arena health override")
	check(boss.radius == 24.0 and boss.speed == 50.0 and boss.tint == Color.GREEN, "adding to tree preserves inherited overrides")
	check(is_equal_approx(boss.phase_time, 2.4) and not boss.next_is_charge, "pre-tree opening timer and first attack overrides are consumed")
	boss.target = player
	boss.arena_bounds = Rect2(0, 0, 800, 600)
	boss.position = Vector2(200, 300)
	player.position = Vector2(500, 300)
	boss.attack_player.connect(on_attack)
	boss.warning_duration = 0.1
	boss.charge_timeout = 0.4
	boss.charge_distance = 120.0
	boss.charge_speed = 60.0
	boss.charge_width = 90.0
	boss.recovery_duration = 3.0
	boss._start_charge_warning()
	check(boss.charge_end == Vector2(320, 300) and is_equal_approx(boss.phase_time, 0.1), "charge warning consumes distance and warning overrides")
	boss._physics_process(0.1)
	check(boss.state == "charge" and is_equal_approx(boss.phase_time, 0.4), "charge consumes timeout override")
	boss._physics_process(0.4)
	check(boss.position == Vector2(224, 300), "charge consumes speed override")
	check(boss.state == "recovery" and is_equal_approx(boss.phase_time, 3.0), "timeout transitions into configured recovery")
	boss.reset_state()
	check(is_equal_approx(boss.phase_time, 2.4) and not boss.next_is_charge, "reset consumes opening properties without fixed literals")
	boss.charge_stop_tolerance = 81.0
	boss.charge_distance = 100.0
	boss.charge_speed = 40.0
	boss.charge_timeout = 10.0
	boss._start_charge_warning()
	boss._physics_process(boss.warning_duration)
	boss._physics_process(0.5)
	check(boss.state == "recovery", "charge consumes configurable stop tolerance")

	boss.reset_state()
	player.position = Vector2(400, 300)
	boss.warning_duration = 0.4
	boss.rock_warning_offset = 0.2
	boss.rock_min_warning_duration = 0.9
	boss.rock_recovery_delay = 0.4
	boss.rock_aftermath_duration = 1.1
	boss.rock_radius = 20.0
	boss.rock_count = 3
	boss.attack_damage = 80.0
	boss.rock_damage_multiplier = 0.25
	boss.rock_spacing_random_min = 1.0
	boss.rock_spacing_random_max = 1.0
	boss.rock_pattern_seed = 19
	boss._start_rocks()
	disable_rocks(boss)
	check(boss.rocks.size() == 3, "rock attack consumes configurable count")
	check(is_equal_approx(boss.phase_time, 1.3), "rock phase uses configured minimum warning and tail")
	for rock: RockWarning in boss.rocks:
		check(rock.radius == 20.0 and is_equal_approx(rock.warning_duration, 0.9), "spawned warning receives radius and duration")
		check(is_equal_approx(rock.aftermath_duration, 1.1), "spawned warning receives aftermath override")
	check(is_equal_approx(boss.rocks[1].global_position.distance_to(player.global_position), 66.0), "rock ring offset and spacing control placement distance")
	boss._rock_impact(player.global_position, boss.rock_radius)
	check(is_equal_approx(damage_received, 20.0), "rock impact consumes configurable damage multiplier")
	var centers: Array[Vector2] = rock_centers(boss)
	boss.reset_state()
	boss.rock_pattern_seed = 19
	boss._start_rocks()
	disable_rocks(boss)
	check(rock_centers(boss) == centers, "setting exported seed reproduces a rock pattern")
	boss.reset_state()
	boss.rock_pattern_seed = 19
	boss.rock_ring_offset = 4.0
	boss._start_rocks()
	disable_rocks(boss)
	check(is_equal_approx(boss.rocks[1].global_position.distance_to(player.global_position), 100.0), "changed ring offset changes the next attack")
	boss.reset_state()
	boss.warning_duration = 1.1
	boss._start_rocks()
	disable_rocks(boss)
	check(is_equal_approx(boss.rocks[0].warning_duration, 1.3), "warning duration plus configured offset can exceed minimum")
	boss.reset_state()
	boss.rock_spacing_random_min = 1.2
	boss.rock_spacing_random_max = 0.8
	boss.rock_pattern_seed = 7
	boss._start_rocks()
	disable_rocks(boss)
	centers = rock_centers(boss)
	boss.reset_state()
	boss.rock_spacing_random_min = 0.8
	boss.rock_spacing_random_max = 1.2
	boss.rock_pattern_seed = 7
	boss._start_rocks()
	disable_rocks(boss)
	check(rock_centers(boss) == centers, "reversed spacing limits are normalized at use")
	boss.reset_state()
	boss.rock_count = 0
	boss._start_rocks()
	check(boss.rocks.is_empty(), "zero configured count disables rock creation")
	boss.reset_state()
	boss.rock_count = 1
	boss.rock_aftermath_duration = 5.0
	boss._start_rocks()
	disable_rocks(boss)
	var lingering: RockWarning = boss.rocks[0]
	lingering._physics_process(lingering.warning_duration)
	boss._start_rocks()
	disable_rocks(boss)
	var newest: RockWarning = boss.rocks[1]
	check(boss.rocks.size() == 2, "overlapping aftermath remains tracked across attacks")
	boss.ai_enabled = false
	boss._physics_process(0.0)
	check(not lingering.ai_enabled and not newest.ai_enabled, "AI pause reaches old and new warning generations")
	boss.reset_state()
	check(lingering.is_queued_for_deletion() and newest.is_queued_for_deletion(), "reset clears all overlapping warning generations")
	boss.ai_enabled = true
	for _index: int in range(BossActor.MAX_LIVE_ROCK_WARNINGS + 2):
		boss._start_rocks()
	check(boss.rocks.size() == BossActor.MAX_LIVE_ROCK_WARNINGS, "rapid attacks and long aftermath retain a bounded warning count")
	boss.reset_state()
	for property_name: String in [
		"attack_damage", "fallback_target_radius", "initial_recovery_duration", "recovery_duration",
		"warning_duration", "charge_timeout", "charge_distance", "charge_width",
		"charge_speed", "charge_stop_tolerance", "rock_min_warning_duration", "rock_warning_offset",
		"rock_recovery_delay", "rock_aftermath_duration", "rock_damage_multiplier",
		"rock_ring_offset", "rock_min_separation", "rock_spacing_random_min", "rock_spacing_random_max"
	]:
		for invalid: float in [-1.0, INF, NAN]:
			boss.set(property_name, invalid)
			var actual: float = float(boss.get(property_name))
			check(is_finite(actual) and actual >= 0.0, "%s rejects negative/non-finite configuration" % property_name)
	for invalid: float in [-10.0, 0.0, INF, NAN]:
		boss.rock_radius = invalid
		check(is_finite(boss.rock_radius) and boss.rock_radius > 0.0, "rock radius remains finite and positive")
	boss.rock_count = -5
	check(boss.rock_count == 0, "negative count clamps to zero")
	boss.rock_count = 100000
	check(boss.rock_count == BossActor.MAX_ROCK_COUNT, "large rock count is bounded")
	boss.rock_search_rings = 0
	boss.rock_angular_samples = -1
	check(boss.rock_search_rings == 1 and boss.rock_angular_samples == 1, "search dimensions cannot be zero")
	boss.rock_search_rings = 100000
	boss.rock_angular_samples = 100000
	check(boss.rock_search_rings == BossActor.MAX_ROCK_SEARCH_RINGS and boss.rock_angular_samples == BossActor.MAX_ROCK_ANGULAR_SAMPLES, "search dimensions are bounded")
	boss.ability_mode = "invalid"
	check(boss.ability_mode == "alternate", "invalid ability modes fall back predictably")
	boss.rock_radius = 1000.0
	boss.arena_bounds = Rect2(0, 0, 100, 100)
	var inset: Rect2 = boss._ability_safe_bounds(boss.rock_radius)
	check(inset.size.x >= 0.0 and inset.size.y >= 0.0, "oversized hazard radius never inverts safe bounds")
	boss._start_rocks()
	disable_rocks(boss)
	check(boss.rocks.size() == 1 and boss.rocks[0].global_position == Vector2(50, 50), "impossible pattern has a bounded finite fallback")
	boss.reset_state()
	boss.target = null
	boss._start_charge_warning()
	boss._start_rocks()
	check(boss.state == "recovery" and boss.rocks.is_empty(), "missing target safely prevents new attacks")
	var plain_target := Node2D.new()
	world.add_child(plain_target)
	boss.target = plain_target
	boss.fallback_target_radius = 23.0
	check(boss._target_radius() == 23.0, "target fallback radius is configurable")

	var warning := RockWarning.new()
	for property_name: String in ["radius", "warning_duration", "aftermath_duration"]:
		check(has_export(warning, property_name), "%s is an editable warning property" % property_name)
	warning.set_physics_process(false)
	world.add_child(warning)
	warning.warning_duration = 0.2
	warning.aftermath_duration = 0.5
	warning.impact.connect(on_impact)
	warning._physics_process(0.2)
	check(impact_count == 1 and warning.impacted, "configured warning clock triggers impact")
	warning._physics_process(0.4)
	check(not warning.is_queued_for_deletion() and impact_count == 1, "configured aftermath keeps warning alive without repeat damage")
	warning._physics_process(0.11)
	check(warning.is_queued_for_deletion(), "configured aftermath controls cleanup")
	var instant := RockWarning.new()
	instant.set_physics_process(false)
	world.add_child(instant)
	instant.radius = NAN
	instant.warning_duration = -1.0
	instant.aftermath_duration = INF
	check(instant.radius > 0.0 and instant.warning_duration == 0.0 and instant.aftermath_duration == 0.0, "invalid warning values are safe")
	instant.impact.connect(on_impact)
	instant._physics_process(0.01)
	check(impact_count == 2 and instant.is_queued_for_deletion(), "zero warning/aftermath impacts once and cleans up")

	var configured := BossActor.new()
	configured.max_health = 432.0
	configured.charge_speed = 123.0
	configured.initial_recovery_duration = 1.7
	configured.rock_pattern_seed = 42
	configured.rock_aftermath_duration = 0.6
	var packed := PackedScene.new()
	check(packed.pack(configured) == OK, "boss configuration can be packed")
	var restored := packed.instantiate() as BossActor
	check(restored.max_health == 432.0 and restored.health == 432.0, "serialized standalone HP applies without an arena")
	check(restored.charge_speed == 123.0 and is_equal_approx(restored.phase_time, 1.7), "serialized charge and opening timer overrides survive initialization")
	check(restored.rock_rng.seed == 42 and is_equal_approx(restored.rock_aftermath_duration, 0.6), "serialized seed and aftermath are consumed")
	configured.free()
	restored.free()
	world.free()
	print("Boss config tests: %d checks, %d failures" % [checks, failures])
	await preload("res://tests/audio_teardown.gd").drain(self)
	quit(1 if failures > 0 else 0)
