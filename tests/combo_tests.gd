extends SceneTree
## Run: godot --headless --path . --script tests/combo_tests.gd
## Integrated deterministic tests: real main, arena, actors, projectiles and callbacks.
var game: Node
var arena: RageArena
var checks: int = 0
var failures: int = 0
var damage_events: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_run")

func expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)

func close(actual: float, wanted: float, label: String) -> void:
	expect(absf(actual - wanted) < 0.0001, "%s (actual=%s expected=%s)" % [label, actual, wanted])

func prepare(ranks: Dictionary) -> void:
	arena.clear_enemies()
	arena.apply_ranks(ranks)
	arena.stats.crit_chance = 0.0
	arena.stats.shields = 0
	arena.stats.hp = 50.0
	arena.rng.seed = 7319
	arena.player.regen_buff_left = 0.0
	arena.hits = 0
	arena.crits = 0
	arena.poison_hits = 0
	arena.bleed_hits = 0
	arena.total_damage = 0.0
	damage_events.clear()

func dummy(at: Vector2) -> EnemyActor:
	var target: EnemyActor = arena.spawn_enemy("dummy", at)
	target.damaged.connect(func(amount: float, critical: bool, _at: Vector2) -> void:
		damage_events.append({"amount": amount, "critical": critical})
	)
	return target

func arrow() -> CatArrow:
	var projectile: CatArrow = preload("res://scenes/projectiles/arrow.tscn").instantiate() as CatArrow
	arena.arrows.add_child(projectile)
	return projectile

