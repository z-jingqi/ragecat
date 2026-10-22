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
@export var freeze_by_rank := PackedFloat32Array([0, 0.65, 0.8, 1.0])
@export_range(0, 60, 0.01) var thaw_immunity: float = 2.0
@export_range(1, 100, 1) var boss_frost_threshold: int = 5
@export_range(0, 60, 0.01) var boss_mark_duration: float = 2.0
@export_range(1, 10, 0.1) var shatter_multiplier: float = 2.0
@export var burn_chance_by_rank := PackedFloat32Array([0, 0.2, 0.3, 0.4])
@export var burn_dps_by_rank := PackedFloat32Array([0, 0.2, 0.3, 0.4])
@export_range(0, 60, 0.01) var burn_duration: float = 3.0
@export_range(0.01, 10, 0.01) var burn_tick_interval: float = 0.25
@export var shock_chance_by_rank := PackedFloat32Array([0, 0.2, 0.3, 0.4])
@export var shock_bonus_by_rank := PackedFloat32Array([0, 0.1, 0.15, 0.2])
@export_range(0, 60, 0.01) var shock_duration: float = 2.0
@export var gravity: GravityDefinition
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
	copy.boss_frost_threshold = maxi(1, copy.boss_frost_threshold)
	copy.shatter_multiplier = maxf(1.0, copy.shatter_multiplier)
	copy.burn_chance_by_rank = DefinitionValidation.rank_floats(copy.burn_chance_by_rank)
	for i in range(copy.burn_chance_by_rank.size()): copy.burn_chance_by_rank[i] = minf(1.0, copy.burn_chance_by_rank[i])
	copy.burn_dps_by_rank = DefinitionValidation.rank_floats(copy.burn_dps_by_rank)
	copy.burn_tick_interval = maxf(0.01, copy.burn_tick_interval)
	copy.shock_chance_by_rank = DefinitionValidation.rank_floats(copy.shock_chance_by_rank)
	for i in range(copy.shock_chance_by_rank.size()): copy.shock_chance_by_rank[i] = minf(1.0, copy.shock_chance_by_rank[i])
	copy.shock_bonus_by_rank = DefinitionValidation.rank_floats(copy.shock_bonus_by_rank)
	if gravity != null: copy.gravity = gravity.validated_copy()
	copy.flash_duration = maxf(0.01, copy.flash_duration)
	return copy
