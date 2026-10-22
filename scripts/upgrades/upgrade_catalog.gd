class_name UpgradeCatalog
extends RefCounted
## Compatibility dictionaries are derived from independently authored upgrade resources.
const UPGRADES := [
	preload("res://resources/upgrades/fire_enchant.tres"),
	preload("res://resources/upgrades/fire_bow.tres"),
	preload("res://resources/upgrades/lightning_enchant.tres"),
	preload("res://resources/upgrades/lightning_bow.tres"),
	preload("res://resources/upgrades/ice_enchant.tres"),
	preload("res://resources/upgrades/ice_bow.tres"),
	preload("res://resources/upgrades/dark_enchant.tres"),
	preload("res://resources/upgrades/dark_bow.tres"),

	preload("res://resources/upgrades/split.tres"),
	preload("res://resources/upgrades/knockback.tres"),
	preload("res://resources/upgrades/long_draw.tres"),
	preload("res://resources/upgrades/vitality.tres"),
	preload("res://resources/upgrades/damage.tres"),
	preload("res://resources/upgrades/damage_flat.tres"),
	preload("res://resources/upgrades/attack_speed.tres"),
	preload("res://resources/upgrades/crit_chance.tres"),
	preload("res://resources/upgrades/crit_damage.tres"),
	preload("res://resources/upgrades/move_speed.tres"),
	preload("res://resources/upgrades/pickup_radius.tres"),
	preload("res://resources/upgrades/regen.tres"),
	preload("res://resources/upgrades/shield.tres"),
	preload("res://resources/upgrades/pierce.tres"),
	preload("res://resources/upgrades/burst.tres"),
	preload("res://resources/upgrades/spread_arrow.tres"),
]
var _definitions: Dictionary = {}
var _text_locale := ""
var definitions: Dictionary:
	get:
		refresh_translations()
		return _definitions
var resources: Dictionary = {}

func _init(configured_upgrades: Array[UpgradeDefinition] = []) -> void:
	var source: Array = UPGRADES if configured_upgrades.is_empty() else configured_upgrades
	for original: UpgradeDefinition in source:
		if original == null: continue
		var upgrade := original.validated_copy()
		resources[upgrade.upgrade_id] = upgrade
		# Copies prevent consumers of the legacy view from modifying source data.
		_definitions[upgrade.upgrade_id] = {"name":upgrade.display_name,"description":upgrade.description,"values":upgrade.values.duplicate(),"requires":upgrade.prerequisite,"tag":upgrade.tag,"max_rank":upgrade.rank_limit()}

func refresh_translations() -> void:
	var locale := TranslationServer.get_locale()
	if _text_locale == locale: return
	_text_locale = locale
	for key: String in resources:
		var item: UpgradeDefinition = resources[key]
		_definitions[key]["name"] = item.display_name
		_definitions[key]["description"] = item.description
		_definitions[key]["tag"] = item.tag

func definition(key: String) -> UpgradeDefinition:
	return resources.get(key) as UpgradeDefinition

func max_rank(key: String) -> int:
	var upgrade := definition(key)
	return upgrade.rank_limit() if upgrade != null else 0

func rank_for(ranks: Dictionary, key: String) -> int:
	var item := definition(key)
	if item == null: return 0
	if not item.element_id.is_empty():
		if str(ranks.get("element_type", "")) != item.element_id: return 0
		return int(ranks.get("enchant_rank" if item.is_enchantment else "element_skill_rank", 0))
	return int(ranks.get(key, 0))

func choice_rank(ranks: Dictionary, key: String) -> int:
	var item := definition(key)
	if item != null and item.is_enchantment and item.element_id != str(ranks.get("element_type", "")):
		return maxi(1, int(ranks.get("enchant_rank", 0)))
	return mini(max_rank(key), rank_for(ranks, key) + 1)

func eligible(ranks: Dictionary, _stats: CombatStats = null) -> Array[String]:
	var current := normalize_ranks(ranks)
	var result: Array[String] = []
	for key: String in definitions:
		var item := definition(key)
		if item.is_enchantment:
			if item.element_id != str(current.get("element_type", "")) or rank_for(current, key) < max_rank(key): result.append(key)
			continue
		if not item.element_id.is_empty():
			if item.element_id != str(current.get("element_type", "")) or int(current.get("enchant_rank", 0)) <= 0: continue
		if rank_for(current, key) < max_rank(key): result.append(key)
	return result

func apply_choice(ranks: Dictionary, key: String) -> Dictionary:
	var result := normalize_ranks(ranks)
	if not eligible(result).has(key): return result
	var item := definition(key)
	if item.is_enchantment:
		result["enchant_rank"] = choice_rank(result, key)
		result["element_type"] = item.element_id
	elif not item.element_id.is_empty(): result["element_skill_rank"] = rank_for(result, key) + 1
	else: result[key] = rank_for(result, key) + 1
	return normalize_ranks(result)

