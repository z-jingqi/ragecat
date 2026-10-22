class_name UpgradeDefinition
extends Resource

@export var upgrade_id: String
@export var display_name: String
## Tokens are resolved from this same definition, never duplicated balance text.
@export_multiline var description_template: String
@export_range(0, 3, 1) var max_rank: int = 3
@export var values: PackedFloat32Array
@export var prerequisite: String
@export var tag: String
@export var element_id: String
@export var is_enchantment: bool = false
@export var element_skill: ElementSkillDefinition
@export_group("Secondary rank parameters")
@export var duration_by_rank: PackedFloat32Array
@export var retention_by_rank: PackedFloat32Array
@export var targets_by_rank: PackedInt32Array
@export var spacing_by_rank: PackedFloat32Array
## Final multiplier for each rank, not multiplied cumulatively.
@export var damage_multiplier_by_rank: PackedFloat32Array
@export_range(0, 100, 1, "or_greater") var base_count: int = 0
@export_group("Projectile and shield parameters")
@export var fragment_angles_degrees: PackedFloat32Array
@export_range(0.0, 180.0, 0.01) var fan_spacing_degrees: float = 0.0
@export_range(0.0, 10.0, 0.01, "or_greater") var side_arrow_damage: float = 1.0
@export_range(0.0, 1.0, 0.01) var crit_per_shield: float = 0.0

var description: String:
	get:
		var text := description_template
		var tokens := {
			"values": _rank_list(values),
			"percent_values": _rank_list(values, 100.0),
			"durations": _rank_list(duration_by_rank),
			"targets": _rank_list(targets_by_rank),
			"spacing": _rank_list(spacing_by_rank),
			"damage_multiplier_percent": _rank_list(damage_multiplier_by_rank, 100.0),
			"retention_percent_values": _rank_list(retention_by_rank, 100.0),
			"fragment_count": str(fragment_angles_degrees.size()),
			"side_damage_percent": number(side_arrow_damage * 100.0),
			"shield_crit_percent": number(crit_per_shield * 100.0),
			"max_rank": str(rank_limit()),
		}
		for token: String in tokens:
			text = text.replace("{" + token + "}", str(tokens[token]))
		return text

func rank_limit() -> int:
	return mini(clampi(max_rank, 0, 3), maxi(0, values.size() - 1))

func value_at(rank: int) -> float:
	return rank_parameter(values, rank)

func rank_parameter(sequence: Variant, rank: int, fallback: float = 0.0) -> float:
	if sequence.is_empty():
		return fallback
	return float(sequence[clampi(rank, 0, mini(rank_limit(), sequence.size() - 1))])

func _rank_list(sequence: Variant, scale: float = 1.0) -> String:
	var parts: PackedStringArray = []
	for rank in range(1, rank_limit() + 1):
		var formatted := number(rank_parameter(sequence, rank) * scale)
		if parts.is_empty() or formatted != parts[-1]:
			parts.append(formatted)
	return "/".join(parts)

static func number(amount: float) -> String:
	return ("%.2f" % amount).trim_suffix("0").trim_suffix("0").trim_suffix(".")

func validated_copy() -> UpgradeDefinition:
	var copy := duplicate(true) as UpgradeDefinition
	DefinitionValidation.nonnegative_floats(copy, UpgradeDefinition.new())
	copy.max_rank = clampi(copy.max_rank, 0, 3)
	if element_skill != null: copy.element_skill = element_skill.validated_copy()
	copy.values = DefinitionValidation.rank_floats(copy.values)
	copy.duration_by_rank = DefinitionValidation.rank_floats(copy.duration_by_rank)
	copy.retention_by_rank = DefinitionValidation.rank_floats(copy.retention_by_rank, 1.0)
	copy.spacing_by_rank = DefinitionValidation.rank_floats(copy.spacing_by_rank)
	copy.damage_multiplier_by_rank = DefinitionValidation.rank_floats(copy.damage_multiplier_by_rank, 1.0)
	for index in range(copy.targets_by_rank.size()):
		copy.targets_by_rank[index] = maxi(0, copy.targets_by_rank[index])
	copy.base_count = maxi(0, copy.base_count)
	copy.fan_spacing_degrees = minf(180.0, copy.fan_spacing_degrees)
	copy.crit_per_shield = minf(1.0, copy.crit_per_shield)
	copy.fragment_angles_degrees = PackedFloat32Array()
	for angle: float in fragment_angles_degrees:
		if is_finite(angle):
			copy.fragment_angles_degrees.append(wrapf(angle, -180.0, 180.0))
	return copy
