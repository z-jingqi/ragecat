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
var damage_flat: float
var burst_damage_multiplier: float
var damage_percent: float
var attack_speed: float
var crit_chance: float
var crit_multiplier: float
var move_speed: float
var pickup_radius: float
var regen: float
var pierce_max_hits: int
var pierce_retention: float
var burst_count: int
var burst_spacing: float
var spread_arrow_count: int
var split_damage: float
var split_angles: PackedFloat32Array
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
var shield_crit_per_charge: float
var hit_immunity: float
var collision_radius: float
var arena_padding: float
var dash_speed: float
var dash_duration: float
var dash_cooldown_duration: float
var dash_grants_immunity: bool
var hit_feedback_duration: float
var ranks: Dictionary = {}
var active_elements: Array[String] = []
var active_element: String = ""
var element_capacity: int = 1
var base_damage: float = 0.0
var element_damage: float = 0.0
var element_skill: ElementSkillDefinition
var element_skill_rank: int = 0
var knockback_bonus: float = 0.0
var gravity_outer_radius: float = 0.0
var gravity_inner_radius: float = 0.0
var gravity_acceleration: float = 0.0
var gravity_dps: float = 0.0
var gravity_gap: float = 0.5

## Authoritative probability for combat, previews and marginal-value calculations.
## Shield capacity is deliberately not used: only unspent charges grant crit.
func effective_shield_crit_bonus() -> float:
	var rules := combat_definition if combat_definition != null else CombatDefinition.new()
	var cap := clampf(rules.shield_crit_bonus_cap, 0.0, 1.0) if is_finite(rules.shield_crit_bonus_cap) else CombatDefinition.new().shield_crit_bonus_cap
	var per_charge := _safe_probability(shield_crit_per_charge, 0.0)
	return minf(cap, per_charge * maxi(0, shields))

func effective_crit_chance() -> float:
	var rules := combat_definition if combat_definition != null else CombatDefinition.new()
	var cap := clampf(rules.total_crit_chance_cap, 0.0, 1.0) if is_finite(rules.total_crit_chance_cap) else CombatDefinition.new().total_crit_chance_cap
	return minf(cap, _safe_probability(crit_chance, 0.0) + effective_shield_crit_bonus())

static func _safe_probability(value: float, fallback: float) -> float:
	return clampf(value, 0.0, 1.0) if is_finite(value) else fallback

func gravity_mode() -> bool:
	return active_element == "dark" and element_skill_rank > 0 and element_skill != null and element_skill.gravity != null

func fire_mode() -> bool:
	return active_element == "fire" and element_skill_rank > 0 and element_skill != null

func effective_pierce_text() -> String:
	if gravity_mode(): return GameLocale.text("HUD_PIERCE_DARK")
	if fire_mode(): return GameLocale.text("HUD_PIERCE_FIRE")
	return GameLocale.text("HUD_PIERCE") % [pierce_max_hits, UpgradeDefinition.number(pierce_retention * 100)]

func _init(source: CharacterDefinition = null) -> void:
	character = source if source != null else CharacterDefinition.new()
	hp = character.base_health
	apply_ranks({})
	hp = max_hp

func apply_ranks(new_ranks: Dictionary) -> void:
	var base := character if character != null else CharacterDefinition.new()
	var weapon := base.bow if base.bow != null else BowDefinition.new()
	combat_definition = base.combat if base.combat != null else CombatDefinition.new()
	var previous_catalog := catalog
	catalog = UpgradeCatalog.new(base.upgrades, combat_definition)
	if previous_catalog != null:
		catalog.progression = previous_catalog.progression
		catalog.all_unlocked = previous_catalog.all_unlocked
	ranks = catalog.normalize_ranks(new_ranks)
	active_elements = catalog.selected_elements(ranks)
	active_element = active_elements[0] if not active_elements.is_empty() else ""
	element_capacity = base.element_capacity
	element_skill = null
	element_skill_rank = 0
	if not active_element.is_empty():
		var ability := catalog.definition(active_element + "_bow")
		element_skill_rank = _rank(active_element + "_bow")
		if ability != null and element_skill_rank > 0: element_skill = ability.element_skill
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
	damage_flat = _value("damage_flat")
	damage_percent = combat_definition.base_damage_percent + _value("damage")
	base_damage = (weapon.damage + damage_flat) * (1.0 + damage_percent / 100.0)
	element_damage = _value(active_element + "_enchant") * (1.0 + damage_percent / 100.0) if not active_element.is_empty() else 0.0
	attack_speed = combat_definition.base_attack_speed + _value("attack_speed")
	crit_chance = combat_definition.base_crit_chance + _value("crit_chance")
	crit_multiplier = combat_definition.base_crit_multiplier + _value("crit_damage")
	move_speed = base.base_move_speed * (1.0 + _value("move_speed"))
	pickup_radius = base.base_pickup_radius + _value("pickup_radius")
	regen = combat_definition.base_regen + _value("regen")
	pierce_max_hits = catalog.count("pierce", _rank("pierce"))
	pierce_retention = _parameter("pierce", "retention_by_rank", 1.0)
	burst_count = catalog.count("burst", _rank("burst"))
	burst_damage_multiplier = _parameter("burst", "damage_multiplier_by_rank", 1.0)
	burst_spacing = _parameter("burst", "spacing_by_rank")
	spread_arrow_count = catalog.count("spread_arrow", _rank("spread_arrow"))
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
	hit_immunity = combat_definition.hit_immunity
	collision_radius = base.collision_radius
	arena_padding = base.arena_padding
	dash_speed = base.dash_speed
	dash_duration = base.dash_duration
	dash_cooldown_duration = base.dash_cooldown
	dash_grants_immunity = base.dash_grants_immunity
	hit_feedback_duration = base.hit_feedback_duration
	knockback_bonus = _value("knockback")
	knockback *= 1.0 + knockback_bonus
	arrow_range *= 1.0 + _value("long_draw")
	if gravity_mode():
		var gravity := element_skill.gravity
		arrow_speed = maxf(gravity.minimum_speed, gravity.parameter(gravity.speed_by_rank, element_skill_rank))
		gravity_inner_radius = gravity.parameter(gravity.inner_radius_by_rank, element_skill_rank) * (1.0 + gravity.parameter(gravity.split_inner_bonus, _rank("split")))
		gravity_outer_radius = maxf(gravity_inner_radius, gravity.parameter(gravity.outer_radius_by_rank, element_skill_rank) * (1.0 + gravity.parameter(gravity.fan_outer_bonus, _rank("spread_arrow"))))
		gravity_acceleration = gravity.parameter(gravity.acceleration_by_rank, element_skill_rank) * clampf(1.0 + knockback_bonus * gravity.pull_upgrade_scale, 1.0, gravity.pull_multiplier_cap)
		gravity_dps = element_damage * gravity.parameter(gravity.damage_per_second_by_rank, element_skill_rank) * (1.0 + gravity.parameter(gravity.burst_dot_bonus, _rank("burst")))
		gravity_gap = maxf(gravity.minimum_gap, gravity.base_gap / maxf(0.01, 1.0 + _value("attack_speed")))
		burst_damage_multiplier = 1.0
	else:
		arrow_speed *= 1.0 + _value("long_draw")

func _rank(key: String) -> int:
	return catalog.rank_for(ranks, key)

func _value(key: String) -> float:
	return catalog.value(key, _rank(key))

func _parameter(key: String, property: String, fallback: float = 0.0) -> float:
	return catalog.parameter(key, property, _rank(key), fallback)
