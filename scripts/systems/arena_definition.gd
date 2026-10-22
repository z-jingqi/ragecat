class_name ArenaDefinition
extends Resource

@export_range(0.01, 1000, 0.01) var enemy_mass: float = 1.0
@export_range(0.01, 1000, 0.01) var boss_mass: float = 10.0
## Immutable run settings; RageArena snapshots this resource on entry.
@export var hit_feedback: HitFeedbackDefinition = preload("res://resources/feedback/hit_feedback.tres")
@export var damage_feedback: DamageFeedbackDefinition = DamageFeedbackDefinition.new()
@export_group("Arena")
@export var normal_bounds := Rect2(48, 104, 1184, 620)
@export var practice_bounds := Rect2(36, 104, 876, 620)
@export_range(1, 500, 1) var enemy_limit: int = 69
@export_range(1, 1000, 1) var enemy_projectile_limit: int = 128
@export_range(1, 1000, 1) var effect_limit: int = 70
@export_range(1, 10000, 1) var pickup_limit: int = 250
@export_range(0, 200, 1) var spawn_inset: float = 40.0
@export_range(0, 200, 1) var spawn_edge_inset: float = 35.0
@export_group("Experience")
@export_range(1, 1000, 1) var initial_xp_needed: int = 8
@export_range(1, 1000, 1) var xp_base: int = 8
@export_range(0, 100, 1) var xp_per_level: int = 3
@export_range(1, 10000, 1) var xp_limit: int = 60
@export_range(1, 100, 1) var pickup_value: int = 1
@export_range(0, 2000, 1) var pickup_speed: float = 360.0
@export_range(1, 200, 1) var pickup_collect_radius: float = 20.0
@export_range(1, 100, 1) var boss_pickup_count: int = 12
@export_range(0, 200, 1) var boss_pickup_ring: float = 22.0
@export_group("Difficulty and health")
@export_range(1, 10000, 1) var melee_health: float = 34.0
@export_range(1, 100000, 1) var boss_health: float = 900.0
@export_range(1, 1000000, 1) var dummy_health: float = 100000.0
@export_range(1, 3600, 1) var difficulty_period: float = 180.0
@export_range(0, 100, 0.1) var difficulty_bonus_cap: float = 8.0
@export_range(0, 5, 0.01) var boss_health_increment: float = 0.45
@export_range(0, 1000, 1) var contact_damage: float = 10.0
@export_group("Spawn cadence")
@export_range(0.01, 3600, 0.01) var boss_interval: float = 120.0
@export_range(0.01, 60, 0.01) var spawn_interval: float = 1.35
@export_range(0.01, 60, 0.01) var minimum_spawn_interval: float = 0.28
@export_range(1, 3600, 1) var spawn_acceleration_period: float = 330.0
@export_range(0.01, 10, 0.01) var boss_spawn_multiplier: float = 3.0
@export_group("Ranged population")
@export_range(0, 3600, 1) var ranged_intro_time: float = 45.0
@export_range(0, 1, 0.01) var ranged_fraction: float = 0.12
@export_range(0, 100, 1) var ranged_limit: int = 4
@export_group("Upgrade choices")
@export_range(1, 3, 1) var upgrade_choices: int = 3
@export_range(0, 1, 0.01) var heal_fraction: float = 0.35
@export_group("Boss defaults (arena overrides)")
@export_range(0.01, 10, 0.01) var boss_warning_duration: float = 1.0
@export_range(1, 500, 1) var boss_charge_width: float = 80.0
@export_range(1, 200, 1) var boss_rock_radius: float = 35.0
@export_group("Practice builds")
@export var practice_presets: Dictionary = {
	"preset_fire": {"element_type":"fire", "enchant_rank":3, "element_skill_rank":3, "pierce":3},
	"preset_lightning": {"element_type":"lightning", "enchant_rank":3, "element_skill_rank":3},
	"preset_ice": {"element_type":"ice", "enchant_rank":3, "element_skill_rank":3, "attack_speed":2},
	"preset_dark": {"element_type":"dark", "enchant_rank":3, "element_skill_rank":3, "knockback":3},
	"preset_split": {"split":3}, "preset_burst": {"burst":3},
	"preset_fan": {"spread_arrow":3}, "preset_long": {"long_draw":3},
	"preset_shieldcrit": {"shield":3,"crit_damage":3},
}
@export_group("Practice arrangement")
@export var practice_spawn_offset := Vector2(200, 0)
@export_range(1, 50, 1) var practice_line_count: int = 5
@export_range(0, 1000, 1) var practice_line_start: float = 90.0
@export_range(1, 500, 1) var practice_line_spacing: float = 65.0
@export_range(1, 50, 1) var practice_group_count: int = 8
@export_range(1, 1000, 1) var practice_group_radius: float = 180.0

