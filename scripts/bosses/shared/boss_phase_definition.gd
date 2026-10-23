class_name BossPhaseDefinition
extends Resource
## One immutable phase snapshot. Seconds and world units use game time.
@export var charge_count: int = 1
@export var repeat_charge_warning: float = 0.3
@export var combo_recovery: float = 1.2
@export var tracking_rock_count: int = 8
@export var tracking_rock_interval: float = 0.5
@export var tracking_rock_warning: float = 0.7
@export var tracking_rock_recovery: float = 1.0
@export var summon_count: int = 3
@export var summon_warning: float = 1.0
@export var summon_cooldown: float = 7.0
@export var summon_ring: bool = false
@export var projectile_angles: PackedFloat32Array = PackedFloat32Array([0.0])
@export var skyfire_splashes: int = 0
@export var ring_intervals: PackedFloat32Array = PackedFloat32Array([])

func snapshot() -> BossPhaseDefinition:
	var copy := duplicate(true) as BossPhaseDefinition
	var defaults := BossPhaseDefinition.new()
	for item in get_property_list():
		if item.type == TYPE_FLOAT:
			var value := float(copy.get(item.name))
			copy.set(item.name, maxf(0.0,value) if is_finite(value) else defaults.get(item.name))
	copy.charge_count = clampi(copy.charge_count,1,16)
	copy.tracking_rock_count = clampi(copy.tracking_rock_count,0,128)
	copy.tracking_rock_interval = maxf(0.01,copy.tracking_rock_interval)
	copy.summon_count = clampi(copy.summon_count,0,128)
	copy.skyfire_splashes = clampi(copy.skyfire_splashes,0,16)
	var angles := PackedFloat32Array()
	for angle in copy.projectile_angles:
		if is_finite(angle) and angles.size() < 16: angles.append(clampf(angle,-180,180))
	if angles.is_empty(): angles.append(0.0)
	copy.projectile_angles = angles
	var gaps := PackedFloat32Array()
	for gap in copy.ring_intervals:
		if is_finite(gap) and gaps.size() < 15: gaps.append(maxf(0.01,gap))
	copy.ring_intervals = gaps
	return copy
