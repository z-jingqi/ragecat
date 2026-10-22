class_name ElementSkillDefinition
extends Resource
## Per-element bow ability tuning. Enchantments themselves never activate these.
@export var element_id: String = ""
@export var popup_label: String = ""
@export var damage_by_rank := PackedFloat32Array([0, 1, 1.5, 2])
@export var radius_by_rank := PackedFloat32Array([0, 70, 85, 100])
@export var targets_by_rank := PackedInt32Array([0, 2, 3, 4])
@export var duration_by_rank := PackedFloat32Array([0, 0.6, 0.8, 1.0])
@export_range(0, 1000, 1) var chain_range: float = 140.0
@export_range(0, 1, 0.01) var chill_fraction: float = 0.2
@export_range(0, 1, 0.01) var boss_chill_fraction: float = 0.1
@export_range(0, 60, 0.01) var chill_duration: float = 2.0
@export_range(1, 100, 1) var frost_threshold: int = 3
@export_range(0, 60, 0.01) var frost_window: float = 2.0
@export var freeze_by_rank := PackedFloat32Array([0, 0.4, 0.6, 0.8])
@export_range(0, 60, 0.01) var thaw_immunity: float = 2.0
@export_range(0, 60, 0.01) var shared_cooldown: float = 2.5
@export_range(0, 2000, 1) var pull_speed: float = 120.0
@export_range(0, 10, 0.01) var pull_upgrade_scale: float = 1.0
@export_range(1, 10, 0.01) var pull_multiplier_cap: float = 2.0
@export var color: Color = Color("fd9b54")
@export_range(0.01, 10, 0.01) var flash_duration: float = 0.25

func parameter(sequence: Variant, rank: int) -> float:
	return float(sequence[clampi(rank, 0, sequence.size() - 1)]) if not sequence.is_empty() else 0.0

func validated_copy() -> ElementSkillDefinition:
	var copy := duplicate(true) as ElementSkillDefinition
	DefinitionValidation.nonnegative_floats(copy, ElementSkillDefinition.new())
	copy.damage_by_rank = DefinitionValidation.rank_floats(copy.damage_by_rank)
	copy.radius_by_rank = DefinitionValidation.rank_floats(copy.radius_by_rank)
	copy.duration_by_rank = DefinitionValidation.rank_floats(copy.duration_by_rank)
	copy.freeze_by_rank = DefinitionValidation.rank_floats(copy.freeze_by_rank)
	for i in range(copy.targets_by_rank.size()): copy.targets_by_rank[i] = maxi(0, copy.targets_by_rank[i])
	copy.chill_fraction = minf(1, copy.chill_fraction)
	copy.boss_chill_fraction = minf(1, copy.boss_chill_fraction)
	copy.frost_threshold = maxi(1, copy.frost_threshold)
	copy.pull_multiplier_cap = maxf(1, copy.pull_multiplier_cap)
	copy.flash_duration = maxf(0.01, copy.flash_duration)
	return copy