func validated_copy() -> ArenaDefinition:
	var copy := duplicate(true) as ArenaDefinition
	var defaults := ArenaDefinition.new()
	if copy.hit_feedback == null: copy.hit_feedback = HitFeedbackDefinition.new()
	copy.hit_feedback = copy.hit_feedback.validated_copy()
	if copy.damage_feedback == null: copy.damage_feedback = DamageFeedbackDefinition.new()
	for property in get_property_list():
		if property.type == TYPE_FLOAT and not is_finite(float(copy.get(property.name))):
			copy.set(property.name, defaults.get(property.name))
	# Inspector hints are authoring aids, not runtime safety checks.
	for key in ["enemy_limit", "enemy_projectile_limit", "effect_limit", "pickup_limit", "initial_xp_needed", "xp_base", "xp_limit", "pickup_value", "boss_pickup_count", "upgrade_choices", "practice_line_count", "practice_group_count"]:
		copy.set(key, maxi(1, int(copy.get(key))))
	for key in ["melee_health", "boss_health", "dummy_health", "difficulty_period", "spawn_acceleration_period", "pickup_collect_radius"]:
		copy.set(key, maxf(1.0, float(copy.get(key))))
	for key in ["enemy_mass", "boss_mass", "boss_interval", "spawn_interval", "minimum_spawn_interval", "boss_spawn_multiplier", "boss_warning_duration"]:
		copy.set(key, maxf(0.01, float(copy.get(key))))
	for key in ["xp_per_level", "pickup_speed", "boss_health_increment", "spawn_inset", "spawn_edge_inset", "boss_pickup_ring", "practice_line_start", "practice_line_spacing", "practice_group_radius"]:
		copy.set(key, maxf(0.0, float(copy.get(key))))
	copy.boss_charge_width = maxf(1.0, copy.boss_charge_width)
	copy.boss_rock_radius = maxf(1.0, copy.boss_rock_radius)
	copy.upgrade_choices = mini(3, copy.upgrade_choices) # Three cards fit the supported menu layout.
	copy.ranged_fraction = clampf(copy.ranged_fraction, 0.0, 1.0)
	copy.ranged_limit = maxi(0, copy.ranged_limit)
	copy.ranged_intro_time = maxf(0.0, copy.ranged_intro_time)
	copy.heal_fraction = clampf(copy.heal_fraction, 0.0, 1.0)
	copy.contact_damage = maxf(0.0, copy.contact_damage)
	copy.difficulty_bonus_cap = maxf(0.0, copy.difficulty_bonus_cap)
	copy.normal_bounds.size = copy.normal_bounds.size.max(Vector2(100, 100))
	copy.practice_bounds.size = copy.practice_bounds.size.max(Vector2(100, 100))
	var smallest_side := minf(minf(copy.normal_bounds.size.x, copy.normal_bounds.size.y), minf(copy.practice_bounds.size.x, copy.practice_bounds.size.y))
	copy.spawn_inset = minf(copy.spawn_inset, smallest_side * 0.5)
	copy.spawn_edge_inset = minf(copy.spawn_edge_inset, smallest_side * 0.5)
	return copy
