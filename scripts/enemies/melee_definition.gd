class_name MeleeDefinition
extends Resource
## Per-archetype tuning, multiplied by the run's shared baseline health/damage.
@export var health_multiplier: float = 1.0
@export var damage_multiplier: float = 1.0
@export var move_speed: float = 64.0
@export var mass: float = 1.0
@export var radius: float = 16.0
@export var body_color: Color = Color("9869ba")
@export var elite: bool = false

func validated_copy() -> MeleeDefinition:
	var copy := duplicate(true) as MeleeDefinition
	DefinitionValidation.nonnegative_floats(copy, MeleeDefinition.new())
	copy.health_multiplier = maxf(0.01, copy.health_multiplier)
	copy.mass = maxf(0.01, copy.mass)
	copy.radius = maxf(1.0, copy.radius)
	return copy
