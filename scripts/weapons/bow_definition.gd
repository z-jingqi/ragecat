class_name BowDefinition
extends Resource
## Immutable character-independent base weapon data.
@export var id: String = "starter_bow"
@export var display_name_key: String = "NAME_BOW"
var display_name: String:
	get: return GameLocale.text(display_name_key)
## Optional compatible scenes. Null keeps the built-in bow and arrow.
@export var controller_scene: PackedScene
@export var projectile_scene: PackedScene
@export var damage: float = 15.0
@export var rate: float = 1.8
@export var projectile_speed: float = 650.0
@export var projectile_range: float = 520.0
@export var projectile_width: float = 7.0
@export var knockback: float = 0.0
@export_range(0.0, 1000.0, 0.1, "or_greater") var spawn_offset: float = 28.0
@export_range(0.0, 10.0, 0.01, "or_greater") var collision_width_scale: float = 0.5
@export_range(0, 10000, 1, "or_greater") var primary_projectile_limit: int = 128

func validated_copy() -> BowDefinition:
	var copy := duplicate(true) as BowDefinition
	DefinitionValidation.nonnegative_floats(copy, BowDefinition.new())
	copy.primary_projectile_limit = maxi(0, copy.primary_projectile_limit)
	return copy
