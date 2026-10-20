extends SceneTree
## Tunable edits must reach real runtime behavior and preview text, without
## changing source definitions or another run. No baseline tests are replaced.
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)

func near(actual: float, expected: float, label: String) -> void:
	check(is_equal_approx(actual, expected), "%s (got %.7f, expected %.7f)" % [label, actual, expected])

func exported(resource: Object, name: String) -> bool:
	for property: Dictionary in resource.get_property_list():
		if property.name == name:
			return bool(int(property.usage) & PROPERTY_USAGE_EDITOR)
	return false

func custom_character() -> CharacterDefinition:
	var cat := (load("res://resources/cat.tres") as CharacterDefinition).duplicate(true) as CharacterDefinition
	cat.upgrades.clear()
	for definition: UpgradeDefinition in UpgradeCatalog.UPGRADES:
		cat.upgrades.append(definition.duplicate(true) as UpgradeDefinition)
	return cat

func upgrade(cat: CharacterDefinition, key: String) -> UpgradeDefinition:
	for definition: UpgradeDefinition in cat.upgrades:
		if definition.upgrade_id == key: return definition
	return null

func check_exports() -> void:
	var cat := custom_character()
	for property: String in ["base_health", "base_move_speed", "base_pickup_radius", "collision_radius", "arena_padding", "dash_speed", "dash_duration", "dash_cooldown", "dash_grants_immunity", "hit_feedback_duration", "bow", "combat", "upgrades"]:
		check(exported(cat, property), "Character parameter is Inspector-editable: " + property)
	for property: String in ["base_crit_chance", "base_crit_multiplier", "base_damage_percent", "base_attack_speed", "base_regen", "hit_immunity", "status_tick_interval", "default_status_duration"]:
		check(exported(cat.combat, property), "Combat parameter is Inspector-editable: " + property)
	for property: String in ["damage", "rate", "projectile_speed", "projectile_range", "projectile_width", "knockback", "spawn_offset", "collision_width_scale", "primary_projectile_limit", "fragment_projectile_limit"]:
		check(exported(cat.bow, property), "Bow parameter is Inspector-editable: " + property)
	for property: String in ["values", "max_rank", "duration_by_rank", "retention_by_rank", "targets_by_rank", "spacing_by_rank", "base_count", "fragment_angles_degrees", "fan_spacing_degrees", "side_arrow_damage", "crit_per_shield", "description_template"]:
		check(exported(cat.upgrades[0], property), "Upgrade parameter is Inspector-editable: " + property)
	for definition: UpgradeDefinition in cat.upgrades:
		check(definition.max_rank == 3 and definition.values.size() == 4, "Default has exactly three ranks plus baseline: " + definition.upgrade_id)
		check("{" not in definition.description, "Description resolves all data tokens: " + definition.upgrade_id)

