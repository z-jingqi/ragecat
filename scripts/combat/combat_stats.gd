class_name CombatStats
extends Resource
## All percentages are fractions except damage_percent (20 means +20%).
var character: CharacterDefinition
var max_hp: float = 100.0
var hp: float = 100.0
var shield_capacity: int = 0
var shields: int = 0
var damage_percent: float = 0.0
var attack_speed: float = 1.0
var crit_chance: float = 0.05
var crit_multiplier: float = 2.0
var move_speed: float = 230.0
var pickup_radius: float = 75.0
var regen: float = 0.0
var poison_dps: float = 0.0
var bleed_dps: float = 0.0
var status_duration: float = 4.0
var poison_crit: float = 0.0
var spread_radius: float = 0.0
var pierce_max_hits: int = 1
var pierce_retention: float = 0.70
var burst_count: int = 1
var spread_arrow_count: int = 1
var split_damage: float = 0.0
var bleed_regen: float = 0.0
var arrow_damage: float = 15.0
var arrow_rate: float = 1.8
var arrow_speed: float = 650.0
var arrow_range: float = 520.0
var arrow_width: float = 7.0
var knockback: float = 45.0
var poison_duration: float = 4.0
var bleed_duration: float = 4.0
var spread_max_targets: int = 3
var bleed_regen_buff: float = 0.0
var ranks: Dictionary = {}

func apply_ranks(new_ranks: Dictionary) -> void:
	var catalog := UpgradeCatalog.new()
	ranks = new_ranks.duplicate()
	# Rebuild from immutable defaults; repeated rank changes cannot compound.
	arrow_damage = 15.0
	arrow_rate = 1.8
	arrow_speed = 650.0
	arrow_range = 520.0
	arrow_width = 7.0
	knockback = 45.0
	if character != null and character.bow != null:
		arrow_damage = character.bow.damage
		arrow_rate = character.bow.rate
		arrow_speed = character.bow.projectile_speed
		arrow_range = character.bow.projectile_range
		arrow_width = character.bow.projectile_width
		knockback = character.bow.knockback
	max_hp = (character.base_health if character != null else 100.0) + _value(catalog, "vitality")
	hp = clampf(hp, 0.0, max_hp)
	shield_capacity = int(_value(catalog, "shield"))
	shields = clampi(shields, 0, shield_capacity)
	damage_percent = _value(catalog, "damage")
	attack_speed = 1.0 + _value(catalog, "attack_speed")
	crit_chance = 0.05 + _value(catalog, "crit_chance")
	crit_multiplier = 2.0 + _value(catalog, "crit_damage")
	move_speed = (character.base_move_speed if character != null else 230.0) * (1.0 + _value(catalog, "move_speed"))
	pickup_radius = (character.base_pickup_radius if character != null else 75.0) + _value(catalog, "pickup_radius")
	regen = _value(catalog, "regen")
	poison_dps = _value(catalog, "poison")
	bleed_dps = _value(catalog, "bleed")
	poison_crit = _value(catalog, "poison_crit")
	spread_radius = _value(catalog, "spread")
	pierce_max_hits = 1 + int(_value(catalog, "pierce"))
	pierce_retention = [0.70, 0.75, 0.85, 0.95][clampi(int(ranks.get("pierce", 0)), 0, 3)]
	burst_count = 1 + int(_value(catalog, "burst"))
	spread_arrow_count = 1 + int(_value(catalog, "spread_arrow"))
	bleed_regen = _value(catalog, "bleed_regen")
	bleed_regen_buff = bleed_regen
	split_damage = _value(catalog, "split")
	knockback *= 1.0 + _value(catalog, "knockback")
	arrow_range *= 1.0 + _value(catalog, "long_draw")
	arrow_speed *= 1.0 + _value(catalog, "long_draw")

func _value(catalog: UpgradeCatalog, key: String) -> float:
	return catalog.value(key, int(ranks.get(key, 0)))
