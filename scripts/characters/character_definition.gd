class_name CharacterDefinition
extends Resource
## Add future characters as data resources, not branches in combat rules.
@export var id: String = "cat"
@export var display_name: String = "Rage Cat"
@export var base_health: float = 100.0
@export var base_move_speed: float = 230.0
@export var base_pickup_radius: float = 75.0
@export var bow: BowDefinition

func create_stats() -> CombatStats:
	var stats := CombatStats.new()
	stats.character = self
	stats.apply_ranks({})
	stats.hp = stats.max_hp
	return stats
