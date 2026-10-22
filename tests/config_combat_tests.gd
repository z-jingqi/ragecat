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
	for property: String in ["base_health", "base_move_speed", "base_pickup_radius", "collision_radius", "arena_padding", "dash_speed", "dash_duration", "dash_cooldown", "dash_grants_immunity", "hit_feedback_duration", "bow", "combat", "upgrades", "element_capacity"]:
		check(exported(cat, property), "Character parameter is Inspector-editable: " + property)
	for property: String in ["base_crit_chance", "base_crit_multiplier", "base_damage_percent", "base_attack_speed", "base_regen", "hit_immunity"]:
		check(exported(cat.combat, property), "Combat parameter is Inspector-editable: " + property)
	for property: String in ["damage", "rate", "projectile_speed", "projectile_range", "projectile_width", "knockback", "spawn_offset", "collision_width_scale", "primary_projectile_limit", "fragment_projectile_limit"]:
		check(exported(cat.bow, property), "Bow parameter is Inspector-editable: " + property)
	for property: String in ["values", "max_rank", "duration_by_rank", "retention_by_rank", "targets_by_rank", "spacing_by_rank", "damage_multiplier_by_rank", "base_count", "fragment_angles_degrees", "fan_spacing_degrees", "side_arrow_damage", "crit_per_shield", "description_template"]:
		check(exported(cat.upgrades[0], property), "Upgrade parameter is Inspector-editable: " + property)
	for property: String in ["damage_by_rank", "radius_by_rank", "targets_by_rank", "duration_by_rank", "chain_range", "chill_fraction", "boss_chill_fraction", "chill_duration", "frost_threshold", "frost_window", "freeze_by_rank", "thaw_immunity", "shared_cooldown", "pull_speed", "pull_multiplier_cap"]:
		check(exported(upgrade(cat, "ice_bow").element_skill, property), "Element skill parameter is Inspector-editable: " + property)
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
	var ice := upgrade(cat, "ice_bow").element_skill
	ice.chill_duration = 6.0
	ice.chill_fraction = 0.35
	ice.boss_chill_fraction = 0.15
	ice.frost_window = 0.75
	ice.freeze_by_rank = PackedFloat32Array([0, 0.25, 0.5, 0.75])
	ice.thaw_immunity = 1.25
	upgrade(cat, "pierce").retention_by_rank = PackedFloat32Array([0.9, 0.6, 0.5, 0.4])
	upgrade(cat, "lightning_bow").element_skill.targets_by_rank = PackedInt32Array([0, 1, 2, 4])
	upgrade(cat, "burst").spacing_by_rank = PackedFloat32Array([0.25, 0.25, 0.25, 0.25])
	upgrade(cat, "split").fragment_angles_degrees = PackedFloat32Array([-40, 0, 40])
	upgrade(cat, "spread_arrow").fan_spacing_degrees = 20.0
	upgrade(cat, "spread_arrow").side_arrow_damage = 0.25
	upgrade(cat, "shield").crit_per_shield = 0.4
	var first := cat.create_stats()
	var second := cat.create_stats()
	var expected := {"max_hp":175.0, "hp":175.0, "move_speed":321.0, "pickup_radius":123.0, "collision_radius":23.0, "arena_padding":26.0, "dash_speed":401.0, "dash_duration":0.4, "dash_cooldown_duration":1.25, "hit_feedback_duration":0.7, "crit_chance":0.2, "crit_multiplier":2.5, "damage_percent":12.0, "attack_speed":0.7, "regen":0.3, "hit_immunity":0.25, "arrow_damage":31.0, "arrow_rate":1.0, "arrow_speed":411.0, "arrow_range":333.0, "arrow_width":8.0, "knockback":17.0, "arrow_spawn_offset":13.0, "arrow_collision_width_scale":0.25, "primary_projectile_limit":3, "fragment_projectile_limit":3, "shield_crit_per_charge":0.4}
	for property: String in expected:
		near(float(first.get(property)), float(expected[property]), "Resource edit reaches run stat " + property)
	check(not first.dash_grants_immunity, "Dash immunity comes from character definition")
	var ranks := {"element_type":"ice", "enchant_rank":1, "element_skill_rank":1, "pierce":1, "burst":2, "split":1, "spread_arrow":1, "shield":2}
	first.apply_ranks(ranks)
	near(first.element_skill.chill_duration, 6.0, "Ice chill duration is data-driven")
	near(first.element_skill.parameter(first.element_skill.freeze_by_rank, 1), 0.25, "Freeze rank duration is data-driven")
	near(first.element_skill.thaw_immunity, 1.25, "Thaw immunity is data-driven")
	near(first.element_damage, 5.6, "Elemental damage is supplied by enchantment and total damage bonus")
	near(first.pierce_retention, 0.6, "Retention rank has one source")
	check(first.catalog.definition("lightning_bow").element_skill.targets_by_rank[1] == 1, "Chain target cap is data-driven")
	near(first.burst_spacing, 0.25, "Burst spacing is data-driven")
	check(first.split_angles.size() == 3, "Fragment count comes from configured directions")
	near(first.split_angles[0], deg_to_rad(-40), "Fragment direction is configurable in degrees")
	near(first.fan_spread_angle, deg_to_rad(20), "Fan angle uses editable degrees")
	near(first.side_arrow_damage, 0.25, "Fan side-arrow damage comes from data")
	check("6s" in first.catalog.describe_change("ice_bow", 0), "Ice preview shares runtime chill duration")
	check("freeze 0.25s" in first.catalog.describe_change("ice_bow", 0), "Ice preview shares runtime freeze duration")
	check("immunity 1.25s" in first.catalog.describe_change("ice_bow", 0), "Ice preview shares runtime immunity")
	check("60% retained" in first.catalog.describe_change("pierce", 0), "Pierce preview shares retention rank array")
	check("1 additional targets" in first.catalog.describe_change("lightning_bow", 0), "Chain preview shares target cap")
	check("0.25s spacing" in first.catalog.describe_change("burst", 0), "Burst preview shares spacing")
	check("3 fragments" in first.catalog.describe_change("split", 0), "Split preview shares fragment count")
	check("25% damage" in str(first.catalog.definitions.spread_arrow.description), "Fan description shares side damage")
	check("40% crit" in str(first.catalog.definitions.shield.description), "Shield description shares crit bonus")
	first.hp = 37.0
	first.shields = 1
	first.split_angles[0] = 0.0
	first.catalog.definitions.ice_enchant.values[1] = 999.0
	ranks.element_skill_rank = 3
	near(second.hp, 175.0, "HP is independent between runs")
	check(second.shields == 0 and second.ranks.is_empty(), "Shield/rank state is independent between runs")
	near(upgrade(cat,"ice_enchant").values[1], 5.0, "Legacy catalog view cannot mutate upgrade resource")
	near(upgrade(cat,"split").fragment_angles_degrees[0], -40.0, "Runtime fragment angles cannot mutate definition")
	near(cat.base_health, 175.0, "Runtime HP cannot mutate character baseline")
	check(int(first.ranks.element_skill_rank) == 1, "Caller rank dictionary cannot mutate run state")
	first.apply_ranks(first.ranks)
	near(first.hp, 37.0, "Rank rebuild does not heal")
	near(first.element_damage, 5.6, "Rank rebuild ignores mutated compatibility view")
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
	var status := StatusEffects.new()
	status.apply_ice(first.element_skill, 1)
	near(status.chill_remaining, 6.0, "Configured ice duration reaches status runtime")
	near(status.movement_multiplier(), 0.65, "Configured ice fraction changes real movement")
	status.apply_ice(first.element_skill, 1)
	status.apply_ice(first.element_skill, 1)
	near(status.frozen_remaining, 0.25, "Configured freeze duration reaches runtime")
	status.tick(0.25)
	near(status.immunity_remaining, 1.25, "Configured immunity starts after thaw")
	status.tick(1.25)
	check(status.immunity_remaining == 0 and not status.is_frozen(), "Configured control clocks expire")
	status.clear()
	status.apply_ice(first.element_skill, 1, true)
	near(status.movement_multiplier(), 0.85, "Configured boss chill uses its separate fraction")
	check_runtime_nodes(first)
	upgrade(cat,"damage").max_rank = 1
	var limited := cat.create_stats()
	limited.apply_ranks({"damage":99})
	near(limited.damage_percent, 32.0, "Editable rank cap bounds runtime values")
	check(not limited.catalog.eligible({"damage":1}).has("damage"), "Editable rank cap bounds eligibility")
	check(limited.catalog.describe_change("damage",1) == "MAX RANK", "Editable rank cap bounds card preview")
	cat.base_health = 200.0
	cat.bow.damage = 99.0
	upgrade(cat, "ice_bow").element_skill.chill_duration = 19.0
	first.apply_ranks(first.ranks)
	near(first.max_hp, 175.0, "Editing source character cannot change an active run")
	near(first.arrow_damage, 31.0, "Editing source bow cannot change an active run")
	near(first.element_skill.chill_duration, 6.0, "Editing source rank array cannot change an active run")
	var next_run := cat.create_stats()
	next_run.apply_ranks({"element_type":"ice", "enchant_rank":1, "element_skill_rank":1})
	near(next_run.max_hp, 200.0, "New run picks up edited character")
	near(next_run.arrow_damage, 99.0, "New run picks up edited weapon")
	near(next_run.element_skill.chill_duration, 19.0, "New run picks up edited upgrade array")

