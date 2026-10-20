extends SceneTree
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	var cat: CharacterDefinition = load("res://resources/cat.tres") as CharacterDefinition
	check(cat != null and cat.id == "cat", "character resource loads")
	var character_stats: CombatStats = cat.create_stats()
	check(character_stats.arrow_damage == cat.bow.damage and character_stats.hp == cat.base_health, "character and bow data populate stats")
	var stats := CombatStats.new()
	var catalog := UpgradeCatalog.new()
	check(catalog.definitions.size() >= 17, "catalog has all upgrades")
	check(not catalog.eligible({}).has("poison_crit"), "combo prerequisite enforced")
	check(catalog.eligible({"poison": 1}).has("poison_crit"), "poison combo unlocks")
	check(not catalog.eligible({"damage": 3}).has("damage"), "max rank excluded")
	check(not catalog.eligible({"poison": 1, "poison_crit": 3}).has("poison_crit"), "maximum rank toxic precision is excluded when owned")
	check(catalog.describe_change("spread_arrow", 0) == "1 arrows per burst -> 3 arrows per burst", "spread preview shows total arrows")
	check(catalog.describe_change("pierce", 1) == "2 hits / 75% retained -> 3 hits / 85% retained", "pierce preview shows count and retention")
	check(catalog.describe_change("poison_crit", 3) == "MAX RANK", "maximum rank preview caps correctly")
	for upgrade_key: String in catalog.definitions:
		check(not catalog.describe_change(upgrade_key, 0).is_empty(), "numeric preview exists for " + upgrade_key)
	stats.apply_ranks({"damage": 3, "vitality": 2, "shield": 2, "poison": 1, "poison_crit": 3, "bleed": 1, "bleed_regen": 2})
	check(stats.max_hp == 140.0 and stats.hp == 100.0, "recompute preserves current hp")
	check(stats.shield_capacity == 2 and stats.shields == 0, "shield capacity does not refill implicitly")
	var status := StatusEffects.new()
	var first: Dictionary = CombatRules.resolve_direct(stats, status, 10.0, 0.2)
	check(not first.crit and not first.pre_poison and not first.pre_bleed, "first hit cannot use status applied by itself")
	check(is_equal_approx(first.damage, 16.0), "damage rank scales damage")
	check(not status.has_poison(), "resolver is pure")
	status.apply_arrow(stats)
	var second: Dictionary = CombatRules.resolve_direct(stats, status, 10.0, 0.2, 0.5)
	check(second.crit and second.pre_poison and second.pre_bleed, "prehit statuses activate combos")
	check(is_equal_approx(second.damage, 16.0), "critical and retention compose")
	check(second.sustain == 1.0, "bleed sustain direct only")
	var poison := StatusEffects.new()
	poison.apply_poison(10.0, 2.0)
	check(poison.tick(0.25) == 0.0, "no premature DOT")
	poison.apply_poison(10.0, 2.0)
	check(poison.tick(0.25) == 5.0, "refresh preserves tick clock")
	check(poison.tick(2.0) == 15.0, "DOT clips to remaining lifetime")
	check(not poison.has_poison(), "DOT expires")
	stats.apply_ranks({"poison_crit": 3, "spread_arrow": 0})
	check(CombatRules.resolve_direct(stats, status, 10.0, 0.999).crit, "poison crit rank three guarantees crit")
	check(stats.spread_arrow_count == 1, "base bow fires one arrow")
	stats.apply_ranks({"shield": 2, "spread_arrow": 3})
	check(stats.spread_arrow_count == 7, "spread adds symmetric side arrows")
	stats.shields = 2
	check(CombatRules.resolve_direct(stats, StatusEffects.new(), 10.0, 0.24).crit, "each shield automatically adds 10 percent crit")
	check(not CombatRules.resolve_direct(stats, StatusEffects.new(), 10.0, 0.26).crit, "shield crit uses current shield count")
	var health := HealthState.new(stats)
	stats.shields = 2
	var blocked: Dictionary = health.receive_hit(999.0)
	check(blocked.shielded and stats.hp == 100.0 and stats.shields == 1, "shield absorbs entire hit")
	check(not health.receive_hit(999.0).accepted and stats.shields == 1, "same frame second hit rejected")
	health.tick(0.49)
	check(not health.receive_hit(999.0).accepted, "iframe lasts half a second")
	health.tick(0.02)
	check(health.receive_hit(999.0).shielded and stats.shields == 0, "next shield consumes after iframe")
	health.tick(0.5)
	check(health.receive_hit(20.0).damage == 20.0 and stats.hp == 80.0, "unshielded damage")
	stats.apply_ranks({"regen": 2})
	health.tick(1.0)
	check(stats.hp == 81.0, "regeneration ticks")
	health.receive_hit(500.0)
	health.tick(2.0)
	check(stats.hp == 0.0, "regen cannot resurrect")
	print("MODEL TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)
