class_name CharacterDefinition
extends Resource
## Add future characters as data resources, not branches in combat rules.
@export var id: String = "cat"
@export var display_name: String = "Rage Cat"
@export var base_health: float = 100.0
@export var base_move_speed: float = 230.0
@export var base_pickup_radius: float = 75.0
@export_range(0.0, 100.0, 0.1, "or_greater") var collision_radius: float = 16.0
@export_range(0.0, 100.0, 0.1, "or_greater") var arena_padding: float = 18.0
@export_range(0.0, 5000.0, 0.1, "or_greater") var dash_speed: float = 760.0
@export_range(0.0, 60.0, 0.01, "or_greater") var dash_duration: float = 0.2
@export_range(0.0, 60.0, 0.01, "or_greater") var dash_cooldown: float = 2.0
@export var dash_grants_immunity: bool = true
@export_range(0.0, 60.0, 0.01, "or_greater") var hit_feedback_duration: float = 0.45
@export var bow: BowDefinition = BowDefinition.new()
@export var combat: CombatDefinition = CombatDefinition.new()
## Empty uses the default catalog; supply all desired definitions to customize.
@export var upgrades: Array[UpgradeDefinition] = []

func create_stats() -> CombatStats:
	return CombatStats.new(self)

func validated_copy() -> CharacterDefinition:
	var copy := duplicate(true) as CharacterDefinition
	DefinitionValidation.nonnegative_floats(copy, CharacterDefinition.new())
	copy.base_health = maxf(1.0, copy.base_health)
	copy.bow = (bow if bow != null else BowDefinition.new()).validated_copy()
	copy.combat = (combat if combat != null else CombatDefinition.new()).validated_copy()
	copy.upgrades = []
	for upgrade: UpgradeDefinition in upgrades:
		if upgrade != null:
			copy.upgrades.append(upgrade.validated_copy())
	return copy