func check_invalid_configuration() -> void:
	var cat := custom_character()
	cat.base_health = -10.0
	cat.base_move_speed = NAN
	cat.dash_speed = -2.0
	cat.bow.damage = INF
	cat.bow.rate = -1.0
	cat.bow.fragment_projectile_limit = -9
	upgrade(cat, "ice_bow").element_skill.chill_fraction = 5.0
	upgrade(cat, "ice_bow").element_skill.frost_threshold = 0
	upgrade(cat, "ice_bow").element_skill.freeze_by_rank = PackedFloat32Array([0, NAN, -1, INF])
	cat.combat.base_crit_chance = 4.0
	upgrade(cat, "damage").values = PackedFloat32Array([0, NAN, -4, INF])
	upgrade(cat, "pierce").retention_by_rank = PackedFloat32Array([0, NAN, -1, 5])
	upgrade(cat, "split").fragment_angles_degrees = PackedFloat32Array([NAN, INF, 30])
	var stats := cat.create_stats()
	stats.apply_ranks({"damage":3,"pierce":3,"split":3,"element_type":"ice","enchant_rank":1,"element_skill_rank":3})
	near(stats.max_hp, 1.0, "Invalid negative health is made safe in snapshot")
	near(stats.move_speed, CharacterDefinition.new().base_move_speed, "Nonfinite character field uses declared default")
	near(stats.dash_speed, 0.0, "Negative dash speed is clamped")
	near(stats.arrow_damage, BowDefinition.new().damage, "Nonfinite weapon field uses declared default")
	near(stats.arrow_rate, 0.0, "Negative fire rate is disabled")
	check(stats.fragment_projectile_limit == 0, "Negative budget is disabled")
	near(stats.element_skill.chill_fraction, 1.0, "Ice chill fraction is bounded in snapshot")
	check(stats.element_skill.frost_threshold == 1, "Ice freeze threshold is positive in snapshot")
	near(stats.element_skill.freeze_by_rank[3], 0.0, "Nonfinite freeze duration is neutral")
	near(stats.crit_chance, 1.0, "Crit chance is safely bounded")
	near(stats.damage_percent, 0.0, "Nonfinite rank value is neutral")
	near(stats.pierce_retention, 1.0, "Retention is bounded")
	check(stats.split_angles.size() == 1, "Nonfinite fragment directions are omitted")
	check(cat.base_health == -10.0 and is_nan(cat.base_move_speed), "Validation never edits source character")
	check(is_inf(cat.bow.damage) and is_inf(upgrade(cat,"damage").values[3]), "Validation never edits nested source definitions")
	var status := StatusEffects.new()
	status.apply_ice(stats.element_skill, 3)
	status.tick(100.0)
	check(not status.is_frozen() and status.chill_remaining == 0, "Sanitized control values cannot create permanent status")
	check(is_inf(upgrade(cat, "ice_bow").element_skill.freeze_by_rank[3]), "Validation leaves nested element skill source untouched")

