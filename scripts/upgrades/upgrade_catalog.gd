class_name UpgradeCatalog
extends RefCounted
## Compatibility dictionaries are derived from independently authored upgrade resources.
const UPGRADES := [
	preload("res://resources/upgrades/split.tres"),
	preload("res://resources/upgrades/knockback.tres"),
	preload("res://resources/upgrades/long_draw.tres"),
	preload("res://resources/upgrades/vitality.tres"),
	preload("res://resources/upgrades/damage.tres"),
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

func _init() -> void:
	for upgrade: UpgradeDefinition in UPGRADES:
		definitions[upgrade.upgrade_id] = {"name":upgrade.display_name,"description":upgrade.description,"values":upgrade.values,"requires":upgrade.prerequisite,"tag":upgrade.tag}


func eligible(ranks: Dictionary, stats: CombatStats = null) -> Array[String]:
	var result: Array[String] = []
	for key: String in definitions:
		var definition: Dictionary = definitions[key]
		if int(ranks.get(key, 0)) >= int(definition["values"].size()) - 1:
			continue
		var prerequisite: String = str(definition.get("requires", ""))
		if not prerequisite.is_empty() and int(ranks.get(prerequisite, 0)) == 0:
			continue
		result.append(key)
	return result

func value(key: String, rank: int) -> float:
	if not definitions.has(key):
		return 0.0
	return float(definitions[key]["values"][clampi(rank, 0, int(definitions[key]["values"].size())-1)])

## Numeric card preview. Shows this upgrade's contribution, not other upgrades.
func describe_change(key: String, current_rank: int) -> String:
	if not definitions.has(key):
		return ""
	var maximum: int = int(definitions[key]["values"].size()) - 1
	var current: int = clampi(current_rank, 0, maximum)
	if current >= maximum:
		return "MAX RANK"
	return "%s -> %s" % [_describe_value(key, current), _describe_value(key, current + 1)]

func _describe_value(key: String, rank: int) -> String:
	var amount: float = value(key, rank)
	match key:
		"vitality": return "+%s max HP" % _number(amount)
		"damage": return "+%s%% arrow damage" % _number(amount)
		"attack_speed": return "+%s%% attack speed" % _number(amount * 100.0)
		"crit_chance": return "+%s%% crit chance" % _number(amount * 100.0)
		"crit_damage": return "+%s crit multiplier" % _number(amount)
		"move_speed": return "+%s%% movement speed" % _number(amount * 100.0)
		"pickup_radius": return "+%s pickup radius" % _number(amount)
		"regen": return "%s HP/s" % _number(amount)
		"shield": return "%d shield capacity" % int(amount)
		"poison": return "%s poison DPS / 4s" % _number(amount)
		"bleed": return "%s bleed DPS / 4s" % _number(amount)
		"poison_crit": return "+%s pp crit vs poisoned" % _number(amount * 100.0)
		"split": return "2 fragments / %s%% damage" % _number(amount * 100.0) if amount > 0.0 else "no fragments"
		"knockback": return "+%s%% knockback" % _number(amount * 100.0)
		"long_draw": return "+%s%% range and arrow speed" % _number(amount * 100.0)
		"spread": return "%s spread radius / 3 targets" % _number(amount)
		"pierce":
			var retention: float = [70.0, 75.0, 85.0, 95.0][clampi(rank, 0, 3)]
			return "%d hits / %s%% retained" % [1 + int(amount), _number(retention)]
		"burst": return "%d bursts / 0.12s spacing" % (1 + int(amount))
		"spread_arrow": return "%d arrows per burst" % (1 + int(amount))
		"bleed_regen": return "%s bonus HP/s / 3s buff" % _number(amount)
	return "%s" % _number(amount)

func _number(amount: float) -> String:
	return ("%.2f" % amount).trim_suffix("0").trim_suffix("0").trim_suffix(".")
