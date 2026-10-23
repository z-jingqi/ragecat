class_name SpitterDefinition
extends Resource
@export_group("Body and retreat")
@export_range(0.01, 1000, 0.01) var mass: float = 1.0
@export_range(0.01, 2, 0.01) var health_multiplier: float = 0.6
@export_range(1, 1000, 1) var move_speed: float = 105.0
@export_range(1, 100, 1) var radius: float = 15.0
@export_range(0, 2000, 1) var retreat_start: float = 220.0
@export_range(1, 2000, 1) var retreat_end: float = 280.0
@export var body_color: Color = Color("55d6c2")
@export_group("Shot")
@export var initial_shot_min_fraction: float = 0.5
@export var initial_shot_max_fraction: float = 1.0
@export_range(1, 4000, 1) var shoot_range: float = 520.0
@export_range(0.01, 60, 0.01) var shot_interval: float = 2.0
@export_range(0.01, 10, 0.01) var telegraph_duration: float = 0.4
@export_range(0, 1000, 1) var bullet_damage: float = 8.0
@export_range(1, 2000, 1) var bullet_speed: float = 240.0
@export_range(1, 100, 0.5) var bullet_radius: float = 6.0
@export_range(1, 4000, 1) var bullet_range: float = 620.0
@export var bullet_color: Color = Color("ffb65c")
@export var warning_color: Color = Color("ffdd86")

func validated_copy() -> SpitterDefinition:
	var copy := duplicate(true) as SpitterDefinition
	var defaults := SpitterDefinition.new()
	for property in get_property_list():
		if property.type == TYPE_FLOAT and not is_finite(float(copy.get(property.name))):
			copy.set(property.name, defaults.get(property.name))
	for key in ["mass", "health_multiplier", "move_speed", "radius", "shoot_range", "shot_interval", "telegraph_duration", "bullet_speed", "bullet_radius", "bullet_range"]:
		copy.set(key, maxf(0.01, float(copy.get(key))))
	copy.retreat_start = maxf(0.0, copy.retreat_start)
	copy.retreat_end = maxf(copy.retreat_start + 1.0, copy.retreat_end)
	copy.initial_shot_min_fraction = clampf(copy.initial_shot_min_fraction, 0.0, 1.0)
	copy.initial_shot_max_fraction = clampf(copy.initial_shot_max_fraction, copy.initial_shot_min_fraction, 1.0)
	copy.bullet_damage = maxf(0.0, copy.bullet_damage)
	return copy
