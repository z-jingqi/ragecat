extends SceneTree
## Independent integration checks: exercise real bow/projectile/enemy callbacks.
var checks := 0
var failures := 0
var arena: RageArena
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("GRAVITY FAIL: " + label)
func near(actual: float, expected: float, tolerance: float, label: String) -> void:
	check(absf(actual - expected) <= tolerance, "%s actual=%s expected=%s" % [label, actual, expected])
func setup(ranks: Dictionary = {}) -> void:
	if is_instance_valid(arena): arena.free()
	arena = RageArena.new()
	arena.practice = true
	root.add_child(arena)
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	var settings := {"element_type": "dark", "enchant_rank": 1, "element_skill_rank": 1}
	settings.merge(ranks, true)
	arena.apply_ranks(settings)
	arena.player.position = Vector2(350, 350)
func enemy_at(at: Vector2, kind: String = "chaser") -> EnemyActor:
	var enemy := arena.spawn_enemy(kind, at)
	enemy.max_health = 100000.0
	enemy.health = enemy.max_health
	enemy.speed = 0.0
	return enemy
func fire() -> CatArrow:
	arena.bow.shoot()
	for child in arena.arrows.get_children():
		if child is CatArrow and not child.is_queued_for_deletion(): return child
	return null
func live_arrows() -> int: return arena.bow.active_count(false) + arena.bow.active_count(true)
func projectile_contracts() -> void:
	for rank in range(1, 4):
		setup({"element_skill_rank": rank, "spread_arrow": 3, "burst": 3, "split": 3})
		var target := enemy_at(Vector2(650, 350))
		var arrow := fire()
		check(arrow != null, "rank %d creates gravity arrow" % rank)
		if arrow == null: continue
		near(arrow.speed, [180.0, 140.0, 110.0][rank - 1], 0.001, "rank flight speed")
		check(live_arrows() == 1, "fan/burst/split still one arrow")
		var origin := arrow.position
		arrow._physics_process(0.1)
		near(arrow.position.distance_to(origin), arrow.speed * 0.1, 0.01, "real straight flight")
		for repeat in range(5): arena.bow.shoot()
		check(live_arrows() == 1, "direct shoot cannot bypass single arrow cap")
		arrow._physics_process(300.0 / arrow.speed)
		check(not arrow.is_queued_for_deletion(), "direct-hit exhaustion never despawns gravity arrow")
		check(target.health < target.max_health, "direct damage was actually delivered")
		check(live_arrows() == 1, "direct hit does not spawn split fragments")
	setup({"element_skill_rank": 0})
	enemy_at(Vector2(600, 350))
	var normal := fire()
	check(normal != null and normal.speed > 180.0, "dark enchant without skill is ordinary arrow")
func configured_field(at: Vector2) -> GravityField:
	var field := GravityField.new()
	field.configure(arena.stats, arena.enemies, arena.deal_element_damage)
	arena.add_child(field)
	field.position = at
	return field
func movement_and_contact() -> void:
	setup()
	var field := configured_field(Vector2(550, 350))
	var light := enemy_at(Vector2(450, 350))
	var heavy := enemy_at(Vector2(450, 350))
	heavy.mass = 10.0
	field.attach_enemy(light)
	field.attach_enemy(heavy)
	check(light.contact_damage_suppressed(), "outer field suppresses contact before first enemy callback")
	check(light.gravity_velocity == Vector2.ZERO, "suppression does not require visible movement")
	for i in range(6):
		light._physics_process(1.0 / 60.0)
		heavy._physics_process(1.0 / 60.0)
	check(light.position.x > heavy.position.x and heavy.position.x > 450.0, "actual mass-dependent displacement")
	check(light.gravity_velocity.length() <= field.pull_speed_cap + 0.01, "pull velocity respects cap")
	var before := light.position
	light._physics_process(10.0)
	check(light.position.distance_to(before) <= before.distance_to(field.position) + 0.01, "oversized delta cannot overshoot tip")
	var outsider := enemy_at(Vector2(750, 350))
	field.attach_enemy(outsider)
	check(not outsider.contact_damage_suppressed(), "outside field remains contact damaging")
	var boss := enemy_at(Vector2(450, 350), "boss") as BossActor
	field.attach_enemy(boss)
	boss.state = "recovery"
	boss.phase_time = 10.0
	boss._physics_process(0.1)
	check(boss.position.x > 450.0, "boss recovery can be pulled")
	boss.state = "warning"
	boss.phase_time = 10.0
	before = boss.position
	boss.knockback(Vector2.RIGHT, 100.0)
	boss._physics_process(0.1)
	check(boss.position == before, "boss warning ignores gravity and external knockback")
	boss.gravity_contact_grace = 0.1
	boss.state = "charge"
	check(not boss.contact_damage_suppressed(), "boss charge overrides residual contact grace")
	light.position = field.position + Vector2(0, 90)
	light.gravity_velocity = Vector2.ZERO
	light.speed = 60.0
	light.target = arena.player
	light.ai_enabled = true
	before = light.position
	light._physics_process(0.1)
	check(light.position.x < before.x, "chaser AI continues along with vertical gravity pull")
	light.mass = -2.0
	check(light.mass > 0.0, "mass setter rejects nonpositive mass")
	light.mass = NAN
	check(is_finite(light.mass) and light.mass > 0.0, "mass setter rejects NaN")
	field.deactivate()
	check(light.gravity_source == null and light.gravity_velocity == Vector2.ZERO, "source removal clears pull state")
