class_name BowController
extends Node
## Equipped weapon: owns targeting, cadence, burst scheduling and projectile creation.
## Damage and effect resolution are deliberately delegated through arrow_hit.
signal arrow_hit(arrow: CatArrow, enemy: EnemyActor)

# Independent budgets: fragments can never crowd out the normal bow volley.
const PRIMARY_LIMIT: int = 128
const FRAGMENT_LIMIT: int = 128

var player: CatPlayer
var stats: CombatStats
var enemies: Node2D
var arrows: Node2D
var bounds: Rect2
var enabled: bool = true
var attack_clock: float = 0.0
var burst_remaining: int = 0
var burst_clock: float = 0.0

func setup(owner_player: CatPlayer, combat_stats: CombatStats, enemy_container: Node2D, projectile_container: Node2D, arena_bounds: Rect2) -> void:
	player = owner_player
	stats = combat_stats
	enemies = enemy_container
	arrows = projectile_container
	bounds = arena_bounds

func _physics_process(delta: float) -> void:
	if not enabled or not is_instance_valid(player) or stats == null or stats.hp <= 0.0:
		return
	attack_clock -= delta
	burst_clock -= delta
	# Finish the existing volley first, preserving fractional-frame residuals.
	while burst_remaining > 0 and burst_clock <= 0.0:
		shoot()
		burst_remaining -= 1
		burst_clock += 0.12
	if attack_clock <= 0.0 and burst_remaining == 0 and nearest_enemy() != null:
		shoot()
		burst_remaining = stats.burst_count - 1
		burst_clock = 0.12
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
	# Skip a whole fan rather than emitting an asymmetric partial fan at cap.
	if active_count(false) + stats.spread_arrow_count > PRIMARY_LIMIT: return
	var direction := player.position.direction_to(enemy.position)
	player.aim_direction = direction
	for i in range(stats.spread_arrow_count):
		var arrow := preload("res://scenes/projectiles/arrow.tscn").instantiate() as CatArrow
		arrow.direction = direction.rotated((float(i)-float(stats.spread_arrow_count-1)/2.0)*0.20)
		arrow.position = player.position + arrow.direction*28
		arrow.speed = stats.arrow_speed
		arrow.max_range = stats.arrow_range
		arrow.width = stats.arrow_width * 0.5
		arrow.max_hits = stats.pierce_max_hits
		arrow.decay = stats.pierce_retention
		# Side arrows intentionally carry 55% damage: close-range shotgun is useful, not a free triple.
		arrow.damage_scale = 1.0 if i == stats.spread_arrow_count/2 else 0.55
		arrow.enemies = enemies
		arrow.arena_bounds = bounds
		arrow.enemy_hit.connect(_relay_arrow_hit)
		arrows.add_child(arrow)

func active_count(secondary: bool) -> int:
	var count := 0
	for node in arrows.get_children():
		if node is CatArrow and not node.is_queued_for_deletion() and node.secondary == secondary:
			count += 1
	return count

func _relay_arrow_hit(arrow: CatArrow, enemy: EnemyActor) -> void:
	# Capture collision geometry before damage/knockback callbacks mutate targets.
	if not arrow.secondary and not arrow.split_used and stats.split_damage > 0.0:
		arrow.split_used = true
		_spawn_fragments(arrow, enemy.get_instance_id())
	arrow_hit.emit(arrow, enemy)

func _spawn_fragments(source: CatArrow, ignored_id: int) -> void:
	if source.impact_traveled >= source.max_range: return
	if active_count(true) + 2 > FRAGMENT_LIMIT: return
	for angle: float in [-PI / 6.0, PI / 6.0]:
		var fragment := preload("res://scenes/projectiles/arrow.tscn").instantiate() as CatArrow
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

