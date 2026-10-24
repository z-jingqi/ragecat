class_name EnemyOccupancyDefinition
extends Resource
## Ground occupancy only. Hurtboxes, damage and force tuning are independent.
@export var enabled: bool = true
@export_range(1, 8, 1) var maximum_slides: int = 4
@export_range(0.001, 0.2, 0.001) var safe_margin: float = 0.03
@export_range(32, 1024, 1) var spawn_search_distance: float = 512.0
@export_range(64, 8192, 1) var spawn_search_attempts: int = 4096
@export_range(0.01, 2, 0.01) var certification_tolerance: float = 1.0
@export_range(1, 4000, 1) var charge_clearance_speed: float = 2400.0
@export_range(1, 100, 1) var charge_clearance_cap: float = 48.0
@export_range(16, 1024, 1) var charge_work_limit: int = 256
@export_range(1, 32, 1) var charge_chain_depth: int = 32

func validated_copy() -> EnemyOccupancyDefinition:
	var copy := duplicate(true) as EnemyOccupancyDefinition
	DefinitionValidation.nonnegative_floats(copy, EnemyOccupancyDefinition.new())
	copy.maximum_slides = clampi(copy.maximum_slides, 1, 8)
	copy.safe_margin = clampf(copy.safe_margin, 0.001, 0.2)
	copy.spawn_search_distance = clampf(copy.spawn_search_distance, 32.0, 1024.0)
	copy.spawn_search_attempts = clampi(copy.spawn_search_attempts, 64, 8192)
	copy.certification_tolerance = clampf(copy.certification_tolerance, 0.01, 2.0)
	copy.charge_clearance_speed = clampf(copy.charge_clearance_speed, 1.0, 4000.0)
	copy.charge_clearance_cap = clampf(copy.charge_clearance_cap, 1.0, 100.0)
	copy.charge_work_limit = clampi(copy.charge_work_limit, 16, 1024)
	copy.charge_chain_depth = clampi(copy.charge_chain_depth, 1, 32)
	return copy
