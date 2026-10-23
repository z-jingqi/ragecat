extends SceneTree
## Deterministic real arena damage/feedback coverage for non-stacking fire burn.
var arena: RageArena
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)
func near(actual: float, expected: float, label: String) -> void:
	check(absf(actual - expected) < 0.001, "%s: actual=%s expected=%s" % [label, actual, expected])
func reset(ranks: Dictionary = {"fire_enchant": 3, "fire_bow": 3}) -> void:
	arena.clear_enemies()
	arena.apply_ranks(ranks)
	arena.stats.crit_chance = 0.0
	arena.stats.knockback = 0.0
	arena.rng.seed = 717
	if arena.stats.element_skill != null:
		arena.stats.element_skill.burn_chance_by_rank = PackedFloat32Array([0, 1, 1, 1])
func target(at := Vector2(400, 350), hp := 10000.0) -> EnemyActor:
	var enemy := arena.spawn_enemy("dummy", at)
	enemy.max_health = hp
	enemy.health = hp
	return enemy
func hit(enemy: EnemyActor, scale := 1.0, fragment := false, retention := 1.0) -> void:
	var arrow := CatArrow.new()
	arrow.damage_scale = scale
	arrow.retention = retention
	arrow.secondary = fragment
	arrow.impact_position = enemy.position
	arena._on_arrow_hit(arrow, enemy)
	arrow.free()
func burn(enemy: EnemyActor) -> BurnEffect:
	return arena.element_procs.burns.get(enemy.get_instance_id()) as BurnEffect
func tick(seconds: float) -> void: arena.element_procs._physics_process(seconds)

func source_snapshot_tests() -> void:
	for rank in range(1, 4):
		for fragment: bool in [false, true]:
			reset({"fire_enchant": 3, "fire_bow": rank, "damage": 2, "burst": 2})
			arena.stats.combat_definition.total_crit_chance_cap = 1.0 # Isolate critical damage formula, not production chance.
			arena.stats.crit_chance = 1.0
			var primary := target()
			var splash := target(primary.position + Vector2(0, 40))
			var coefficient := 0.55 * (0.6 if fragment else 1.0)
			var source_e := 15.0 * 1.4 * 0.45 * coefficient
			var expected_dps: float = source_e * [0.0, 0.2, 0.3, 0.4][rank]
			hit(primary, coefficient, fragment)
			check(burn(primary) != null and burn(splash) != null, "rank%d direct and blast both eligible, fragment=%s" % [rank, fragment])
			near(burn(primary).dps, expected_dps, "direct DPS uses precrit scaled source E")
			near(burn(splash).dps, expected_dps, "blast DPS excludes explosion multiplier")
			var before_primary := primary.health
			var before_splash := splash.health
			var before_hits := arena.hits
			var before_crits := arena.crits
			var before_procs := arena.element_procs.proc_counts.duplicate()
			var before_damage := arena.total_damage
			tick(0.25)
			near(before_primary - primary.health, expected_dps * 0.25, "direct burn fixed quarter-second damage")
			near(before_splash - splash.health, expected_dps * 0.25, "blast burn fixed quarter-second damage")
			near(arena.total_damage - before_damage, expected_dps * 0.5, "burn included in arena practice accounting")
			check(arena.hits == before_hits and arena.crits == before_crits and arena.element_procs.proc_counts == before_procs, "DOT has no direct hit, crit, blast or recursive proc")
			var popup := arena.effects.get_child(arena.effects.get_child_count() - 1) as FloatingText
			check(popup.element_type == "fire" and popup.damage_kind == "element" and not popup.critical, "burn popup typed F, elemental only, never CRIT")

func refresh_and_time_tests() -> void:
	reset()
	var enemy := target()
	hit(enemy)
	var state := burn(enemy)
	var original_dps := state.dps
	tick(0.1)
	var before := enemy.health
	# Both weaker and stronger arrows preserve the original burn snapshot.
	hit(enemy, 0.1)
	hit(enemy, 4.0)
	check(burn(enemy) == state and arena.element_procs.burns.size() == 1, "one singleton after multiple same-frame hits")
	near(state.dps, original_dps, "refresh never changes existing DPS")
	near(state.accrued, 0.1, "refresh never resets tick phase")
	near(state.remaining, 3.0, "refresh restores duration only")
	before = enemy.health
	tick(0.14)
	near(enemy.health, before, "refresh does not add instant tick")
	tick(0.01)
	near(before - enemy.health, original_dps * 0.25, "original quarter-second deadline remains")
	tick(50.0)
	near(before - enemy.health, original_dps * 3.1, "large delta caps lifetime and includes final partial tick")
	check(burn(enemy) == null, "expired burn removed")
	before = enemy.health
	tick(50.0)
	near(enemy.health, before, "no damage after expiry")
	hit(enemy, 0.1)
	near(burn(enemy).dps, original_dps * 0.1, "new burn after expiry snapshots new source")
	reset()
	arena.stats.element_skill.burn_duration = 0.63
	enemy = target()
	hit(enemy)
	before = enemy.health
	tick(5.0)
	near(before - enemy.health, 6.0 * 0.63, "nonmultiple duration exact DPS integral")
	check(burn(enemy) == null, "fractional final tick removes burn")
	reset()
	enemy = target()
	hit(enemy)
	before = enemy.health
	for i in range(180): tick(1.0 / 60.0)
	near(before - enemy.health, 18.0, "180 game frames deliver exactly 3 seconds of DPS")