func check_config_and_independence() -> void:
	var cat := custom_character()
	cat.base_health = 175.0
	cat.base_move_speed = 321.0
	cat.base_pickup_radius = 123.0
	cat.collision_radius = 23.0
	cat.arena_padding = 26.0
	cat.dash_speed = 401.0
	cat.dash_duration = 0.4
	cat.dash_cooldown = 1.25
	cat.dash_grants_immunity = false
	cat.hit_feedback_duration = 0.7
	cat.combat.base_crit_chance = 0.2
	cat.combat.base_crit_multiplier = 2.5
	cat.combat.base_damage_percent = 12.0
	cat.combat.base_attack_speed = 0.7
	cat.combat.base_regen = 0.3
	cat.combat.hit_immunity = 0.25
	cat.combat.status_tick_interval = 0.25
	cat.combat.default_status_duration = 2.25
	cat.bow.damage = 31.0
	cat.bow.rate = 1.0
	cat.bow.projectile_speed = 411.0
	cat.bow.projectile_range = 333.0
	cat.bow.projectile_width = 8.0
	cat.bow.knockback = 17.0
	cat.bow.spawn_offset = 13.0
	cat.bow.collision_width_scale = 0.25
	cat.bow.primary_projectile_limit = 3
	cat.bow.fragment_projectile_limit = 3
	upgrade(cat, "poison").duration_by_rank = PackedFloat32Array([2, 6, 7, 8])
	upgrade(cat, "bleed").duration_by_rank = PackedFloat32Array([2, 5, 6, 7])
	upgrade(cat, "bleed_regen").duration_by_rank = PackedFloat32Array([0, 1.25, 2.5, 5])
	upgrade(cat, "pierce").retention_by_rank = PackedFloat32Array([0.9, 0.6, 0.5, 0.4])
	upgrade(cat, "spread").targets_by_rank = PackedInt32Array([0, 1, 2, 4])
	upgrade(cat, "burst").spacing_by_rank = PackedFloat32Array([0.25, 0.25, 0.25, 0.25])
	upgrade(cat, "split").fragment_angles_degrees = PackedFloat32Array([-40, 0, 40])
	upgrade(cat, "spread_arrow").fan_spacing_degrees = 20.0
	upgrade(cat, "spread_arrow").side_arrow_damage = 0.25
	upgrade(cat, "shield").crit_per_shield = 0.4
	var first := cat.create_stats()
	var second := cat.create_stats()
	var expected := {"max_hp":175.0, "hp":175.0, "move_speed":321.0, "pickup_radius":123.0, "collision_radius":23.0, "arena_padding":26.0, "dash_speed":401.0, "dash_duration":0.4, "dash_cooldown_duration":1.25, "hit_feedback_duration":0.7, "crit_chance":0.2, "crit_multiplier":2.5, "damage_percent":12.0, "attack_speed":0.7, "regen":0.3, "hit_immunity":0.25, "status_tick_interval":0.25, "arrow_damage":31.0, "arrow_rate":1.0, "arrow_speed":411.0, "arrow_range":333.0, "arrow_width":8.0, "knockback":17.0, "arrow_spawn_offset":13.0, "arrow_collision_width_scale":0.25, "primary_projectile_limit":3, "fragment_projectile_limit":3, "shield_crit_per_charge":0.4}
	for property: String in expected:
		near(float(first.get(property)), float(expected[property]), "Resource edit reaches run stat " + property)
	check(not first.dash_grants_immunity, "Dash immunity comes from character definition")
	var ranks := {"poison":1, "bleed":1, "bleed_regen":1, "pierce":1, "spread":1, "burst":2, "split":1, "spread_arrow":1, "shield":2}
	first.apply_ranks(ranks)
	near(first.poison_duration, 6.0, "Poison rank duration is data-driven")
	near(first.bleed_duration, 5.0, "Bleed rank duration is data-driven")
	near(first.bleed_regen_duration, 1.25, "Sustain rank duration is data-driven")
	near(first.pierce_retention, 0.6, "Retention rank has one source")
	check(first.spread_max_targets == 1, "Spread target cap is data-driven")
	near(first.burst_spacing, 0.25, "Burst spacing is data-driven")
	check(first.split_angles.size() == 3, "Fragment count comes from configured directions")
	near(first.split_angles[0], deg_to_rad(-40), "Fragment direction is configurable in degrees")
	near(first.fan_spread_angle, deg_to_rad(20), "Fan angle uses editable degrees")
	near(first.side_arrow_damage, 0.25, "Fan side-arrow damage comes from data")
	check("6s" in first.catalog.describe_change("poison", 0), "Poison preview shares runtime duration")
	check("5s" in first.catalog.describe_change("bleed", 0), "Bleed preview shares runtime duration")
	check("1.25s" in first.catalog.describe_change("bleed_regen", 0), "Sustain preview shares runtime duration")
	check("60% retained" in first.catalog.describe_change("pierce", 0), "Pierce preview shares retention rank array")
	check("1 targets" in first.catalog.describe_change("spread", 0), "Spread preview shares target cap")
	check("0.25s spacing" in first.catalog.describe_change("burst", 0), "Burst preview shares spacing")
	check("3 fragments" in first.catalog.describe_change("split", 0), "Split preview shares fragment count")
	check("25% damage" in str(first.catalog.definitions.spread_arrow.description), "Fan description shares side damage")
	check("40% crit" in str(first.catalog.definitions.shield.description), "Shield description shares crit bonus")
	first.hp = 37.0
	first.shields = 1
	first.split_angles[0] = 0.0
	first.catalog.definitions.poison.values[1] = 999.0
	ranks.poison = 3
	near(second.hp, 175.0, "HP is independent between runs")
	check(second.shields == 0 and second.ranks.is_empty(), "Shield/rank state is independent between runs")
	near(upgrade(cat,"poison").values[1], 3.0, "Legacy catalog view cannot mutate upgrade resource")
	near(upgrade(cat,"split").fragment_angles_degrees[0], -40.0, "Runtime fragment angles cannot mutate definition")
	near(cat.base_health, 175.0, "Runtime HP cannot mutate character baseline")
	check(int(first.ranks.poison) == 1, "Caller rank dictionary cannot mutate run state")
	first.apply_ranks(first.ranks)
	near(first.hp, 37.0, "Rank rebuild does not heal")
	near(first.poison_dps, 3.0, "Rank rebuild ignores mutated compatibility view")
	near(first.split_angles[0], deg_to_rad(-40), "Rank rebuild restores configured fragment direction")
	first.shields = 2
	check(CombatRules.resolve_direct(first, StatusEffects.new(), 10.0, 0.9).crit, "Configured shield crit bonus reaches resolver")
	first.shields = 0
	var health := HealthState.new(first)
	check(health.receive_hit(1).accepted, "First damage is accepted")
	health.tick(0.125)
	check(not health.receive_hit(1).accepted, "Configured immunity rejects premature damage")
	health.tick(0.125)
	check(health.receive_hit(1).accepted, "Configured immunity expires at configured time")
	var status := StatusEffects.new(cat.combat)
	status.apply_poison(8.0)
	near(status.poison_remaining, 2.25, "Omitted duration uses combat definition")
	near(status.tick(0.125), 0.0, "Configured DOT waits for its own period")
	near(status.tick(0.125), 2.0, "Configured DOT period changes real damage cadence")
	near(status.tick(2.0), 16.0, "Configured DOT clips total damage to duration")
	check(not status.has_poison(), "Configured DOT expires")
	check_runtime_nodes(first)
	upgrade(cat,"damage").max_rank = 1
	var limited := cat.create_stats()
	limited.apply_ranks({"damage":99})
	near(limited.damage_percent, 32.0, "Editable rank cap bounds runtime values")
	check(not limited.catalog.eligible({"damage":1}).has("damage"), "Editable rank cap bounds eligibility")
	check(limited.catalog.describe_change("damage",1) == "MAX RANK", "Editable rank cap bounds card preview")
	cat.base_health = 200.0
	cat.bow.damage = 99.0
	upgrade(cat, "poison").duration_by_rank[1] = 19.0
	first.apply_ranks(first.ranks)
	near(first.max_hp, 175.0, "Editing source character cannot change an active run")
	near(first.arrow_damage, 31.0, "Editing source bow cannot change an active run")
	near(first.poison_duration, 6.0, "Editing source rank array cannot change an active run")
	var next_run := cat.create_stats()
	next_run.apply_ranks({"poison":1})
	near(next_run.max_hp, 200.0, "New run picks up edited character")
	near(next_run.arrow_damage, 99.0, "New run picks up edited weapon")
	near(next_run.poison_duration, 19.0, "New run picks up edited upgrade array")

