class_name BowController
extends Node
## Equipped weapon: owns targeting, cadence, burst scheduling and projectile creation.
## Damage and effect resolution are deliberately delegated through arrow_hit.
signal arrow_hit(arrow: CatArrow, enemy: EnemyActor)

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
	if attack_clock <= 0.0:
		if nearest_enemy() != null:
			shoot()
			burst_remaining = stats.burst_count - 1
			burst_clock = 0.12
			attack_clock = 1.0 / (stats.arrow_rate * stats.attack_speed)
	if burst_remaining > 0 and burst_clock <= 0:
		shoot()
		burst_remaining -= 1
		burst_clock = 0.12

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

func _relay_arrow_hit(arrow: CatArrow, enemy: EnemyActor) -> void:
	arrow_hit.emit(arrow, enemy)
