class_name UpgradeCatalog
extends RefCounted
## Compatibility dictionaries are derived from independently authored upgrade resources.
const UPGRADES := [
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
	preload("res://resources/upgrades/poison.tres"),
	preload("res://resources/upgrades/bleed.tres"),
	preload("res://resources/upgrades/poison_crit.tres"),
	preload("res://resources/upgrades/spread.tres"),
	preload("res://resources/upgrades/pierce.tres"),
	preload("res://resources/upgrades/burst.tres"),
	preload("res://resources/upgrades/spread_arrow.tres"),
	preload("res://resources/upgrades/bleed_regen.tres"),
]
var definitions: Dictionary = {}
var resources: Dictionary = {}

func _init(configured_upgrades: Array[UpgradeDefinition] = []) -> void:
	var source: Array = UPGRADES if configured_upgrades.is_empty() else configured_upgrades
	for original: UpgradeDefinition in source:
		if original == null: continue
		var upgrade := original.validated_copy()
		resources[upgrade.upgrade_id] = upgrade
		# Copies prevent consumers of the legacy view from modifying source data.
		definitions[upgrade.upgrade_id] = {"name":upgrade.display_name,"description":upgrade.description,"values":upgrade.values.duplicate(),"requires":upgrade.prerequisite,"tag":upgrade.tag,"max_rank":upgrade.rank_limit()}

func definition(key: String) -> UpgradeDefinition:
	return resources.get(key) as UpgradeDefinition

func max_rank(key: String) -> int:
	var upgrade := definition(key)
	return upgrade.rank_limit() if upgrade != null else 0

func eligible(ranks: Dictionary, stats: CombatStats = null) -> Array[String]:
	var result: Array[String] = []
	for key: String in definitions:
		var definition: Dictionary = definitions[key]
		if int(ranks.get(key, 0)) >= max_rank(key):
			continue
		var prerequisite: String = str(definition.get("requires", ""))
		if not prerequisite.is_empty() and int(ranks.get(prerequisite, 0)) == 0:
			continue
		result.append(key)
	return result

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
		return "MAX RANK"
	return describe_rank(key, current + 1)

func describe_rank(key: String, rank: int) -> String:
	if rank <= 0: return "Not selected"
	return _describe_value(key, clampi(rank, 0, max_rank(key)))

func _describe_value(key: String, rank: int) -> String:
	var amount: float = value(key, rank)
	var upgrade := definition(key)
	match key:
		"vitality": return "+%s max HP" % _number(amount)
		"damage": return "+%s%% arrow damage" % _number(amount)
		"damage_flat": return "+%s flat arrow damage (before %%)" % _number(amount)
		"attack_speed": return "+%s%% attack speed" % _number(amount * 100.0)
		"crit_chance": return "+%s%% crit chance" % _number(amount * 100.0)
		"crit_damage": return "+%s crit multiplier" % _number(amount)
		"move_speed": return "+%s%% movement speed" % _number(amount * 100.0)
		"pickup_radius": return "+%s pickup radius" % _number(amount)
		"regen": return "%s HP/s" % _number(amount)
		"shield": return "%d shield capacity / +%s%% crit per shield" % [int(amount), _number(upgrade.crit_per_shield * 100.0)]
		"poison": return "%s poison DPS / %ss" % [_number(amount), _number(parameter(key, "duration_by_rank", rank))]
		"bleed": return "%s bleed DPS / %ss" % [_number(amount), _number(parameter(key, "duration_by_rank", rank))]
		"poison_crit": return "+%s pp crit vs poisoned" % _number(amount * 100.0)
		"split": return "%d fragments / %s%% damage" % [upgrade.fragment_angles_degrees.size(), _number(amount * 100.0)] if amount > 0.0 else "no fragments"
		"knockback": return "+%s%% knockback" % _number(amount * 100.0)
		"long_draw": return "+%s%% range and arrow speed" % _number(amount * 100.0)
		"spread": return "%s spread radius / %d targets" % [_number(amount), int(parameter(key, "targets_by_rank", rank))]
		"pierce":
			return "%d hits / %s%% retained" % [count(key, rank), _number(parameter(key, "retention_by_rank", rank) * 100.0)]
		"burst": return "%d volleys / %ss spacing\nEach arrow: %s%% damage (%s%% less)\nSide arrows and fragments inherit this cost" % [count(key, rank), _number(parameter(key, "spacing_by_rank", rank)), _number(parameter(key, "damage_multiplier_by_rank", rank, 1.0) * 100.0), _number((1.0 - parameter(key, "damage_multiplier_by_rank", rank, 1.0)) * 100.0)]
		"spread_arrow": return "%d arrows per burst / side arrows: %s%% damage" % [count(key, rank), _number(upgrade.side_arrow_damage * 100.0)]
		"bleed_regen": return "%s bonus HP/s / %ss buff" % [_number(amount), _number(parameter(key, "duration_by_rank", rank))]
	return "%s" % _number(amount)

func _number(amount: float) -> String:
	return UpgradeDefinition.number(amount)
