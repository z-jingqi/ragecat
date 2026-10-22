class_name GravityDefinition
extends Resource
## Moving dark-arrow tuning. Rank zero never activates this mode.
@export var speed_by_rank := PackedFloat32Array([0, 180, 140, 110])
@export var outer_radius_by_rank := PackedFloat32Array([0, 140, 160, 180])
@export var inner_radius_by_rank := PackedFloat32Array([0, 50, 65, 80])
@export var acceleration_by_rank := PackedFloat32Array([0, 900, 1200, 1500])
@export var damage_per_second_by_rank := PackedFloat32Array([0, 1, 1.3, 1.6])
@export var burst_dot_bonus := PackedFloat32Array([0, 0.15, 0.30, 0.45])
@export var fan_outer_bonus := PackedFloat32Array([0, 0.10, 0.20, 0.30])
@export var split_inner_bonus := PackedFloat32Array([0, 0.10, 0.20, 0.30])
@export var minimum_speed: float = 1.0
@export var lifetime: float = 8.0
@export var base_gap: float = 0.5
@export var minimum_gap: float = 0.3
@export var tick_interval: float = 0.2
@export var contact_grace: float = 0.1
@export var pull_speed_cap: float = 240.0
@export var pull_damping: float = 8.0
@export var pull_upgrade_scale: float = 1.0
@export var pull_multiplier_cap: float = 2.0
@export var tip_offset: float = 15.0

func parameter(values: PackedFloat32Array, rank: int) -> float:
	return values[clampi(rank, 0, values.size()-1)] if not values.is_empty() else 0.0

func validated_copy() -> GravityDefinition:
	var copy := duplicate(true) as GravityDefinition
	DefinitionValidation.nonnegative_floats(copy, GravityDefinition.new())
	for key in ["speed_by_rank", "outer_radius_by_rank", "inner_radius_by_rank", "acceleration_by_rank", "damage_per_second_by_rank", "burst_dot_bonus", "fan_outer_bonus", "split_inner_bonus"]:
		copy.set(key, DefinitionValidation.rank_floats(copy.get(key)))
	copy.minimum_speed = maxf(0.01, copy.minimum_speed)
	copy.lifetime = maxf(0.01, copy.lifetime)
	copy.tick_interval = maxf(0.01, copy.tick_interval)
	copy.minimum_gap = maxf(0.3, copy.minimum_gap)
	copy.base_gap = maxf(copy.minimum_gap, copy.base_gap)
	copy.pull_multiplier_cap = maxf(1.0, copy.pull_multiplier_cap)
	copy.contact_grace = minf(copy.contact_grace, maxf(0.0, copy.minimum_gap - 0.2))
	var previous := INF
	for i in range(1, copy.speed_by_rank.size()):
		copy.speed_by_rank[i] = minf(previous, maxf(copy.minimum_speed, copy.speed_by_rank[i]))
		previous = copy.speed_by_rank[i]
	return copy
