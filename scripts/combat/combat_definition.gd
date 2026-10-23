class_name CombatDefinition
extends Resource
## Shared, editable combat rules. Runtime health/status objects copy these values.
## Independent ceilings: all sources combined, and current-shield contribution.
@export_range(0.0, 1.0) var total_crit_chance_cap: float = 0.60
@export_range(0.0, 1.0) var shield_crit_bonus_cap: float = 0.09
@export_range(0.0, 1.0) var base_crit_chance: float = 0.05
@export_range(0.0, 100.0, 0.01, "or_greater") var base_crit_multiplier: float = 2.0
@export var base_damage_percent: float = 0.0
@export_range(0.0, 100.0, 0.01, "or_greater") var base_attack_speed: float = 1.0
@export_range(0.0, 100.0, 0.01, "or_greater") var base_regen: float = 0.0
@export_range(0.0, 60.0, 0.01, "or_greater") var hit_immunity: float = 0.5

func validated_copy() -> CombatDefinition:
	var copy := duplicate(true) as CombatDefinition
	DefinitionValidation.nonnegative_floats(copy, CombatDefinition.new())
	copy.base_crit_chance = clampf(copy.base_crit_chance, 0.0, 1.0)
	copy.total_crit_chance_cap = clampf(copy.total_crit_chance_cap, 0.0, 1.0)
	copy.shield_crit_bonus_cap = clampf(copy.shield_crit_bonus_cap, 0.0, 1.0)
	return copy
