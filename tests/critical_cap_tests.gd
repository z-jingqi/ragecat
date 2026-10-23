extends SceneTree
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)

func near(actual: float, expected: float, label: String) -> void:
	check(is_equal_approx(actual, expected), label + " got " + str(actual))

func _initialize() -> void:
	var stats := (load("res://resources/characters/archer.tres") as CharacterDefinition).create_stats()
	stats.catalog.all_unlocked = true
	stats.apply_ranks({"crit_chance": 3, "shield": 3})
	near(stats.shield_crit_per_charge, 0.03, "production shield increment")
	near(stats.combat_definition.total_crit_chance_cap, 0.6, "production total cap")
	near(stats.combat_definition.shield_crit_bonus_cap, 0.09, "production shield cap")
	for charges in range(4):
		stats.shields = charges
		near(stats.effective_shield_crit_bonus(), charges * 0.03, "current shields only")
		near(stats.effective_crit_chance(), 0.29 + charges * 0.03, "ordinary max upgrade build")
	stats.shields = 100
	near(stats.effective_shield_crit_bonus(), 0.09, "future extra shields cannot bypass bonus cap")
	stats.crit_chance = 0.59
	near(stats.effective_crit_chance(), 0.6, "all sources share total cap")
	stats.crit_chance = 10.0
	near(stats.effective_crit_chance(), 0.6, "high base alone obeys total cap")
	stats.shields = 0
	near(stats.effective_shield_crit_bonus(), 0.0, "empty shield zero bonus regardless of capacity")
	stats.shields = -20
	near(stats.effective_shield_crit_bonus(), 0.0, "negative shields are harmless")
	stats.shields = 3
	stats.combat_definition.shield_crit_bonus_cap = 0.02
	near(stats.effective_shield_crit_bonus(), 0.02, "independent editable bonus ceiling")
	stats.combat_definition.shield_crit_bonus_cap = 0.09
	stats.shields = 0
	for chance in [0.0, 0.6, 1.0]:
		stats.combat_definition.total_crit_chance_cap = chance
		stats.crit_chance = 1.0
		var at := CombatRules.resolve_direct(stats, null, 10.0, chance)
		check(not at.crit, "strict roll boundary at " + str(chance))
		check(not CombatRules.resolve_direct(stats, null, 10.0, 1.0).crit, "one roll never crits")
		if chance > 0.0:
			check(CombatRules.resolve_direct(stats, null, 10.0, chance - 0.00001).crit, "below boundary crits")
		else:
			check(not CombatRules.resolve_direct(stats, null, 10.0, 0.0).crit, "zero chance rejects zero roll")
	stats.combat_definition.total_crit_chance_cap = 0.6
	stats.element_damage = 7.0
	var primary := CombatRules.resolve_direct(stats, null, 10.0, 0.0)
	near(primary.damage, (primary.base_precrit + primary.elemental_precrit) * stats.crit_multiplier, "one roll multiplies entire B+E packet")
	var secondary := CombatRules.resolve_direct(stats, null, 10.0, 0.0, 1.0, true)
	check(not secondary.crit, "secondary fragments never crit")
	near(secondary.damage, secondary.base_precrit + secondary.elemental_precrit, "secondary damage unchanged")
	for invalid in [NAN, INF, -INF]:
		var rules := CombatDefinition.new()
		rules.total_crit_chance_cap = invalid
		rules.shield_crit_bonus_cap = invalid
		var validated := rules.validated_copy()
		near(validated.total_crit_chance_cap, 0.6, "nonfinite total uses safe default")
		near(validated.shield_crit_bonus_cap, 0.09, "nonfinite shield uses safe default")
		stats.combat_definition = rules
		stats.crit_chance = invalid
		stats.shield_crit_per_charge = invalid
		stats.shields = 3
		near(stats.effective_crit_chance(), 0.0, "invalid live contributions cannot yield invalid probability")
	for value in [-1.0, 2.0]:
		var rules := CombatDefinition.new()
		rules.total_crit_chance_cap = value
		rules.shield_crit_bonus_cap = value
		var validated := rules.validated_copy()
		near(validated.total_crit_chance_cap, clampf(value, 0.0, 1.0), "total cap clamped")
		near(validated.shield_crit_bonus_cap, clampf(value, 0.0, 1.0), "shield cap clamped")
	var display_rules := CombatDefinition.new()
	display_rules.shield_crit_bonus_cap = 0.07
	display_rules.total_crit_chance_cap = 0.42
	var display_catalog := UpgradeCatalog.new([], display_rules)
	for locale in ["en", "zh_CN"]:
		TranslationServer.set_locale(locale)
		var description := display_catalog.definition("shield").description
		check("7" in description and "42" in description and "{" not in description, "configured caps in template " + locale)
		var rank_text := display_catalog.describe_rank("shield", 3)
		check("7" in rank_text and "42" in rank_text, "configured caps in rank text " + locale)
	print("Critical cap tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