func _run() -> void:
	game = preload("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.start_run(true)
	arena = game.arena as RageArena
	game.process_mode = Node.PROCESS_MODE_DISABLED
	arena.bow.enabled = false
	_first_hit_ordering()
	_piercing_crit_retention()
	_spread_limits()
	_dot_clocks_and_no_procs()
	_regen_refresh()
	_catalog_limit()
	print("COMBO INTEGRATION: %d checks, %d failures" % [checks, failures])
	game.free()
	quit(0 if failures == 0 else 1)

func _first_hit_ordering() -> void:
	prepare({"poison": 1, "poison_crit": 3, "spread": 1})
	var target: EnemyActor = dummy(Vector2(300, 300))
	var neighbor: EnemyActor = dummy(Vector2(330, 300))
	var projectile: CatArrow = arrow()
	arena._on_arrow_hit(projectile, target)
	close(100000.0 - target.health, arena.stats.arrow_damage, "First poison application is not retroactively critical")
	expect(target.status.has_poison(), "First arrow applies poison")
	expect(arena.crits == 0 and arena.hits == 1, "Real callback counts clean first hit")
	expect(not projectile.spread_used and not neighbor.status.has_poison(), "Fresh poison does not spread on its application hit")
	arena._on_arrow_hit(projectile, target)
	close(float(damage_events.back().amount), arena.stats.arrow_damage * arena.stats.crit_multiplier, "Second hit on pre-poisoned target guarantees critical")
	expect(arena.crits == 1 and arena.hits == 2, "Real callback counts guaranteed critical")
	expect(projectile.spread_used and neighbor.status.has_poison(), "Second hit spreads existing poison")

func _piercing_crit_retention() -> void:
	prepare({"poison": 1, "poison_crit": 3, "pierce": 2})
	var first: EnemyActor = dummy(Vector2(250, 300))
	var second: EnemyActor = dummy(Vector2(350, 300))
	var third: EnemyActor = dummy(Vector2(450, 300))
	second.status.apply_poison(3.0)
	third.status.apply_poison(3.0)
	var projectile: CatArrow = arrow()
	projectile.position = Vector2(200, 300)
	projectile.direction = Vector2.RIGHT
	projectile.speed = 300.0
	projectile.max_range = 1000.0
	projectile.arena_bounds = arena.bounds
	projectile.enemies = arena.enemies
	projectile.max_hits = arena.stats.pierce_max_hits
	projectile.decay = arena.stats.pierce_retention
	projectile.enemy_hit.connect(arena._on_arrow_hit)
	projectile._physics_process(1.0)
	close(100000.0 - first.health, arena.stats.arrow_damage, "Actual projectile first target retains full damage")
	close(100000.0 - second.health, arena.stats.arrow_damage * 0.85 * 2.0, "Actual projectile second target combines decay and poison crit")
	close(100000.0 - third.health, arena.stats.arrow_damage * 0.85 * 2.0, "Actual projectile third target keeps the same retained percentage before crit")
	expect(arena.hits == 3 and arena.crits == 2, "Projectile signal drives all three arena hit callbacks")
	expect(projectile.hit_ids.size() == 3 and not projectile.can_hit(first.get_instance_id()), "Piercing never re-hits same target")
	expect(projectile.is_queued_for_deletion(), "Piercing stops at configured hit count")

func _spread_limits() -> void:
	prepare({"poison": 1, "spread": 1})
	var source: EnemyActor = dummy(Vector2(300, 300))
	var nearby: Array[EnemyActor] = []
	for x: float in [315.0, 325.0, 340.0, 345.0]:
		nearby.append(dummy(Vector2(x, 300)))
	var chained: EnemyActor = dummy(Vector2(390, 300))
	var other_source: EnemyActor = dummy(Vector2(700, 300))
	var other_neighbor: EnemyActor = dummy(Vector2(720, 300))
	source.status.apply_poison(3.0)
	other_source.status.apply_poison(3.0)
	var projectile: CatArrow = arrow()
	arena._on_arrow_hit(projectile, source)
	var poisoned: int = 0
	for target: EnemyActor in nearby:
		if target.status.has_poison(): poisoned += 1
	expect(poisoned == arena.stats.spread_max_targets, "Spread obeys configured maximum target count")
	expect(not chained.status.has_poison(), "Spread cannot recursively propagate through newly poisoned neighbor")
	expect(arena.hits == 1 and damage_events.size() == 1, "Spread is status-only, not additional direct hits")
	arena._on_arrow_hit(projectile, other_source)
	expect(not other_neighbor.status.has_poison(), "Same arrow cannot spread a second time at later pierced target")
	for target: EnemyActor in nearby:
		target._physics_process(0.5)
	expect(not chained.status.has_poison(), "DOT ticks never trigger recursive spread")

func _dot_clocks_and_no_procs() -> void:
	prepare({"poison": 1, "bleed": 1, "poison_crit": 3, "bleed_regen": 1, "spread": 1})
	arena.stats.crit_chance = 1.0
	var target: EnemyActor = dummy(Vector2(300, 300))
	var neighbor: EnemyActor = dummy(Vector2(330, 300))
	target.status.apply_poison(6.0, 4.0)
	target._physics_process(0.25)
	expect(damage_events.is_empty(), "Poison does not tick before half-second boundary")
	target.status.apply_bleed(8.0, 4.0)
	target.status.apply_poison(6.0, 4.0)
	target._physics_process(0.25)
	close(100000.0 - target.health, 3.0, "Poison refresh preserves pending tick, bleed has independent clock")
	target._physics_process(0.25)
	close(100000.0 - target.health, 7.0, "Bleed ticks separately at its own half-second boundary")
	target._physics_process(0.25)
	close(100000.0 - target.health, 10.0, "Poison continues its original cadence")
	for event: Dictionary in damage_events:
		expect(not bool(event.critical), "DOT emits non-critical damage despite 100% direct crit chance")
	expect(arena.hits == 0 and arena.crits == 0, "DOT never increments direct-hit or critical counters")
	close(arena.player.regen_buff_left, 0.0, "DOT does not grant bleed regeneration buff")
	close(arena.stats.hp, 50.0, "DOT does not instantly sustain player")
	expect(not neighbor.status.has_poison(), "DOT never propagates contagion")

func _regen_refresh() -> void:
	prepare({"bleed": 1, "bleed_regen": 1})
	var target: EnemyActor = dummy(Vector2(300, 300))
	var projectile: CatArrow = arrow()
	arena._on_arrow_hit(projectile, target)
	close(arena.player.regen_buff_left, 0.0, "First bleed application does not retroactively activate sustain")
	arena._on_arrow_hit(projectile, target)
	close(arena.player.regen_buff_left, 3.0, "Direct hit against existing bleed activates three-second buff")
	close(arena.stats.hp, 50.0, "Sustain trigger grants no instantaneous healing")
	arena.player._physics_process(0.5)
	close(arena.stats.hp, 50.0 + arena.stats.bleed_regen * 0.5, "Active buff heals over elapsed time")
	close(arena.player.regen_buff_left, 2.5, "Buff duration counts down")
	var hp_before: float = arena.stats.hp
	arena._on_arrow_hit(projectile, target)
	close(arena.player.regen_buff_left, 3.0, "Repeated direct hit refreshes instead of stacks buff duration")
	close(arena.stats.hp, hp_before, "Refreshing buff adds no instant healing")
	arena.player.regen_buff_left = 0.0
	arena.player._physics_process(0.5)
	close(arena.stats.hp, hp_before, "Expired sustain buff stops healing")

func _catalog_limit() -> void:
	var catalog: UpgradeCatalog = UpgradeCatalog.new()
	expect(catalog.eligible({"poison": 1}).has("poison_crit"), "Poison unlocks guaranteed-critical upgrade")
	expect(not catalog.eligible({"poison": 1, "poison_crit": 3}).has("poison_crit"), "Owned maximum-rank poison critical upgrade cannot be offered again")
