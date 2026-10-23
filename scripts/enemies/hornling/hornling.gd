class_name Hornling
extends EnemyActor
## Basic melee creature; shared combat behavior remains in EnemyActor.

var archetype: MeleeDefinition
func _ready() -> void:
	if archetype == null: archetype = preload("res://resources/enemies/hornling.tres").validated_copy()
	speed = archetype.move_speed
	radius = archetype.radius
	mass = archetype.mass
	tint = archetype.body_color
	contact_damage_multiplier = archetype.damage_multiplier