func check_invalid_configuration() -> void:
	var cat := custom_character()
	cat.base_health = -10.0
	cat.base_move_speed = NAN
	cat.dash_speed = -2.0
	cat.bow.damage = INF
	cat.bow.rate = -1.0
	cat.bow.fragment_projectile_limit = -9
	cat.combat.status_tick_interval = 0.000000000001
	cat.combat.base_crit_chance = 4.0
	upgrade(cat, "damage").values = PackedFloat32Array([0, NAN, -4, INF])
	upgrade(cat, "pierce").retention_by_rank = PackedFloat32Array([0, NAN, -1, 5])
	upgrade(cat, "split").fragment_angles_degrees = PackedFloat32Array([NAN, INF, 30])
	var stats := cat.create_stats()
	stats.apply_ranks({"damage":3,"pierce":3,"split":3})
	near(stats.max_hp, 1.0, "Invalid negative health is made safe in snapshot")
	near(stats.move_speed, CharacterDefinition.new().base_move_speed, "Nonfinite character field uses declared default")
	near(stats.dash_speed, 0.0, "Negative dash speed is clamped")
	near(stats.arrow_damage, BowDefinition.new().damage, "Nonfinite weapon field uses declared default")
	near(stats.arrow_rate, 0.0, "Negative fire rate is disabled")
	check(stats.fragment_projectile_limit == 0, "Negative budget is disabled")
	near(stats.status_tick_interval, 0.001, "Tiny tick interval respects Inspector minimum")
	near(stats.crit_chance, 1.0, "Crit chance is safely bounded")
	near(stats.damage_percent, 0.0, "Nonfinite rank value is neutral")
	near(stats.pierce_retention, 1.0, "Retention is bounded")
	check(stats.split_angles.size() == 1, "Nonfinite fragment directions are omitted")
	check(cat.base_health == -10.0 and is_nan(cat.base_move_speed), "Validation never edits source character")
	check(is_inf(cat.bow.damage) and is_inf(upgrade(cat,"damage").values[3]), "Validation never edits nested source definitions")
	var status := StatusEffects.new(stats.combat_definition)
	status.apply_poison(8.0, 2.0)
	near(status.tick(100.0), 16.0, "Tiny interval uses bounded analytic tick accounting")
	status.apply_bleed(INF, 2.0)
	check(not status.has_bleed(), "Nonfinite DOT application is rejected")

