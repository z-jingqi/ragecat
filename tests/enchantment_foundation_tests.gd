extends SceneTree
var checks: int = 0
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
func near(actual: float, expected: float, label: String) -> void:
	check(absf(actual - expected) < 0.001, "%s actual=%s expected=%s" % [label, actual, expected])
func run() -> void:
	var catalog := UpgradeCatalog.new()
	catalog.all_unlocked = true # Full-catalog combat fixture; progression is tested separately.
	check(catalog.definitions.size() == 24, "16 general + four enchants + four bow skills")
	check(catalog.eligible({}).size() == 20, "plain enchant cards eligible, skill cards gated")
	var ranks := catalog.apply_choice({}, "fire_enchant")
	check(ranks.enchant_rank == 1 and ranks.element_type == "fire" and ranks.element_skill_rank == 0, "first enchant grants only damage")
	ranks = catalog.apply_choice(ranks, "fire_bow")
	ranks = catalog.apply_choice(ranks, "fire_enchant")
	ranks = catalog.apply_choice(ranks, "fire_enchant")
	for element: String in ["lightning", "ice", "dark", "fire"]:
		ranks = catalog.apply_choice(ranks, element + "_enchant")
		check(ranks.enchant_rank == 3 and ranks.element_skill_rank == 1, "switch preserves investments without free rank")
		check(not catalog.eligible(ranks).has(element + "_enchant"), "current max enchant excluded")
		for other: String in ["fire", "lightning", "ice", "dark"]:
			if other != element: check(catalog.eligible(ranks).has(other + "_enchant"), "other max-rank switches retained")
	var arena := RageArena.new()
	arena.practice = true
	root.add_child(arena)
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	for element: String in ["fire", "lightning", "ice", "dark"]:
		arena.apply_ranks({element + "_enchant": 1, "damage_flat": 1, "damage": 1, "burst": 1})
		arena.stats.crit_chance = 0
		near(arena.stats.base_damage, 24, "base damage B")
		near(arena.stats.element_damage, 6, "element damage E")
		var packet := CombatRules.resolve_direct(arena.stats, StatusEffects.new(), 15, 1, 0.55 * 0.6)
		near(packet.base_precrit, 24 * 0.6 * 0.55 * 0.6, "base projectile coefficients once")
		near(packet.elemental_precrit, 6 * 0.6 * 0.55 * 0.6, "element projectile coefficients once")
		check(arena.stats.element_skill == null, "no implicit skill")
		var victim := arena.spawn_enemy("dummy", Vector2(650, 400))
		var arrow := CatArrow.new()
		arrow.impact_position = victim.position
		var before := victim.health
		arena._on_arrow_hit(arrow, victim)
		near(before - victim.health, 18, "one combined direct hit")
		check(not victim.status.is_frozen() and victim.status.frost_stacks == 0, "base enchant no special state")
		check(arena.element_procs.get_child_count() == 0, "base enchant creates no effects")
		arrow.free()
	arena.apply_ranks({"dark_enchant": 2, "dark_bow": 2})
	arena.bow.gravity_gap_remaining = 1.75
	arena.bow.attack_clock = 0.3
	arena.bow.burst_remaining = 2
	arena.arrows.add_child(CatArrow.new())
	arena.select_upgrade("fire_enchant")
	near(arena.bow.gravity_gap_remaining, 1.75, "switch preserves shared cooldown")
	near(arena.bow.attack_clock, 0.3, "switch preserves attack cadence")
	check(arena.bow.burst_remaining == 0 and arena.arrows.get_child_count() == 0, "switch clears in-flight attacks")
	check(arena.stats.element_skill_rank == 2 and arena.ranks.enchant_rank == 2, "skill mapped not lost")
	var panel := PracticePanel.new()
	root.add_child(panel)
	panel.setup(catalog)
	var fire: SpinBox = panel._rank_controls.fire_enchant
	fire.value = 1
	check(panel._ranks.enchant_rank == 1, "practice first enchant enters rank one")
	fire.value = 3
	var dark: SpinBox = panel._rank_controls.dark_enchant
	dark.value = 1
	check(panel._ranks.enchant_rank == 3 and panel._ranks.element_type == "dark", "practice switch inherits level")
	check(panel._ranks.element_skill_rank == 0, "practice skill zero remains plain")
	panel.free()
	arena.free()
	print("ENCHANTMENT FOUNDATION: %d checks, %d failures" % [checks, failures])
	await preload("res://tests/audio_teardown.gd").drain(self)
	quit(0 if failures == 0 else 1)