func dot_and_config() -> void:
	setup()
	var config := arena.stats.element_skill.gravity
	config = config.duplicate(true)
	config.outer_radius_by_rank = PackedFloat32Array([0, 123, 150, 170])
	config.inner_radius_by_rank = PackedFloat32Array([0, 37, 60, 70])
	config.damage_per_second_by_rank = PackedFloat32Array([0, 2.3, 3.0, 4.0])
	config.pull_speed_cap = 87.0
	var definitions: Array[UpgradeDefinition] = []
	for source: UpgradeDefinition in UpgradeCatalog.UPGRADES:
		var definition := source.validated_copy()
		if definition.upgrade_id == "dark_bow": definition.element_skill.gravity = config
		definitions.append(definition)
	arena.stats.character.upgrades = definitions
	arena.apply_ranks(arena.ranks)
	var field := configured_field(Vector2(600, 350))
	near(field.outer_radius, 123.0, 0.001, "custom outer radius reaches live field")
	near(field.inner_radius, 37.0, 0.001, "custom core radius reaches live field")
	near(field.pull_speed_cap, 87.0, 0.001, "custom speed cap reaches live field")
	var inside := enemy_at(field.position + Vector2(0, 20))
	var outside := enemy_at(field.position + Vector2(0, 38))
	var hp := inside.health
	field.tick(0.0)
	near(inside.health, hp, 0.001, "no free entry DOT")
	field.tick(0.19)
	near(inside.health, hp, 0.001, "DOT waits for fixed quantum")
	inside.position.y += 100.0
	field.tick(0.5)
	near(inside.health, hp, 0.001, "no outside damage or exposure accumulation")
	inside.position.y -= 100.0
	field.tick(0.01)
	near(hp - inside.health, 2.3, 0.01, "reentry pays only accumulated in-core exposure")
	near(outside.health, outside.max_health, 0.001, "outer-only target never takes core DOT")
	field.tick(0.4)
	near(hp - inside.health, 6.9, 0.02, "fixed tick exact elapsed damage")
	check(arena.hits == 0 and arena.crits == 0, "DOT does not increment direct or critical hit counters")
	check(arena.element_procs.proc_counts.dark == 0, "DOT does not recursively proc")
	check(inside.position == field.position + Vector2(0, 20), "DOT does not cause knockback")
	var invalid := GravityDefinition.new()
	invalid.minimum_speed = 0.0
	invalid.tick_interval = 0.0
	invalid.lifetime = -5.0
	invalid.minimum_gap = 0.0
	invalid = invalid.validated_copy()
	check(invalid.minimum_speed > 0.0 and invalid.tick_interval > 0.0 and invalid.lifetime > 0.0, "invalid config gets positive timing/speed floors")
	check(invalid.minimum_gap >= 0.3, "invalid config cannot disable required threat window")