func buttons(node: Node) -> Array[Button]:
	var result: Array[Button] = []
	if node is Button: result.append(node)
	for child: Node in node.get_children():
		result.append_array(buttons(child))
	return result

func check_real_card_text() -> void:
	var cat := custom_character()
	upgrade(cat,"ice_bow").element_skill.chill_duration = 11.0
	upgrade(cat,"fire_bow").element_skill.radius_by_rank = PackedFloat32Array([0, 123, 123, 123])
	upgrade(cat,"dark_bow").element_skill.shared_cooldown = 7.0
	upgrade(cat,"lightning_bow").element_skill.targets_by_rank = PackedInt32Array([0, 5, 5, 5])
	upgrade(cat,"burst").spacing_by_rank = PackedFloat32Array([0.37, 0.37, 0.37, 0.37])
	upgrade(cat,"pierce").retention_by_rank = PackedFloat32Array([1, 0.42, 0.6, 0.8])
	upgrade(cat,"split").fragment_angles_degrees = PackedFloat32Array([-45, 0, 45])
	upgrade(cat,"spread_arrow").side_arrow_damage = 0.33
	upgrade(cat,"shield").crit_per_shield = 0.22
	for element: String in ["fire", "lightning", "ice", "dark"]:
		upgrade(cat, element + "_enchant").values = PackedFloat32Array([0, 17, 24, 31])
	var expected := {"ice_bow":"11s", "fire_bow":"Radius 123", "dark_bow":"cooldown 7s", "lightning_bow":"5 additional targets", "burst":"0.37s spacing", "pierce":"42% retained", "split":"3 fragments", "spread_arrow":"33% damage", "shield":"22% crit", "fire_enchant":"+17 fire", "lightning_enchant":"+17 lightning", "ice_enchant":"+17 ice", "dark_enchant":"+17 dark"}
	var game: Node = load("res://scenes/main.tscn").instantiate()
	game.character_definition = cat
	root.add_child(game)
	game.start_run(false)
	game.arena.process_mode = Node.PROCESS_MODE_DISABLED
	game.arena.bow.enabled = false
	for key: String in expected:
		var item: UpgradeDefinition = game.catalog.definition(key)
		var ranks: Dictionary = {"element_type":"ice", "enchant_rank":3, "element_skill_rank":3}
		for definition: UpgradeDefinition in cat.upgrades:
			if definition.element_id.is_empty(): ranks[definition.upgrade_id] = 3
		if item.is_enchantment:
			ranks.erase("element_type")
			ranks.erase("enchant_rank")
			ranks.erase("element_skill_rank")
		elif not item.element_id.is_empty():
			ranks.element_type = item.element_id
			ranks.element_skill_rank = 0
		else:
			ranks[key] = 0
		game.arena.apply_ranks(ranks)
		game.arena.stats.hp = game.arena.stats.max_hp
		game.arena.stats.shields = game.arena.stats.shield_capacity
		var selected: Button = null
		# Other enchantments remain intentionally switchable, even on a maxed build.
		for attempt in range(32):
			seed(4200 + attempt)
			game.show_upgrades()
			var cards := buttons(game.overlay)
			check(cards.size() == 3, "Custom " + key + " keeps the supported three-card layout")
			for card: Button in cards:
				if card.text.begins_with(item.display_name + " "): selected = card
			if selected != null: break
			game.resume_run()
		check(selected != null, "Edited " + key + " appears in actual eligible cards")
		if selected != null:
			check(str(expected[key]) in selected.text, "Actual card displays edited " + key + " parameter")
			check(game.catalog.describe_choice(key, game.arena.ranks) in selected.text, "Actual " + key + " card and runtime catalog use identical preview")
			selected.pressed.emit()
			check(game.catalog.rank_for(game.arena.stats.ranks, key) == 1, "Actual " + key + " card callback updates canonical run stats")
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
