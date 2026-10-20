extends SceneTree
## Independent rank/config/UI contracts; collision matrix lives in damage_combinations_tests.
var failures: int = 0
var checks: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, context: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(context)
func near(actual: float, expected: float, context: String) -> void:
	check(absf(actual - expected) < 0.0001, "%s: %.8f expected %.8f" % [context, actual, expected])
func run() -> void:
	var cat := load("res://resources/cat.tres") as CharacterDefinition
	var stats := cat.create_stats()
	var catalog := stats.catalog
	for flat in range(4):
		for percent in range(4):
			stats.apply_ranks({"damage_flat": flat, "damage": percent})
			near(stats.damage_flat, flat * 5.0, "flat rank %d" % flat)
			near(stats.damage_percent, percent * 20.0, "percent rank %d" % percent)
			near(CombatRules.resolve_direct(stats, StatusEffects.new(), 15.0, 1.0).damage, (15.0 + flat * 5.0) * (1.0 + percent * 0.2), "flat before percent, ranks %d/%d" % [flat, percent])
			check(catalog.eligible(stats.ranks).has("damage_flat") == (flat < 3), "flat cap independently enforced")
			check(catalog.eligible(stats.ranks).has("damage") == (percent < 3), "percent cap independently enforced")
	for rank in range(1, 4):
		var coefficient: float = [1.0, 0.60, 0.45, 0.38][rank]
		var ranks := {"damage_flat": 1, "damage": 1, "burst": rank}
		for repeat in range(4):
			stats.apply_ranks(ranks)
			near(CombatRules.resolve_direct(stats, StatusEffects.new(), 15.0, 1.0).damage, 24.0 * coefficient, "repeated apply keeps one final burst multiplier")
		check("%d%% damage" % roundi(coefficient * 100.0) in catalog.describe_rank("burst", rank), "rank benefit and cost uses resource")
		stats.apply_ranks({})
		near(CombatRules.resolve_direct(stats, StatusEffects.new(), 15.0, 1.0).damage, 15.0, "reset restores unchanged baseline")
	check(UpgradeDefinition.number(14.4) == "14.4", "fractional damage remains visible")
	var custom := cat.duplicate(true) as CharacterDefinition
	custom.upgrades = []
	for original: UpgradeDefinition in UpgradeCatalog.UPGRADES:
		var item := original.duplicate(true) as UpgradeDefinition
		if item.upgrade_id == "damage_flat": item.values = PackedFloat32Array([0, 7, 14, 21])
		if item.upgrade_id == "damage": item.values = PackedFloat32Array([0, 25, 50, 75])
		if item.upgrade_id == "burst":
			item.damage_multiplier_by_rank = PackedFloat32Array([1, 0.70, 0.50, 0.40])
			item.spacing_by_rank = PackedFloat32Array([0.12, 0.15, 0.16, 0.17])
		custom.upgrades.append(item)
	var configured := custom.create_stats()
	for rank in range(1, 4):
		configured.apply_ranks({"damage_flat": rank, "damage": rank, "burst": rank})
		var coefficient: float = [1.0, 0.70, 0.50, 0.40][rank]
		near(CombatRules.resolve_direct(configured, StatusEffects.new(), 15.0, 1.0).damage, (15.0 + 7.0 * rank) * (1.0 + 0.25 * rank) * coefficient, "edited config changes runtime")
		check("+%d flat" % (7 * rank) in configured.catalog.describe_rank("damage_flat", rank), "edited flat config changes selected description")
		check("+%d%%" % (25 * rank) in configured.catalog.describe_rank("damage", rank), "edited percent config changes selected description")
		check("%d%% damage" % roundi(coefficient * 100.0) in configured.catalog.describe_rank("burst", rank), "edited burst config changes selected cost")
		check(" -> " not in configured.catalog.describe_change("burst", rank - 1), "no old-to-new preview")
	near(cat.create_stats().catalog.value("damage_flat", 1), 5.0, "custom run cannot mutate original")
	var panel := PracticePanel.new()
	root.add_child(panel)
	panel.setup(configured.catalog)
	for rank in range(4):
		panel.set_ranks({"damage_flat": rank, "burst": rank})
		var flat_control: SpinBox = panel._rank_controls["damage_flat"]
		var burst_control: SpinBox = panel._rank_controls["burst"]
		check(flat_control.value == rank and flat_control.max_value == 3, "practice rank sync and max3")
		check(configured.catalog.describe_rank("damage_flat", rank) in flat_control.tooltip_text, "practice tooltip follows selected/reset rank")
		check(configured.catalog.describe_rank("burst", rank) in burst_control.tooltip_text, "practice cost tooltip follows selected/reset rank")
	var control: SpinBox = panel._rank_controls["burst"]
	control.value = 1
	check("70% damage" in control.tooltip_text, "manual practice spin updates cost")
	panel.free()
	print("DAMAGE UPGRADE CONTRACTS: %d checks, %d failures; ranks, config, reset, practice tooltips" % [checks, failures])
	quit(0 if failures == 0 else 1)
