class_name BowController
extends Node
## Equipped weapon: owns targeting, cadence, burst scheduling and projectile creation.
## Damage and effect resolution are deliberately delegated through arrow_hit.
signal arrow_hit(arrow: BowArrow, enemy: EnemyActor)
signal volley_launched(gravity: bool)

# Independent budgets: fragments can never crowd out the normal bow volley.
# Compatibility aliases for existing callers/tests. Live budgets come from stats.
static var PRIMARY_LIMIT: int = (preload("res://resources/bow.tres") as BowDefinition).primary_projectile_limit
static var FRAGMENT_LIMIT: int = (preload("res://resources/bow.tres") as BowDefinition).fragment_projectile_limit

var player: PlayerActor
var stats: CombatStats
var enemies: Node2D
var arrows: Node2D
var bounds: Rect2
var enabled: bool = true
var attack_clock: float = 0.0
var burst_remaining: int = 0
var burst_clock: float = 0.0
var active_gravity_arrow: BowArrow
var gravity_gap_remaining := 0.0
var gravity_gap_started_frame: int = -1
var gravity_damage_callback: Callable

func _ready() -> void:
	process_physics_priority = -30

func remove_gravity(reset_gate: bool = false) -> void:
	if is_instance_valid(active_gravity_arrow): active_gravity_arrow.retire(reset_gate)
	active_gravity_arrow = null
	if reset_gate:
		gravity_gap_remaining = 0.0
		gravity_gap_started_frame = -1

func _gravity_removed(_arrow: BowArrow) -> void:
	active_gravity_arrow = null
	gravity_gap_remaining = maxf(gravity_gap_remaining, _arrow.get_meta("post_gap", 0.5))
	gravity_gap_started_frame = Engine.get_physics_frames()


func setup(owner_player: PlayerActor, combat_stats: CombatStats, enemy_container: Node2D, projectile_container: Node2D, arena_bounds: Rect2) -> void:
	player = owner_player
	stats = combat_stats
	enemies = enemy_container
	arrows = projectile_container
	bounds = arena_bounds

func _physics_process(delta: float) -> void:
	if not enabled or not is_instance_valid(player) or stats == null or stats.hp <= 0.0:
		return
	if gravity_gap_started_frame != Engine.get_physics_frames():
		gravity_gap_remaining = maxf(0.0, gravity_gap_remaining - delta)
	if stats.gravity_mode():
		burst_remaining = 0
		burst_clock = 0.0
		if not is_instance_valid(active_gravity_arrow) and gravity_gap_remaining <= 0.0: shoot()
		return
	attack_clock -= delta
	burst_clock -= delta
	# Finish the existing volley first, preserving fractional-frame residuals.
	while burst_remaining > 0 and burst_clock <= 0.0:
		shoot()
		burst_remaining -= 1
		burst_clock += maxf(stats.burst_spacing, 0.0)
	if stats.arrow_rate <= 0.0 or stats.attack_speed <= 0.0: return
	if attack_clock <= 0.0 and burst_remaining == 0 and nearest_enemy() != null:
		shoot()
		burst_remaining = stats.burst_count - 1
		burst_clock = maxf(stats.burst_spacing, 0.0)
		var interval := 1.0 / (stats.arrow_rate * stats.attack_speed)
		# A stalled frame does not accumulate unbounded catch-up volleys.
		attack_clock = maxf(attack_clock + interval, 0.0)

func nearest_enemy() -> EnemyActor:
	var nearest: EnemyActor = null
	var best := stats.arrow_range * stats.arrow_range
	for node in enemies.get_children():
		var enemy := node as EnemyActor
		if enemy == null or enemy.health <= 0: continue
		var distance := player.position.distance_squared_to(enemy.position)
		if distance < best:
			best = distance
			nearest = enemy
	return nearest

