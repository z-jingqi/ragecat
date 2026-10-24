extends SceneTree
## Metadata-based composition and dependency eligibility. No game saves are used.
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)

func card(id: String, prerequisite: String = "") -> UpgradeDefinition:
	var result := UpgradeDefinition.new()
	result.upgrade_id = id
	result.prerequisite = prerequisite
	result.values = PackedFloat32Array([0, 1, 2, 3])
	return result

func catalog(items: Array[UpgradeDefinition]) -> UpgradeCatalog:
	var result := UpgradeCatalog.new(items)
	result.all_unlocked = true
	return result

func run() -> void:
	check_dependencies()
	check_elements()
	check_duplicates()
	check_default_compatibility()
	check_modifier_description()
	check_modifier_offer_signals()
	check_default_offer_equivalence()
	print("Catalog composition: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func check_dependencies() -> void:
	var c := catalog([card("root"), card("child", "root"), card("grandchild", "child"), card("missing", "unknown"), card("self", "self"), card("cycle_a", "cycle_b"), card("cycle_b", "cycle_a")])
	check(c.eligible({}) == ["root"], "Only root is eligible before prerequisites")
	check(c.eligible({"root":1}).has("child"), "Owned prerequisite enables child")
	check(not c.eligible({"root":1}).has("grandchild"), "Grandchild still needs child")
	check(c.eligible({"root":1, "child":1}).has("grandchild"), "Valid dependency chain enables grandchild")
	check(not c.eligible({"child":1}).has("grandchild"), "Malformed imports cannot bypass ancestor")
	check(c.apply_choice({}, "child").is_empty(), "Applying unavailable dependent card is rejected")
	check(c.apply_choice({"root":1}, "child").get("child",0) == 1, "Eligible dependent card can be acquired")
	var malformed := {"self":1, "cycle_a":1, "cycle_b":1, "missing":1, "unknown":1}
	for id in ["self", "cycle_a", "cycle_b", "missing"]:
		check(not c.eligible(malformed).has(id), "Invalid/cyclic dependency rejected: " + id)
	check(c.definition("child").prerequisite == "root", "Prerequisite resource remains authored")

func check_elements() -> void:
	var enchant := (load("res://resources/upgrades/fire_enchant.tres") as UpgradeDefinition).duplicate(true) as UpgradeDefinition
	enchant.upgrade_id = "ember_coating"
	var skill := (load("res://resources/upgrades/fire_bow.tres") as UpgradeDefinition).duplicate(true) as UpgradeDefinition
	skill.upgrade_id = "exploding_shot"
	skill.prerequisite = "ember_coating"
	var ice := (load("res://resources/upgrades/ice_enchant.tres") as UpgradeDefinition).duplicate(true) as UpgradeDefinition
	ice.upgrade_id = "winter_coating"
	var ice_skill := (load("res://resources/upgrades/ice_bow.tres") as UpgradeDefinition).duplicate(true) as UpgradeDefinition
	ice_skill.upgrade_id = "winter_shot"
	ice_skill.prerequisite = "winter_coating"
	var c := catalog([enchant, skill, ice, ice_skill])
	check(c.element_enchantment_id("fire") == "ember_coating", "Enchantment bound by metadata")
	check(c.element_skill_id("fire") == "exploding_shot", "Exclusive bound by metadata")
	check(c.element_enchantment_id("unknown").is_empty() and c.element_skill_id("unknown").is_empty(), "Unknown element has no fabricated ID")
	check(c.element_ids() == ["fire", "ice"], "Element registry follows authored order")
	check(not c.eligible({}).has("exploding_shot"), "Exclusive unavailable before enchantment")
	var ranks := c.apply_choice({}, "ember_coating")
	check(ranks == {"element_type":"fire", "enchant_rank":1, "element_skill_rank":0}, "Custom enchant creates shared runtime state")
	check(c.eligible(ranks).has("exploding_shot"), "Custom exclusive eligible after custom enchantment")
	ranks = c.apply_choice(ranks, "exploding_shot")
	check(c.rank_for(ranks, "exploding_shot") == 1, "Custom exclusive increases shared investment")
	check(c.normalize_ranks({"ember_coating":2, "exploding_shot":3}) == {"element_type":"fire", "enchant_rank":2, "element_skill_rank":3}, "Custom per-card fixture input normalizes")
	ranks = c.apply_choice(ranks, "winter_coating")
	check(ranks == {"element_type":"ice", "enchant_rank":1, "element_skill_rank":1}, "Switching custom IDs preserves investment")
	check(c.rank_for(ranks, "exploding_shot") == 0 and c.rank_for(ranks, "winter_shot") == 1, "Only active element receives shared rank")
	check(not c.eligible(ranks).has("exploding_shot"), "Inactive custom exclusive remains unavailable")
	check(c.describe_build_rank("winter_shot", 1, ranks) != "", "Metadata-bound skill description remains available")
	var enchant_only := catalog([enchant])
	check(enchant_only.normalize_ranks({"element_type":"fire", "enchant_rank":2, "element_skill_rank":3}).element_skill_rank == 0, "Missing exclusive safely clamps shared skill investment")
	check(enchant.upgrade_id == "ember_coating" and skill.prerequisite == "ember_coating", "Source metadata is unchanged")

func check_duplicates() -> void:
	var first := card("first")
	first.element_id = "fire"
	first.is_enchantment = true
	var duplicate := card("duplicate")
	duplicate.element_id = "fire"
	duplicate.is_enchantment = true
	var same_id := card("first")
	same_id.values = PackedFloat32Array([0, 99, 99, 99])
	var ability := card("ability")
	ability.element_id = "fire"
	var other_ability := card("other_ability")
	other_ability.element_id = "fire"
	var c := catalog([first, duplicate, same_id, ability, other_ability, card("")])
	check(c.element_enchantment_id("fire") == "first", "First authored enchantment wins duplicate role")
	check(c.element_skill_id("fire") == "ability", "First authored exclusive wins duplicate role")
	check(c.definition("duplicate") == null and c.definition("other_ability") == null, "Ambiguous element aliases cannot become selectable cards")
	check(c.value("first",1) == 1, "Duplicate upgrade ID cannot overwrite first definition")
	check(c.definition("") == null, "Empty IDs are excluded")

func check_default_compatibility() -> void:
	var c := UpgradeCatalog.new()
	c.all_unlocked = true
	for element in ["fire", "lightning", "ice", "dark"]:
		check(c.element_enchantment_id(element) == element + "_enchant", "Existing enchant ID unchanged: " + element)
		check(c.element_skill_id(element) == element + "_bow", "Existing exclusive ID unchanged: " + element)
		var old := {element + "_enchant":2, element + "_bow":3, "damage":2}
		var shared := {"element_type":element, "enchant_rank":2, "element_skill_rank":3, "damage":2}
		check(c.normalize_ranks(old) == shared, "Existing fixture format preserved: " + element)
		check(c.normalize_ranks(shared) == shared, "Existing shared format preserved: " + element)
		check(c.eligible(shared).has(element + "_enchant"), "Current enchant can still upgrade: " + element)
		check(not c.eligible(shared).has(element + "_bow"), "Maximum skill remains excluded: " + element)
	check(c.resources.size() == UpgradeCatalog.UPGRADES.size(), "No default catalog entries rejected")

func check_modifier_description() -> void:
	var upgrade := card("custom_training")
	var health := UpgradeStatModifier.new()
	health.channel = "health"
	var speed := UpgradeStatModifier.new()
	speed.channel = "move_ratio"
	speed.values = PackedFloat32Array([0, 0.1, 0.2, 0.3])
	upgrade.stat_modifiers = [health, speed]
	var c := catalog([upgrade])
	var configured := c.definition("custom_training")
	var expected: PackedStringArray = []
	for modifier in configured.stat_modifiers:
		expected.append(modifier.describe(2, configured.values))
	check(c.describe_rank("custom_training", 2) == "\n".join(expected), "New-ID composite card describes every configured modifier")
	check(c.describe_rank("custom_training", 2).split("\n").size() == 2, "Composite description retains both effects")

func legacy_signals(catalog, stats: CombatStats) -> Dictionary:
	var gravity := stats.gravity_mode()
	var character := stats.character if stats.character != null else CharacterDefinition.new()
	var crit_cap := maxf(0.0, stats.combat_definition.total_crit_chance_cap)
	var effective := stats.effective_crit_chance()
	var critical_rank: int = catalog.rank_for(stats.ranks, "crit_chance")
	var next_delta: float = maxf(0.0, catalog.value("crit_chance", critical_rank + 1) - catalog.value("crit_chance", critical_rank))
	var saturation := 1.0 - UpgradeOfferEngine._unit((crit_cap - effective) / next_delta) if next_delta > 0.0 else 1.0
	var f := {"flat":UpgradeOfferEngine._growth(catalog,stats,"damage_flat"), "percent":UpgradeOfferEngine._growth(catalog,stats,"damage"), "rate":UpgradeOfferEngine._growth(catalog,stats,"attack_speed"), "crit_damage":UpgradeOfferEngine._growth(catalog,stats,"crit_damage"), "regen":UpgradeOfferEngine._growth(catalog,stats,"regen"), "health_growth":UpgradeOfferEngine._growth(catalog,stats,"vitality"), "effective_crit":UpgradeOfferEngine._unit(effective / crit_cap) if crit_cap > 0 else 0.0, "crit_saturation":saturation, "gravity":1.0 if gravity else 0.0, "inactive_pierce":1.0 if gravity or stats.fire_mode() else 0.0, "health_deficit":UpgradeOfferEngine._unit(1.0 - stats.hp / stats.max_hp) if stats.max_hp > 0 else 0.0}
	# Use authoritative live additive stats, normalized by the authored upgrade scale.
	var stat_sources := {"flat":[stats.damage_flat,0.0,"damage_flat"], "percent":[stats.damage_percent,stats.combat_definition.base_damage_percent,"damage"], "rate":[stats.attack_speed,stats.combat_definition.base_attack_speed,"attack_speed"], "crit_damage":[stats.crit_multiplier,stats.combat_definition.base_crit_multiplier,"crit_damage"], "regen":[stats.regen,stats.combat_definition.base_regen,"regen"], "health_growth":[stats.max_hp,character.base_health,"vitality"]}
	for feature: String in stat_sources:
		var source: Array = stat_sources[feature]
		var scale: float = catalog.value(source[2],catalog.max_rank(source[2]))
		f[feature] = UpgradeOfferEngine._unit((float(source[0])-float(source[1]))/scale) if scale > 0 else 0.0
	var volley := maxf(UpgradeOfferEngine._growth(catalog,stats,"burst"), UpgradeOfferEngine._growth(catalog,stats,"spread_arrow"))
	f["volley"] = volley
	f["direct_volley"] = 0.0 if gravity else volley
	f["element"] = UpgradeOfferEngine._growth(catalog, stats, catalog.element_enchantment_id(stats.active_element))
	# In gravity mode these cards convert into DPS/radii, not extra arrows.
	f["pattern_damage"] = f.element if gravity else maxf(f.flat, f.percent)
	f["range_damage"] = f.element if gravity else maxf(f.flat, f.percent)
	f["control_fit"] = 1.0 if gravity else volley
	f["shield_crit_fit"] = f.crit_damage if stats.shield_crit_per_charge > 0 and stats.combat_definition.shield_crit_bonus_cap > 0 else 0.0
	f["move_shortfall"] = UpgradeOfferEngine._unit(1.0 - stats.move_speed / maxf(1.0, character.base_move_speed * (1.0 + catalog.value("move_speed",catalog.max_rank("move_speed")))))
	f["pickup_shortfall"] = UpgradeOfferEngine._unit(1.0 - stats.pickup_radius / maxf(1.0, character.base_pickup_radius + catalog.value("pickup_radius",catalog.max_rank("pickup_radius"))))
	f["range_shortfall"] = UpgradeOfferEngine._unit(1.0 - stats.arrow_range / maxf(1.0, character.bow.projectile_range * (1.0 + catalog.value("long_draw",catalog.max_rank("long_draw"))))) if character.bow != null else 0.0
	for element: String in catalog.element_ids():
		f["active_" + element] = 1.0 if stats.active_element == element else 0.0
	f["lightning"] = f.get("active_lightning", 0.0)
	f["fire_fit"] = maxf(UpgradeOfferEngine._growth(catalog,stats,"burst"),UpgradeOfferEngine._growth(catalog,stats,"spread_arrow"))
	f["lightning_fit"] = UpgradeOfferEngine._growth(catalog,stats,"pierce")
	f["ice_fit"] = f.effective_crit
	f["dark_fit"] = volley
	return f


func check_modifier_offer_signals() -> void:
	var composite := card("traveler_training")
	for channel: String in ["health", "damage_flat", "damage_percent", "attack_speed", "crit_multiplier", "regen", "move_ratio", "pickup_radius", "range_ratio", "crit_chance"]:
		var modifier := UpgradeStatModifier.new()
		modifier.channel = channel
		modifier.scale = 0.1 if channel in ["move_ratio", "attack_speed", "crit_chance"] else 1.0
		composite.stat_modifiers.append(modifier)
	var source := CharacterDefinition.new()
	source.upgrades = [composite]
	var stats := CombatStats.new(source)
	stats.apply_ranks({"traveler_training":1})
	var f := UpgradeOfferEngine.signals(stats.catalog, stats)
	for feature: String in ["flat", "percent", "rate", "crit_damage", "regen", "health_growth", "move_shortfall", "pickup_shortfall", "range_shortfall"]:
		check(float(f[feature]) > 0.0, "New-ID modifier feeds existing feature: " + feature)
	for feature: String in ["flat", "percent", "rate", "crit_damage", "regen", "health_growth"]:
		check(is_equal_approx(float(f[feature]), 1.0 / 3.0), "New-ID scale uses authored full contribution: " + feature)
	check(is_equal_approx(float(f.crit_saturation), 0.0), "New-ID crit increments do not falsely report saturation")
	stats.crit_chance = stats.combat_definition.total_crit_chance_cap
	check(UpgradeOfferEngine.signals(stats.catalog, stats).crit_saturation == 1.0, "Capped crit remains saturated with custom cards")
	var second := card("second_training")
	var boost := UpgradeStatModifier.new()
	boost.channel = "damage_flat"
	boost.scale = 2.0
	var cost := UpgradeStatModifier.new()
	cost.channel = "damage_flat"
	cost.scale = -1.0
	second.stat_modifiers = [boost, cost]
	var both := catalog([composite, second])
	check(is_equal_approx(float(UpgradeOfferEngine._modifier_scales(both).damage_flat), 9.0), "Positive capacities sum across cards; costs do not inflate scale")
	var stronger := card("focused_aim")
	var critical := UpgradeStatModifier.new()
	critical.channel = "crit_chance"
	critical.scale = 0.2
	stronger.stat_modifiers = [critical]
	source.upgrades = [composite, stronger]
	stats = CombatStats.new(source)
	stats.apply_ranks({"traveler_training":1})
	check(is_equal_approx(UpgradeOfferEngine._next_crit_delta(stats.catalog,stats), 0.2), "Crit saturation uses greatest available card increment")

func check_default_offer_equivalence() -> void:
	var stats := CombatStats.new(load("res://resources/characters/archer.tres") as CharacterDefinition)
	for rank in range(4):
		for element in ["", "fire", "lightning", "ice", "dark"]:
			var ranks := {}
			for item: UpgradeDefinition in UpgradeCatalog.UPGRADES:
				if item.element_id.is_empty(): ranks[item.upgrade_id] = rank
			if not element.is_empty():
				ranks.element_type = element
				ranks.enchant_rank = maxi(1, rank)
				ranks.element_skill_rank = rank
			stats.apply_ranks(ranks)
			stats.hp = stats.max_hp * 0.7
			stats.shields = mini(1, stats.shield_capacity)
			var expected := legacy_signals(stats.catalog, stats)
			var actual := UpgradeOfferEngine.signals(stats.catalog, stats)
			check(expected.size() == actual.size(), "Default signal set unchanged")
			for feature: String in expected:
				check(is_equal_approx(float(actual.get(feature, -1000)), float(expected[feature])), "Default signal equals previous formula: %s rank%d %s" % [element, rank, feature])
