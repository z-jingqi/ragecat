extends SceneTree
## Ordinary displacement and gravity conversion are independently configurable.
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func near(actual: float, expected: float, label: String) -> void:
	check(is_equal_approx(actual, expected), label)
func run() -> void:
	var character := load("res://resources/characters/archer.tres") as CharacterDefinition
	if character == null:
		quit(1)
		return
	var stats := character.create_stats()
	near(stats.knockback, 0, "authored opening has no knockback")
	near(BowDefinition.new().knockback, 0, "fallback bow starts with no knockback")
	for rank in range(4):
		stats.apply_ranks({"knockback":rank})
		near(stats.knockback, rank * 15, "fixed ordinary upgrade rank %d" % rank)
		near(stats.knockback_bonus, 0, "default card contains no hidden ordinary ratio")
		stats.apply_ranks({"element_type":"dark", "enchant_rank":1, "element_skill_rank":1, "knockback":rank})
		var g := stats.element_skill.gravity
		near(stats.gravity_acceleration, g.parameter(g.acceleration_by_rank,1) * clampf(1 + rank * 0.25 * g.pull_upgrade_scale,0,g.pull_multiplier_cap), "gravity conversion remains unchanged")
	var custom := CharacterDefinition.new()
	custom.bow.knockback = 80
	for item: UpgradeDefinition in UpgradeCatalog.UPGRADES: custom.upgrades.append(item)
	var ratio := UpgradeStatModifier.new()
	ratio.channel = "knockback_ratio"
	ratio.values = PackedFloat32Array([0,0.5,-0.5,-2])
	var card := UpgradeDefinition.new()
	card.upgrade_id = "custom_ratio"
	card.stat_modifiers.append(ratio)
	custom.upgrades.append(card)
	var other := custom.create_stats()
	for rank in range(4):
		other.apply_ranks({"knockback":rank})
		near(other.knockback,80 + rank*15,"nonzero base receives only flat default bonus")
	for rank in range(1,4):
		other.apply_ranks({"custom_ratio":rank,"knockback":1})
		near(other.knockback,80 * maxf(0,1+ratio.values[rank])+15,"custom ratio affects base only")
	other.apply_ranks({"element_type":"dark", "enchant_rank":1, "element_skill_rank":1, "knockback":2, "custom_ratio":2})
	var gravity := other.element_skill.gravity
	near(other.gravity_acceleration,gravity.parameter(gravity.acceleration_by_rank,1),"legacy negative ratio composes with independent positive gravity channel")
	var flat_only := UpgradeStatModifier.new()
	flat_only.channel = "knockback_flat"
	flat_only.values = PackedFloat32Array([0,100])
	var flat_card := UpgradeDefinition.new()
	flat_card.upgrade_id = "flat_only"
	flat_card.stat_modifiers.append(flat_only)
	custom.upgrades.append(flat_card)
	var flat_stats := custom.create_stats()
	flat_stats.apply_ranks({"element_type":"dark", "enchant_rank":1, "element_skill_rank":1, "flat_only":1})
	near(flat_stats.gravity_acceleration,gravity.parameter(gravity.acceleration_by_rank,1),"ordinary flat channel never silently changes gravity")
	near(custom.bow.knockback,80,"custom authored weapon unchanged")
	near(character.bow.knockback,0,"default resource remains unchanged")
	TranslationServer.set_locale("en")
	check(stats.catalog.describe_rank("knockback",1).contains("+15 knockback"),"flat preview is not a percentage")
	check(stats.catalog.describe_build_rank("knockback",1,stats.ranks).contains("25%"),"gravity preview shows preserved bonus")
	TranslationServer.set_locale("zh_CN")
	check(stats.catalog.describe_rank("knockback",1).contains("+15 击退"),"Chinese preview uses fixed distance")
	check(not stats.catalog.describe_build_rank("knockback",1,stats.ranks).contains("+15"),"dark preview excludes inactive outward impulse")
	print("KNOCKBACK PROGRESSION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