func practice_change(ranks: Dictionary, key: String, rank: int) -> Dictionary:
	var result := normalize_ranks(ranks)
	var item := definition(key)
	if item == null: return result
	if item.is_enchantment:
		if rank > 0 and item.element_id != str(result.get("element_type", "")):
			result["enchant_rank"] = maxi(rank, int(result.get("enchant_rank", 0))) if not result.has("element_type") else int(result.get("enchant_rank", rank))
			result["element_type"] = item.element_id
		elif item.element_id == str(result.get("element_type", "")):
			result["enchant_rank"] = rank
	elif not item.element_id.is_empty():
		if item.element_id == str(result.get("element_type", "")): result["element_skill_rank"] = rank
	else: result[key] = rank
	return normalize_ranks(result)

func value(key: String, rank: int) -> float:
	var upgrade := definition(key)
	return upgrade.value_at(rank) if upgrade != null else 0.0

func parameter(key: String, property: String, rank: int, fallback: float = 0.0) -> float:
	var upgrade := definition(key)
	return upgrade.rank_parameter(upgrade.get(property), rank, fallback) if upgrade != null else fallback

func count(key: String, rank: int) -> int:
	var upgrade := definition(key)
	return upgrade.base_count + int(upgrade.value_at(rank)) if upgrade != null else 1

## Selected rank only: benefits and costs, without a before/after preview.
func describe_change(key: String, current_rank: int) -> String:
	if not definitions.has(key):
		return ""
	var maximum: int = max_rank(key)
	var current: int = clampi(current_rank, 0, maximum)
	if current >= maximum:
		return GameLocale.text("RANK_MAX")
	return describe_rank(key, current + 1)

func describe_rank(key: String, rank: int) -> String:
	if rank <= 0: return GameLocale.text("RANK_NONE")
	return _describe_value(key, clampi(rank, 0, max_rank(key)))

func _describe_value(key: String, rank: int) -> String:
	var amount: float = value(key, rank)
	var upgrade := definition(key)
	if upgrade.is_enchantment:
		return GameLocale.text("DESC_ENCHANT") % [_number(amount), GameLocale.element_name(upgrade.element_id)]
	if upgrade.element_skill != null:
		return _describe_element_skill(upgrade.element_skill, rank)
	match key:
		"vitality": return GameLocale.text("DESC_VITALITY") % _number(amount)
		"damage": return GameLocale.text("DESC_DAMAGE") % _number(amount)
		"damage_flat": return GameLocale.text("DESC_DAMAGE_FLAT") % _number(amount)
		"attack_speed": return GameLocale.text("DESC_ATTACK_SPEED") % _number(amount * 100.0)
		"crit_chance": return GameLocale.text("DESC_CRIT_CHANCE") % _number(amount * 100.0)
		"crit_damage": return GameLocale.text("DESC_CRIT_DAMAGE") % _number(amount)
		"move_speed": return GameLocale.text("DESC_MOVE_SPEED") % _number(amount * 100.0)
		"pickup_radius": return GameLocale.text("DESC_PICKUP") % _number(amount)
		"regen": return GameLocale.text("DESC_REGEN") % _number(amount)
		"shield": return GameLocale.text("DESC_SHIELD") % [int(amount), _number(upgrade.crit_per_shield * 100.0)]
		"split": return GameLocale.text("DESC_SPLIT") % [upgrade.fragment_angles_degrees.size(), _number(amount * 100.0)] if amount > 0.0 else GameLocale.text("DESC_NO_SPLIT")
		"knockback": return GameLocale.text("DESC_KNOCKBACK") % _number(amount * 100.0)
		"long_draw": return GameLocale.text("DESC_LONG_DRAW") % _number(amount * 100.0)
		"pierce":
			return GameLocale.text("DESC_PIERCE") % [count(key, rank), _number(parameter(key, "retention_by_rank", rank) * 100.0)]
		"burst": return GameLocale.text("DESC_BURST") % [count(key, rank), _number(parameter(key, "spacing_by_rank", rank)), _number(parameter(key, "damage_multiplier_by_rank", rank, 1.0) * 100.0), _number((1.0 - parameter(key, "damage_multiplier_by_rank", rank, 1.0)) * 100.0)]
		"spread_arrow": return GameLocale.text("DESC_FAN") % [count(key, rank), _number(upgrade.side_arrow_damage * 100.0)]
	return "%s" % _number(amount)

func _number(amount: float) -> String:
	return UpgradeDefinition.number(amount)

