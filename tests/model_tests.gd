extends SceneTree
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	var cat: CharacterDefinition = load("res://resources/cat.tres") as CharacterDefinition
	check(cat != null and cat.id == "cat", "character resource loads")
	var character_stats: CombatStats = cat.create_stats()
	character_stats.catalog.all_unlocked = true # Full-catalog combat fixture.
	check(character_stats.arrow_damage == cat.bow.damage and character_stats.hp == cat.base_health, "character and bow data populate stats")
	var stats := CombatStats.new()
	stats.catalog.all_unlocked = true # Full-catalog combat fixture.
	var catalog := UpgradeCatalog.new()
	catalog.all_unlocked = true # Full-catalog combat fixture; progression is tested separately.
	check(catalog.definitions.size() >= 17, "catalog has all upgrades")
	check(not catalog.eligible({}).has("fire_bow"), "combo prerequisite enforced")
	check(catalog.eligible({"fire_enchant": 1}).has("fire_bow"), "element skill unlocks")
	check(not catalog.eligible({"damage": 3}).has("damage"), "max rank excluded")
	check(not catalog.eligible({"fire_enchant": 1, "fire_bow": 3}).has("fire_bow"), "maximum rank toxic precision is excluded when owned")
	check(catalog.describe_change("spread_arrow", 0) == "3 arrows per burst / side arrows: 55% damage", "spread preview shows total arrows")
	check(catalog.describe_change("pierce", 1) == "3 hits / 85% retained", "pierce preview shows count and retention")
	check(catalog.describe_change("fire_bow", 3) == "MAX RANK", "maximum rank preview caps correctly")
	for upgrade_key: String in catalog.definitions:
		check(not catalog.describe_change(upgrade_key, 0).is_empty(), "numeric preview exists for " + upgrade_key)
	stats.apply_ranks({"damage":3, "vitality":2, "shield":2})
	check(stats.max_hp == 140.0 and stats.hp == 100.0, "Recompute preserves current HP")
	check(stats.shield_capacity == 2 and stats.shields == 0, "Shield does not refill implicitly")
	var status := StatusEffects.new()
	var first := CombatRules.resolve_direct(stats, status, 10, 0.2)
	check(not first.crit and is_equal_approx(first.damage, 16), "Pure base damage scales by global percent")
	check(status.frost_stacks == 0, "Resolver never applies status")
	stats.combat_definition.total_crit_chance_cap = 1.0 # Isolate critical damage formula, not production chance.
	stats.crit_chance = 1.0
	var second := CombatRules.resolve_direct(stats, status, 10, 0.2, 0.5)
	check(second.crit and is_equal_approx(second.damage,16), "Critical and retention compose")
	stats.apply_ranks({})
	check(stats.spread_arrow_count == 1, "Base bow fires one arrow")
	stats.apply_ranks({"shield": 2, "spread_arrow": 3})
	check(stats.spread_arrow_count == 7, "spread adds symmetric side arrows")
	stats.shields = 2
	check(CombatRules.resolve_direct(stats, StatusEffects.new(), 10.0, 0.109).crit, "each current shield adds 3 percentage points crit")
	check(not CombatRules.resolve_direct(stats, StatusEffects.new(), 10.0, 0.111).crit, "shield crit uses current shield count")
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
	await preload("res://tests/audio_teardown.gd").drain(self)
	quit(0 if failures == 0 else 1)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)