func shoot() -> void:
	var enemy := nearest_enemy()
	if enemy == null: return
	if stats.gravity_mode():
		if is_instance_valid(active_gravity_arrow) or gravity_gap_remaining > 0.0: return
		_spawn_gravity_arrow(enemy)
		return
	# Skip a whole fan rather than emitting an asymmetric partial fan at cap.
	if active_count(false) + stats.spread_arrow_count > stats.primary_projectile_limit: return
	volley_launched.emit(false)
	var direction := player.position.direction_to(enemy.position)
	player.aim_direction = direction
	for i in range(stats.spread_arrow_count):
		var arrow := CombatSceneFactory.arrow(stats.character.bow.projectile_scene)
		arrow.direction = direction.rotated((float(i)-float(stats.spread_arrow_count-1)/2.0)*stats.fan_spread_angle)
		arrow.position = player.position + arrow.direction*stats.arrow_spawn_offset
		arrow.speed = stats.arrow_speed
		arrow.max_range = stats.arrow_range
		arrow.width = stats.arrow_width * stats.arrow_collision_width_scale
		arrow.max_hits = 1 if stats.fire_mode() else stats.pierce_max_hits
		arrow.decay = stats.pierce_retention
		# Only an actual centered arrow carries full damage, including even fans.
		arrow.damage_scale = 1.0 if float(i) == float(stats.spread_arrow_count-1)/2.0 else stats.side_arrow_damage
		arrow.enemies = enemies
		arrow.arena_bounds = bounds
		arrow.enemy_hit.connect(_relay_arrow_hit)
		arrows.add_child(arrow)

func active_count(secondary: bool) -> int:
	var count := 0
	for node in arrows.get_children():
		if node is BowArrow and not node.is_queued_for_deletion() and node.secondary == secondary:
			count += 1
	return count

func _relay_arrow_hit(arrow: BowArrow, enemy: EnemyActor) -> void:
	# Capture collision geometry before damage/knockback callbacks mutate targets.
	if arrow.gravity_field == null and not arrow.secondary and not arrow.split_used and stats.split_damage > 0.0:
		arrow.split_used = true
		_spawn_fragments(arrow, enemy.get_instance_id())
	arrow_hit.emit(arrow, enemy)

func _spawn_fragments(source: BowArrow, ignored_id: int) -> void:
	if source.impact_traveled >= source.max_range: return
	if active_count(true) + stats.split_angles.size() > stats.fragment_projectile_limit: return
	for angle: float in stats.split_angles:
		var fragment := CombatSceneFactory.arrow(stats.character.bow.projectile_scene)
		fragment.secondary = true
		fragment.direction = source.direction.rotated(angle)
		fragment.position = source.impact_position
		fragment.speed = source.speed
		fragment.width = source.width
		fragment.max_range = source.max_range
		fragment.traveled = source.impact_traveled
		fragment.max_hits = 1
		fragment.damage_scale = source.damage_scale * stats.split_damage
		fragment.ignored_ids[ignored_id] = true
		fragment.enemies = enemies
		fragment.arena_bounds = bounds
		fragment.enemy_hit.connect(_relay_arrow_hit)
		arrows.add_child(fragment)


func _spawn_gravity_arrow(enemy: EnemyActor) -> void:
	var arrow := CombatSceneFactory.arrow(stats.character.bow.projectile_scene)
	arrow.process_physics_priority = -20
	arrow.direction = player.position.direction_to(enemy.position)
	if arrow.direction.is_zero_approx(): arrow.direction = Vector2.RIGHT
	player.aim_direction = arrow.direction
	arrow.rotation = arrow.direction.angle()
	arrow.position = player.position + arrow.direction * stats.arrow_spawn_offset
	arrow.speed = stats.arrow_speed
	arrow.max_range = stats.arrow_range
	arrow.width = stats.arrow_width * stats.arrow_collision_width_scale
	arrow.unlimited_direct_hits = true
	arrow.decay = 1.0
	arrow.lifetime_remaining = stats.element_skill.gravity.lifetime
	arrow.enemies = enemies
	arrow.arena_bounds = bounds
	arrow.set_meta("post_gap", stats.gravity_gap)
	arrow.enemy_hit.connect(_relay_arrow_hit)
	arrow.removed.connect(_gravity_removed)
	var field := GravityField.new()
	field.configure(stats, enemies, gravity_damage_callback)
	field.position = Vector2(stats.element_skill.gravity.tip_offset, 0)
	arrow.gravity_field = field
	arrow.add_child(field)
	active_gravity_arrow = arrow
	arrows.add_child(arrow)
	for target: EnemyActor in enemies.get_children(): field.attach_enemy(target)
	volley_launched.emit(true)
