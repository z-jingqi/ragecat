class_name DarkVortex
extends Node2D
## Separate bounded field, not a projectile. It never deals damage or emits procs.
var radius: float = 80.0
var remaining: float = 0.6
var pull_speed: float = 120.0
var color := Color("ba8bff")
var enemies: Node2D
var age: float = 0.0
func _physics_process(delta: float) -> void:
	var elapsed := minf(maxf(0, delta), remaining)
	remaining = maxf(0, remaining - delta)
	age += elapsed
	if is_instance_valid(enemies):
		for node in enemies.get_children():
			var enemy := node as EnemyActor
			if enemy == null or enemy is BossActor or enemy.is_dummy or enemy.is_dead: continue
			if enemy.position.distance_squared_to(position) > radius * radius: continue
			enemy.position = enemy.position.move_toward(position, pull_speed * elapsed)
			enemy._clamp_to_arena()
	queue_redraw()
	if remaining <= 0: queue_free()
func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color(color, 0.1))
	for i in range(3):
		var ring := radius * (0.3 + 0.3 * i)
		draw_arc(Vector2.ZERO, ring, age * 4 + i, age * 4 + i + PI * 1.5, 32, color, 2, true)
	draw_circle(Vector2.ZERO, 7, color.darkened(0.7))