func buttons(node: Node) -> Array[Button]:
	var result: Array[Button] = []
	if node is Button: result.append(node)
	for child: Node in node.get_children():
		result.append_array(buttons(child))
	return result

func check_real_card_text() -> void:
	var cat := custom_character()
	upgrade(cat,"poison").duration_by_rank = PackedFloat32Array([2, 11, 11, 11])
	upgrade(cat,"bleed").duration_by_rank = PackedFloat32Array([2, 12, 12, 12])
	upgrade(cat,"bleed_regen").duration_by_rank = PackedFloat32Array([0, 7, 7, 7])
	upgrade(cat,"spread").targets_by_rank = PackedInt32Array([0, 5, 5, 5])
	upgrade(cat,"burst").spacing_by_rank = PackedFloat32Array([0.37, 0.37, 0.37, 0.37])
	upgrade(cat,"pierce").retention_by_rank = PackedFloat32Array([1, 0.42, 0.6, 0.8])
	upgrade(cat,"split").fragment_angles_degrees = PackedFloat32Array([-45, 0, 45])
	upgrade(cat,"spread_arrow").side_arrow_damage = 0.33
	upgrade(cat,"shield").crit_per_shield = 0.22
	var expected := {"poison":"11s", "bleed":"12s", "bleed_regen":"7s buff", "spread":"5 targets", "burst":"0.37s spacing", "pierce":"42% retained", "split":"3 fragments", "spread_arrow":"33% damage", "shield":"22% crit"}
	var game: Node = load("res://scenes/main.tscn").instantiate()
	game.character_definition = cat
	root.add_child(game)
	game.start_run(false)
	game.arena.process_mode = Node.PROCESS_MODE_DISABLED
	game.arena.bow.enabled = false
	for key: String in expected:
		var ranks: Dictionary = {}
		for definition: UpgradeDefinition in cat.upgrades: ranks[definition.upgrade_id] = 3
		ranks[key] = 0
		game.arena.apply_ranks(ranks)
		game.arena.stats.hp = game.arena.stats.max_hp
		game.arena.stats.shields = game.arena.stats.shield_capacity
		game.show_upgrades()
		var cards := buttons(game.overlay)
		check(cards.size() == 1, "Custom " + key + " produces one actual card")
		if not cards.is_empty():
			check(str(expected[key]) in cards[0].text, "Actual card displays edited " + key + " parameter")
			check(game.catalog.describe_change(key,0) in cards[0].text, "Actual " + key + " card and runtime catalog use identical preview")
			cards[0].pressed.emit()
			check(int(game.arena.stats.ranks.get(key,0)) == 1, "Actual " + key + " card callback updates run stats")
		else:
			game.resume_run()
	game.free()
	paused = false

