class_name BowController
extends Node
## Equipped weapon: owns targeting, cadence, burst scheduling and projectile creation.
## Damage and effect resolution are deliberately delegated through arrow_hit.
signal arrow_hit(arrow: BowArrow, enemy: EnemyActor)
signal volley_launched(gravity: bool)

# Compatibility aliases for existing callers/tests. Live budgets come from stats.
static var PRIMARY_LIMIT: int = (preload("res://resources/bow.tres") as BowDefinition).primary_projectile_limit

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
	# A ready weapon waits for a target; waiting time is never stored as shot debt.
	var was_cooling := attack_clock > 0.0
	attack_clock = maxf(attack_clock, 0.0) - delta
	burst_clock -= delta
	# Finish the existing volley first, preserving fractional-frame residuals.
	while burst_remaining > 0 and burst_clock <= 0.0:
		shoot()
		burst_remaining -= 1
		burst_clock += maxf(stats.burst_spacing, 0.0)
	if stats.arrow_rate <= 0.0 or stats.attack_speed <= 0.0:
		attack_clock = maxf(attack_clock, 0.0)
		return
	if attack_clock <= 0.0 and burst_remaining == 0:
		if nearest_enemy() == null:
			attack_clock = 0.0
			return
		shoot()
		burst_remaining = stats.burst_count - 1
		burst_clock = maxf(stats.burst_spacing, 0.0)
		var interval := 1.0 / (stats.arrow_rate * stats.attack_speed)
		# Preserve normal sub-tick cadence, not a stalled frame or idle backlog.
		# In particular, never leave a zero clock after a long wait: that used
		# to fire an unupgraded second arrow on the very next physics tick.
		var physics_step := 1.0 / float(Engine.physics_ticks_per_second)
		var residual := clampf(-attack_clock, 0.0, minf(delta, physics_step)) if was_cooling else 0.0
		attack_clock = maxf(interval - residual, 0.0)

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
		arrow.visual_element = stats.active_element
		arrows.add_child(arrow)

func active_count(secondary: bool) -> int:
	var count := 0
	for node in arrows.get_children():
		if node is BowArrow and not node.is_queued_for_deletion() and node.secondary == secondary:
			count += 1
	return count

func _relay_arrow_hit(arrow: BowArrow, enemy: EnemyActor) -> void:
	# Impact resolves damage only; projectile patterns are emitted at firing time.
	arrow_hit.emit(arrow, enemy)

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
	arrow.visual_element = stats.active_element
	active_gravity_arrow = arrow
	arrows.add_child(arrow)
	for target: EnemyActor in enemies.get_children(): field.attach_enemy(target)
	volley_launched.emit(true)
