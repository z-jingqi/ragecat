class_name BossDefinition
extends Resource
@export var health_multiplier: float = 1.0
@export var mass_multiplier: float = 1.0
@export var body_radius: float = 34.0
@export var body_color: Color = Color("e88b64")
@export var phase_one: BossPhaseDefinition = BossPhaseDefinition.new()
@export var phase_two: BossPhaseDefinition = BossPhaseDefinition.new()
@export_range(0.01, 1.0) var phase_threshold: float = 0.5
@export var transition_duration: float = 1.0
@export var initial_recovery: float = 0.8
@export var recovery: float = 1.0
@export var near_distance: float = 220.0
@export var far_distance: float = 600.0
@export var near_first_weight: float = 0.6
@export var far_first_weight: float = 0.3
@export var repeat_weight: float = 0.7
@export_group("Summoner")
@export var retreat_start: float = 320.0
@export var retreat_end: float = 420.0
@export var retreat_speed: float = 140.0
@export var summon_ring_radius: float = 260.0
@export var summon_cluster_radius: float = 35.0
@export var summon_clearance: float = 180.0
@export var summon_attempts: int = 24
@export var summon_body_radius: float = 20.0
@export var elite_live_cap: int = 16
@export var after_summon_delay: float = 0.8
@export var projectile_warning: float = 0.6
@export var projectile_cooldown: float = 3.0
@export var projectile: SpitterDefinition = SpitterDefinition.new()
@export_group("Skyfire")
@export var approach_speed: float = 28.0
@export var skyfire_count: int = 2
@export var skyfire_delay: float = 0.8
@export var skyfire_warning: float = 1.2
@export var skyfire_radius: float = 120.0
@export var skyfire_damage: float = 14.0
@export var ground_duration: float = 3.0
@export var ground_tick: float = 0.5
@export var ground_damage: float = 4.0
@export var skyfire_cooldown: float = 8.0
@export var splash_warning: float = 0.8
@export var splash_radius: float = 45.0
@export var splash_damage: float = 6.0
@export var splash_ground_duration: float = 2.0
@export var splash_distance: float = 190.0
@export_group("Fire rings")
@export var ring_warning: float = 1.2
@export var ring_speed: float = 180.0
@export var ring_width: float = 28.0
@export var ring_damage: float = 12.0
@export var ring_initial_radius: float = 42.0
@export var ring_cooldown: float = 9.0
@export_group("Reserved element multipliers")
@export var fire_multiplier: float = 1.0
@export var lightning_multiplier: float = 1.0
@export var ice_multiplier: float = 1.0
@export var dark_multiplier: float = 1.0

func snapshot() -> BossDefinition:
	var copy := duplicate(true) as BossDefinition
	var defaults := BossDefinition.new()
	for item in get_property_list():
		if item.type == TYPE_FLOAT:
			var value := float(copy.get(item.name))
			copy.set(item.name, maxf(0.0, value) if is_finite(value) else defaults.get(item.name))
	copy.health_multiplier = maxf(0.01,copy.health_multiplier)
	copy.mass_multiplier = maxf(0.01,copy.mass_multiplier)
	copy.body_radius = maxf(1.0,copy.body_radius)
	copy.phase_threshold = clampf(copy.phase_threshold, 0.01, 1.0)
	copy.far_distance = maxf(copy.near_distance + 1.0, copy.far_distance)
	copy.summon_attempts = clampi(copy.summon_attempts, 1, 128)
	copy.elite_live_cap = clampi(copy.elite_live_cap, 0, 128)
	copy.skyfire_count = clampi(copy.skyfire_count, 1, 16)
	copy.ground_tick = maxf(0.05, copy.ground_tick)
	copy.ring_speed = maxf(1.0, copy.ring_speed)
	if copy.phase_one == null: copy.phase_one = BossPhaseDefinition.new()
	if copy.phase_two == null: copy.phase_two = BossPhaseDefinition.new()
	copy.phase_one = copy.phase_one.snapshot()
	copy.phase_two = copy.phase_two.snapshot()
	if copy.projectile == null: copy.projectile = SpitterDefinition.new()
	copy.projectile = copy.projectile.validated_copy()
	return copy