func check_runtime_nodes(stats: CombatStats) -> void:
	var stage := Node2D.new()
	stage.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(stage)
	var player := CatPlayer.new()
	player.setup(stats)
	player.arena_bounds = Rect2(0,0,1000,1000)
	player.position = Vector2(300,300)
	player.movement_enabled = false
	stage.add_child(player)
	near(player.radius, 23.0, "Character hit radius uses resource")
	player.dash_left = stats.dash_duration
	player.dash_direction = Vector2.RIGHT
	player._physics_process(0.125)
	near(player.position.x, 350.125, "Real dash movement uses resource speed")
	player.health_state.invulnerability = 0.0
	var hp := stats.hp
	player.receive_hit(2.0)
	near(stats.hp, hp - 2.0, "Configured dash without immunity accepts damage")
	near(player.impact_left, 0.7, "Player feedback duration uses data")
	player.position = Vector2.ZERO
	player.dash_left = 0.0
	player._physics_process(0.0)
	check(player.position == Vector2(26,26), "Player boundary padding uses data")
	player.position = Vector2(300,300)
	var enemies := Node2D.new()
	var arrows := Node2D.new()
	stage.add_child(enemies)
	stage.add_child(arrows)
	var enemy := EnemyActor.new()
	enemy.position = Vector2(450,300)
	enemy.health = 1000.0
	enemy.is_dummy = true
	enemies.add_child(enemy)
	var bow := BowController.new()
	bow.setup(player, stats, enemies, arrows, player.arena_bounds)
	stage.add_child(bow)
	bow.shoot()
	check(arrows.get_child_count() == 3, "Configured primary budget admits complete fan")
	var source := arrows.get_child(1) as CatArrow
	near(source.width, 2.0, "Projectile radius uses bow width scale")
	near(source.position.distance_to(player.position), 13.0, "Projectile spawn offset uses data")
	near(source.speed, 411.0, "Configured projectile speed reaches actual arrow")
	near(source.max_range, 333.0, "Configured range reaches actual arrow")
	near(source.decay, 0.6, "Configured retention reaches actual arrow")
	near((arrows.get_child(0) as CatArrow).damage_scale, 0.25, "Actual side arrow uses configured damage")
	near((arrows.get_child(0) as CatArrow).direction.angle(), deg_to_rad(-20), "Actual fan uses configured angle")
	near(source.damage_scale, 1.0, "Center arrow remains full damage")
	bow.shoot()
	check(arrows.get_child_count() == 3, "Configured primary cap rejects complete extra fan")
	source.impact_position = enemy.position
	source.impact_traveled = 150.0
	bow._relay_arrow_hit(source, enemy)
	check(bow.active_count(true) == 3, "Actual impact spawns configured fragment count")
	for node: Node in arrows.get_children():
		var fragment := node as CatArrow
		if not fragment.secondary: continue
		check(fragment.max_hits == 1 and fragment.ignored_ids.has(enemy.get_instance_id()), "Fragment invariants remain single-hit and ignore source")
		near(fragment.damage_scale, 0.3, "Configured split ratio reaches actual fragment")
		near(fragment.traveled, 150.0, "Fragments retain shared traveled distance")
	var other := arrows.get_child(0) as CatArrow
	other.impact_traveled = 150.0
	bow._relay_arrow_hit(other, enemy)
	check(bow.active_count(true) == 3, "Configured fragment cap rejects whole extra split")
	for arrow: Node in arrows.get_children(): arrow.free()
	stats.spread_arrow_count = 1
	stats.attack_speed = 1.0
	stats.primary_projectile_limit = 10
	bow._physics_process(0.0)
	check(arrows.get_child_count() == 1, "First configured burst fires immediately")
	bow._physics_process(0.125)
	check(arrows.get_child_count() == 1, "Configured burst spacing prevents early second arrow")
	bow._physics_process(0.125)
	check(arrows.get_child_count() == 2, "Second burst fires at configured spacing")
	bow._physics_process(0.25)
	check(arrows.get_child_count() == 3, "Third burst retains configured cadence")
	stats.arrow_rate = 0.0
	bow.attack_clock = 0.0
	bow._physics_process(1.0)
	check(arrows.get_child_count() == 3, "Zero attack rate safely disables new volleys")
	stage.free()

func run() -> void:
	check_exports()
	check_config_and_independence()
	check_invalid_configuration()
	check_real_card_text()
	print("CONFIG COMBAT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