func lifecycle_contracts() -> void:
	setup()
	enemy_at(Vector2(600, 350))
	var arrow := fire()
	var field := arrow.gravity_field
	check(field != null and field.is_active(), "gravity field is active at launch without hit")
	near(field.global_position.distance_to(arrow.global_position), 15.0, 0.001, "field is attached at arrow tip")
	arena.bow._physics_process(20.0)
	check(live_arrows() == 1, "in-flight time cannot queue another projectile")
	arrow.retire()
	near(arena.bow.gravity_gap_remaining, 0.5, 0.001, "full gap begins at actual retirement")
	arena.bow._physics_process(0.5)
	check(live_arrows() == 0, "same-frame expiry cannot spend gap using pre-expiry delta")
	arena.select_upgrade("fire_enchant")
	arena.select_upgrade("dark_enchant")
	arena.bow.shoot()
	check(live_arrows() == 0, "element switch away/back preserves gap")
	arena.clear_enemies()
	enemy_at(Vector2(600, 350))
	arena.bow.shoot()
	check(live_arrows() == 0, "practice clear cannot bypass gap")
	arena.select_upgrade("dark_bow")
	arena.bow.shoot()
	check(live_arrows() == 0, "skill rank change cannot bypass gap")
	await physics_frame
	arena.bow._physics_process(0.49)
	check(live_arrows() == 0, "not ready before full post-despawn gap")
	await physics_frame
	arena.bow._physics_process(0.011)
	check(live_arrows() == 1, "ready after full post-despawn gap")
	setup()
	enemy_at(Vector2(600, 350))
	arrow = fire()
	var victim := enemy_at(arrow.gravity_field.global_position + Vector2(1, 30))
	arrow.max_range = 1.0
	var hp := victim.health
	arrow._physics_process(2.0)
	near(victim.health, hp, 0.001, "range expiry clips field elapsed time, not full oversized delta")
	check(arrow.is_queued_for_deletion(), "range boundary retires arrow")
	setup()
	var contact := enemy_at(arena.player.position + Vector2(10, 0))
	arena.player.invulnerable = false
	arena.stats.shields = 0
	field = configured_field(arena.player.position)
	field.attach_enemy(contact)
	hp = arena.stats.hp
	arena._physics_process(0.01)
	near(arena.stats.hp, hp, 0.001, "contact callback before enemy physics still immune in field")
	field.deactivate()
	arena._physics_process(0.01)
	near(arena.stats.hp, hp, 0.001, "release grace prevents immediate contact hit")
	for i in range(4):
		await physics_frame
		contact._physics_process(0.04)
	arena._physics_process(0.0)
	check(arena.stats.hp < hp, "after .1s release grace actual contact damages player")
func movement_time_steps() -> void:
	var displacements: Array[float] = []
	for step in [1.0 / 30.0, 1.0 / 60.0, 1.0 / 120.0]:
		setup()
		var field := configured_field(Vector2(550, 350))
		var enemy := enemy_at(Vector2(450, 350))
		field.attach_enemy(enemy)
		for i in range(roundi(0.5 / step)): enemy._physics_process(step)
		displacements.append(enemy.position.x - 450.0)
		check(enemy.position.x > 450.0 and enemy.position.x <= 550.0, "real pull stays bounded at timestep %s" % step)
	check(absf(displacements[0] - displacements[2]) < 4.0, "30/120Hz pull integration stays within four pixels")
func swept_dot_contracts() -> void:
	var damage: Array[float] = []
	for subdivisions in [1, 140]:
		setup()
		enemy_at(Vector2(750, 350))
		var arrow := fire()
		var victim := enemy_at(Vector2(500, 380))
		var hp := victim.health
		arrow.max_range = 252.0
		for i in range(subdivisions): arrow._physics_process(1.4 / subdivisions)
		damage.append(hp - victim.health)
		check(victim.position == Vector2(500, 380), "sweep comparison target remains stationary")
	near(damage[0], damage[1], 0.001, "one-step full core traversal matches subdivided DOT")
	near(damage[0], 2.0, 0.01, "earned in-core ticks survive leaving core and source expiry")
func pause_contracts() -> void:
	setup()
	enemy_at(Vector2(650, 350))
	var arrow := fire()
	arena.process_mode = Node.PROCESS_MODE_INHERIT
	arena.bow.enabled = false
	var pos := arrow.position
	var age := arrow.gravity_field.age
	var lifetime := arrow.lifetime_remaining
	paused = true
	for i in range(3): await process_frame
	check(arrow.position == pos, "tree pause freezes projectile flight")
	near(arrow.gravity_field.age, age, 0.00001, "tree pause freezes field time")
	near(arrow.lifetime_remaining, lifetime, 0.00001, "tree pause freezes projectile lifetime")
	paused = false
	arena.process_mode = Node.PROCESS_MODE_DISABLED