## One shared investment survives type switches. Per-element IDs are accepted
## as fixture/import inputs only; normalized runtime state never has dead ranks.
func selected_elements(ranks: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var element := str(ranks.get("element_type", ""))
	if not element.is_empty() and int(ranks.get("enchant_rank", 0)) > 0: result.append(element)
	return result

func normalize_ranks(requested: Dictionary, _preferred_element: String = "") -> Dictionary:
	var result: Dictionary = {}
	for key: String in definitions:
		if not definition(key).element_id.is_empty(): continue
		var rank := clampi(int(requested.get(key, 0)), 0, max_rank(key))
		if rank > 0: result[key] = rank
	var element := str(requested.get("element_type", ""))
	var enchant := int(requested.get("enchant_rank", 0))
	var ability := int(requested.get("element_skill_rank", 0))
	if element.is_empty():
		for key: String in definitions:
			var item := definition(key)
			if item.is_enchantment and int(requested.get(key, 0)) > 0:
				element = item.element_id
				enchant = int(requested[key])
				ability = int(requested.get(element + "_bow", 0))
				break
	if definitions.has(element + "_enchant") and enchant > 0:
		result["element_type"] = element
		result["enchant_rank"] = clampi(enchant, 0, max_rank(element + "_enchant"))
		result["element_skill_rank"] = clampi(ability, 0, max_rank(element + "_bow"))
	return result

func describe_choice(key: String, ranks: Dictionary) -> String:
	var description := describe_build_rank(key, choice_rank(ranks, key), ranks)
	var item := definition(key)
	if item != null and item.is_enchantment and ranks.has("element_type") and item.element_id != str(ranks.element_type):
		description += GameLocale.text("DESC_SWITCH") % [int(ranks.get("enchant_rank", 0)), int(ranks.get("element_skill_rank", 0))]
	return description

func _describe_element_skill(skill: ElementSkillDefinition, rank: int) -> String:
	match skill.element_id:
		"fire": return GameLocale.text("DESC_FIRE") % [_number(skill.parameter(skill.damage_by_rank, rank) * 100), _number(skill.parameter(skill.radius_by_rank, rank)), _number(skill.parameter(skill.burn_chance_by_rank, rank) * 100), _number(skill.parameter(skill.burn_dps_by_rank, rank) * 100), _number(skill.burn_duration)]
		"lightning": return GameLocale.text("DESC_LIGHTNING") % [int(skill.parameter(skill.targets_by_rank, rank)), _number(skill.parameter(skill.damage_by_rank, rank) * 100), _number(skill.chain_range), _number(skill.parameter(skill.shock_chance_by_rank, rank) * 100), _number(skill.shock_duration), _number(skill.parameter(skill.shock_bonus_by_rank, rank) * 100)]
		"ice": return GameLocale.text("DESC_ICE") % [_number(skill.chill_fraction * 100), _number(skill.chill_duration), skill.frost_threshold, _number(skill.parameter(skill.freeze_by_rank, rank)), _number(skill.shatter_multiplier), _number(skill.frost_window), _number(skill.thaw_immunity), _number(skill.boss_chill_fraction * 100), skill.boss_frost_threshold, _number(skill.boss_mark_duration), _number(skill.shatter_multiplier)]
		"dark":
			var g := skill.gravity
			if g == null: return GameLocale.text("DESC_GRAVITY_MISSING")
			return GameLocale.text("DESC_DARK") % [_number(g.parameter(g.speed_by_rank, rank)), _number(g.parameter(g.outer_radius_by_rank, rank)), _number(g.parameter(g.inner_radius_by_rank, rank)), _number(100 * g.parameter(g.damage_per_second_by_rank, rank)), _number(g.base_gap), _number(g.minimum_gap)]

	return ""

func describe_build_rank(key: String, rank: int, ranks: Dictionary) -> String:
	if key == "pierce" and int(ranks.get("element_skill_rank", 0)) > 0:
		match str(ranks.get("element_type", "")):
			"dark": return GameLocale.text("DESC_PIERCE_DARK")
			"fire": return GameLocale.text("DESC_PIERCE_FIRE")
	if str(ranks.get("element_type", "")) != "dark" or int(ranks.get("element_skill_rank", 0)) <= 0 or rank <= 0:
		return describe_rank(key, rank)
	var g := definition("dark_bow").element_skill.gravity
	match key:
		"burst": return GameLocale.text("DESC_DARK_BURST") % _number(g.parameter(g.burst_dot_bonus, rank) * 100)
		"spread_arrow": return GameLocale.text("DESC_DARK_FAN") % _number(g.parameter(g.fan_outer_bonus, rank) * 100)
		"split": return GameLocale.text("DESC_DARK_SPLIT") % _number(g.parameter(g.split_inner_bonus, rank) * 100)
		"long_draw": return GameLocale.text("DESC_DARK_LONG") % _number(value(key, rank) * 100)
		"knockback": return GameLocale.text("DESC_DARK_KNOCKBACK") % [_number(value(key, rank) * g.pull_upgrade_scale * 100), _number(g.pull_multiplier_cap)]
		"attack_speed": return GameLocale.text("DESC_DARK_SPEED") % [_number(value(key, rank) * 100), _number(g.minimum_gap)]
	return describe_rank(key, rank)
