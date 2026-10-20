class_name CombatStats
extends Resource
## Mutable run state. Definitions are read-only inputs, never modified by combat.
## Percentages are fractions except damage_percent (20 means +20%).
var character: CharacterDefinition:
	set(value):
		# A run owns its snapshot, including nested resources and upgrade arrays.
		character = value.validated_copy() if value != null else null
var combat_definition: CombatDefinition
var catalog: UpgradeCatalog
var max_hp: float
var hp: float
var shield_capacity: int
var shields: int
var damage_percent: float
var attack_speed: float
var crit_chance: float
var crit_multiplier: float
var move_speed: float
var pickup_radius: float
var regen: float
var poison_dps: float
var bleed_dps: float
var status_duration: float
var poison_crit: float
var spread_radius: float
var pierce_max_hits: int
var pierce_retention: float
var burst_count: int
var burst_spacing: float
var spread_arrow_count: int
var split_damage: float
var split_angles: PackedFloat32Array
var bleed_regen: float
var bleed_regen_duration: float
var arrow_damage: float
var arrow_rate: float
var arrow_speed: float
var arrow_range: float
var arrow_width: float
var arrow_collision_width_scale: float
var arrow_spawn_offset: float
var fan_spread_angle: float
var side_arrow_damage: float
var primary_projectile_limit: int
var fragment_projectile_limit: int
var knockback: float
var poison_duration: float
var bleed_duration: float
var spread_max_targets: int
var bleed_regen_buff: float
var shield_crit_per_charge: float
var hit_immunity: float
var status_tick_interval: float
var collision_radius: float
var arena_padding: float
var dash_speed: float
var dash_duration: float
var dash_cooldown_duration: float
var dash_grants_immunity: bool
var hit_feedback_duration: float
var ranks: Dictionary = {}

func _init(source: CharacterDefinition = null) -> void:
	character = source if source != null else CharacterDefinition.new()
	hp = character.base_health
	apply_ranks({})
	hp = max_hp

func apply_ranks(new_ranks: Dictionary) -> void:
	var base := character if character != null else CharacterDefinition.new()
	var weapon := base.bow if base.bow != null else BowDefinition.new()
	combat_definition = base.combat if base.combat != null else CombatDefinition.new()
	catalog = UpgradeCatalog.new(base.upgrades)
	ranks = new_ranks.duplicate()
	# Rebuild from definition values; repeated rank changes cannot compound.
	arrow_damage = weapon.damage
	arrow_rate = weapon.rate
	arrow_speed = weapon.projectile_speed
	arrow_range = weapon.projectile_range
	arrow_width = weapon.projectile_width
	arrow_collision_width_scale = weapon.collision_width_scale
	arrow_spawn_offset = weapon.spawn_offset
	primary_projectile_limit = weapon.primary_projectile_limit
	fragment_projectile_limit = weapon.fragment_projectile_limit
	knockback = weapon.knockback
	max_hp = base.base_health + _value("vitality")
	hp = clampf(hp, 0.0, max_hp)
	shield_capacity = int(_value("shield"))
	shields = clampi(shields, 0, shield_capacity)
	damage_percent = combat_definition.base_damage_percent + _value("damage")
	attack_speed = combat_definition.base_attack_speed + _value("attack_speed")
	crit_chance = combat_definition.base_crit_chance + _value("crit_chance")
	crit_multiplier = combat_definition.base_crit_multiplier + _value("crit_damage")
	move_speed = base.base_move_speed * (1.0 + _value("move_speed"))
	pickup_radius = base.base_pickup_radius + _value("pickup_radius")
	regen = combat_definition.base_regen + _value("regen")
	poison_dps = _value("poison")
	bleed_dps = _value("bleed")
	poison_crit = _value("poison_crit")
	spread_radius = _value("spread")
	pierce_max_hits = catalog.count("pierce", _rank("pierce"))
	pierce_retention = _parameter("pierce", "retention_by_rank", 1.0)
	burst_count = catalog.count("burst", _rank("burst"))
	burst_spacing = _parameter("burst", "spacing_by_rank")
	spread_arrow_count = catalog.count("spread_arrow", _rank("spread_arrow"))
	bleed_regen = _value("bleed_regen")
	bleed_regen_buff = bleed_regen
	bleed_regen_duration = _parameter("bleed_regen", "duration_by_rank")
	split_damage = _value("split")
	var split := catalog.definition("split")
	split_angles = PackedFloat32Array()
	if split != null:
		for degrees: float in split.fragment_angles_degrees:
			split_angles.append(deg_to_rad(degrees))
	var fan := catalog.definition("spread_arrow")
	fan_spread_angle = deg_to_rad(fan.fan_spacing_degrees) if fan != null else 0.0
	side_arrow_damage = fan.side_arrow_damage if fan != null else 1.0
	var shield := catalog.definition("shield")
	shield_crit_per_charge = shield.crit_per_shield if shield != null else 0.0
	status_duration = combat_definition.default_status_duration
	poison_duration = _parameter("poison", "duration_by_rank", status_duration)
	bleed_duration = _parameter("bleed", "duration_by_rank", status_duration)
	spread_max_targets = int(_parameter("spread", "targets_by_rank"))
	hit_immunity = combat_definition.hit_immunity
	status_tick_interval = combat_definition.status_tick_interval
	collision_radius = base.collision_radius
	arena_padding = base.arena_padding
	dash_speed = base.dash_speed
	dash_duration = base.dash_duration
	dash_cooldown_duration = base.dash_cooldown
	dash_grants_immunity = base.dash_grants_immunity
	hit_feedback_duration = base.hit_feedback_duration
	knockback *= 1.0 + _value("knockback")
	arrow_range *= 1.0 + _value("long_draw")
	arrow_speed *= 1.0 + _value("long_draw")

func _rank(key: String) -> int:
	return int(ranks.get(key, 0))

func _value(key: String) -> float:
	return catalog.value(key, _rank(key))

func _parameter(key: String, property: String, fallback: float = 0.0) -> float:
	return catalog.parameter(key, property, _rank(key), fallback)