func eligibility_and_lifecycle_tests() -> void:
	reset({"fire_enchant": 3})
	var enemy := target()
	hit(enemy)
	check(burn(enemy) == null, "plain enchant cannot burn")
	reset()
	arena.stats.element_skill.burn_chance_by_rank = PackedFloat32Array([0, 0, 0, 0])
	enemy = target()
	hit(enemy)
	check(burn(enemy) == null, "zero chance cannot burn")
	reset()
	enemy = target()
	arena.element_procs._try_burn(enemy, 15.0, arena.stats.element_skill, 3, "dot")
	check(burn(enemy) == null, "explicit DOT eligibility is rejected")
	arena.deal_element_damage(enemy, 15.0, "fire")
	check(burn(enemy) == null, "derived elemental API alone cannot apply burn")
	hit(enemy)
	var before := enemy.health
	arena.apply_ranks({"ice_enchant": 3, "ice_bow": 3})
	tick(5.0)
	check(arena.element_procs.burns.is_empty(), "element switch clears burn")
	near(enemy.health, before, "switch leaves no delayed burn")
	reset()
	enemy = target(Vector2(400, 350), 1.0)
	var splash := target(Vector2(400, 390))
	hit(enemy)
	check(enemy.is_dead and burn(enemy) == null, "lethal direct never burns dead target")
	check(burn(splash) != null, "lethal direct still blasts and burns survivor")
	reset()
	enemy = target()
	hit(enemy)
	enemy.health = 0.5
	var kills_before := arena.kills
	var damage_before := arena.total_damage
	enemy.is_dummy = false # Ordinary target for the real kill/XP contract; dummies never grant progression.
	arena.practice = false
	var pickups_before := arena.pickups.size()
	tick(10.0)
	check(enemy.is_dead and arena.kills == kills_before + 1, "burn lethal damage counts kill once")
	near(arena.total_damage - damage_before, 0.5, "burn overkill accounting caps actual HP")
	check(arena.pickups.size() == pickups_before + 1, "burn kill creates ordinary XP pickup")
	check(burn(enemy) == null, "lethal burn removes state")
	arena.practice = true
	reset()
	enemy = target()
	hit(enemy)
	before = enemy.health
	arena.enemies.remove_child(enemy)
	tick(1.0)
	near(enemy.health, before, "removed target cannot take burn damage")
	check(arena.element_procs.burns.is_empty(), "removed target pruned")
	enemy.free()
	reset()
	enemy = target()
	hit(enemy)
	enemy.free()
	tick(1.0)
	check(arena.element_procs.burns.is_empty(), "freed target safely pruned via weak reference")
	reset()
	enemy = target()
	hit(enemy)
	arena.clear_enemies()
	check(arena.element_procs.burns.is_empty(), "practice cleanup clears all burn state")

func resource_and_retention_tests() -> void:
	var authored := load("res://resources/elements/fire.tres") as ElementSkillDefinition
	for rank in range(1, 4):
		near(authored.parameter(authored.burn_chance_by_rank, rank), [0.0, 0.2, 0.3, 0.4][rank], "authored burn chance rank%d" % rank)
		near(authored.parameter(authored.burn_dps_by_rank, rank), [0.0, 0.2, 0.3, 0.4][rank], "authored DPS coefficient rank%d" % rank)
	near(authored.burn_duration, 3.0, "authored duration")
	near(authored.burn_tick_interval, 0.25, "authored tick")
	reset()
	var enemy := target()
	hit(enemy, 0.55 * 0.6, true, 0.95)
	near(burn(enemy).dps, 15.0 * 0.55 * 0.6 * 0.95 * 0.4, "source retention included exactly once")
	# A synchronous cleanup during a damage event must stop later large-frame ticks.
	var events := [0]
	enemy.damaged.connect(func(_amount: float, _critical: bool, _at: Vector2) -> void:
		events[0] += 1
		arena.element_procs.clear())
	tick(3.0)
	check(events[0] == 1, "reentrant clear stops remaining queued DOT ticks")

func pause_test() -> void:
	reset()
	var enemy := target()
	hit(enemy)
	var before := enemy.health
	var remaining := burn(enemy).remaining
	arena.bow.enabled = false
	arena.process_mode = Node.PROCESS_MODE_PAUSABLE
	paused = true
	for i in range(5): await process_frame
	near(enemy.health, before, "paused tree deals no DOT")
	near(burn(enemy).remaining, remaining, "paused tree freezes duration")
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	paused = false

func run() -> void:
	arena = RageArena.new()
	arena.practice = true
	root.add_child(arena)
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	source_snapshot_tests()
	refresh_and_time_tests()
	eligibility_and_lifecycle_tests()
	resource_and_retention_tests()
	await pause_test()
	arena.free()
	print("FIRE BURN: %d checks, %d failures" % [checks, failures])
	await preload("res://tests/audio_teardown.gd").drain(self)
	quit(0 if failures == 0 else 1)