func direct_budget_contracts() -> void:
	for pierce in range(4):
		setup({"pierce": pierce, "spread_arrow": 3, "burst": 3, "split": 3})
		arena.stats.crit_chance = 0.0
		var targets: Array[EnemyActor] = []
		for i in range(5): targets.append(enemy_at(Vector2(450 + 50 * i, 350)))
		var arrow := fire()
		# Disable DOT only in this fixture to isolate ordinary B+E impact packets.
		arrow.gravity_field.damage_per_second = 0.0
		arrow._physics_process(1.6)
		check(arrow.hit_ids.size() == 1 + pierce, "direct hit budget 1 + pierce rank %d" % pierce)
		check(not arrow.retired, "pierce exhaustion leaves field flying rank %d" % pierce)
		for i in range(5):
			var expected := 0.0
			if i == 0: expected = 20.0
			elif i <= pierce: expected = 20.0 * [0.70, 0.75, 0.85, 0.95][pierce]
			near(targets[i].max_health - targets[i].health, expected, 0.01, "rank %d target %d normal direct retained once" % [pierce, i])
		var hp := targets[0].health
		arrow.direction = Vector2.LEFT
		arrow._physics_process(1.0)
		near(targets[0].health, hp, 0.001, "same enemy cannot receive second direct hit")
		check(live_arrows() == 1, "no fan burst split extras after penetration")
	setup({"spread_arrow": 3, "burst": 3, "split": 3})
	enemy_at(Vector2(600, 350))
	fire()
	arena.select_upgrade("fire_enchant")
	arena.bow.shoot()
	check(live_arrows() == arena.stats.spread_arrow_count and live_arrows() > 1, "switch to fire restores ordinary fan immediately")
func conversion_matrix() -> void:
	var combinations := 0
	var rank_speeds: Array[float] = []
	for rank in range(1, 4):
		setup({"element_skill_rank": rank, "long_draw": 3})
		rank_speeds.append(arena.stats.arrow_speed)
		for burst in range(4):
			for fan in range(4):
				for split in range(4):
					combinations += 1
					setup({"element_skill_rank": rank, "burst": burst, "spread_arrow": fan, "split": split, "long_draw": 3})
					arena.stats.crit_chance = 0.0
					var target := enemy_at(Vector2(500, 350))
					var arrow := fire()
					var field := arrow.gravity_field
					var config := arena.stats.element_skill.gravity
					var label := "skill%d burst%d fan%d split%d" % [rank, burst, fan, split]
					near(field.outer_radius, config.parameter(config.outer_radius_by_rank, rank) * (1.0 + config.parameter(config.fan_outer_bonus, fan)), 0.001, label + " live outer conversion")
					near(field.inner_radius, config.parameter(config.inner_radius_by_rank, rank) * (1.0 + config.parameter(config.split_inner_bonus, split)), 0.001, label + " live inner conversion")
					check(field.outer_radius >= field.inner_radius, label + " valid concentric radii")
					var expected_dps := arena.stats.element_damage * config.parameter(config.damage_per_second_by_rank, rank) * (1.0 + config.parameter(config.burst_dot_bonus, burst))
					near(field.damage_per_second, expected_dps, 0.001, label + " live DOT conversion")
					near(arrow.speed, config.parameter(config.speed_by_rank, rank), 0.001, label + " long draw does not alter gravity speed")
					near(arrow.damage_scale, 1.0, 0.001, label + " no inherited side arrow penalty")
					near(arena.stats.burst_damage_multiplier, 1.0, 0.001, label + " no inherited burst penalty")
					# Invoke the real field damage callback, rather than just checking derived values.
					var dot_target := enemy_at(field.global_position + Vector2(0, 20))
					field.tick(config.tick_interval)
					near(dot_target.max_health - dot_target.health, expected_dps * config.tick_interval, 0.01, label + " real DOT packet uses converted damage")
					dot_target.position = Vector2(350, 550)
					field.damage_per_second = 0.0
					arrow._physics_process(140.0 / arrow.speed)
					near(target.max_health - target.health, 20.0, 0.01, label + " real impact has full B+E despite conversions")
					check(arena.bow.active_count(false) == 1 and arena.bow.active_count(true) == 0, label + " exactly one primary after impact")
					arena.bow._physics_process(10.0)
					check(arena.bow.burst_remaining == 0, label + " no queued burst while flying")
					arrow.retire()
					arena.bow.shoot()
					arena.bow._physics_process(10.0)
					check(live_arrows() == 0 and arena.bow.gravity_gap_remaining >= 0.3, label + " no same-frame post-removal extra arrow")
	check(combinations == 192, "all 192 skill/volley conversion combinations exercised")
	check(rank_speeds[0] > rank_speeds[1] and rank_speeds[1] > rank_speeds[2], "higher skill stays slower with maximum long draw")
func run() -> void:
	conversion_matrix()
	projectile_contracts()
	movement_and_contact()
	dot_and_config()
	movement_time_steps()
	swept_dot_contracts()
	direct_budget_contracts()
	await lifecycle_contracts()
	await pause_contracts()
	arena.free()
	print("GRAVITY RUNTIME CONTRACTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
