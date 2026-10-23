class_name EnemyBullet
extends Node2D
## Swept contact prevents tunneling. Contact consumes the shot even if damage is blocked.
var definition: SpitterDefinition
var target: Archer
var direction := Vector2.RIGHT
var traveled: float = 0.0
var ai_enabled: bool = true
var consumed: bool = false
## Empty bounds retain standalone projectile behavior; arena shots stop at walls.
var arena_bounds: Rect2 = Rect2()
var previous_target_position: Vector2 = Vector2.ZERO

func setup(at: Vector2, heading: Vector2, settings: SpitterDefinition, player: Archer) -> void:
	position = at
	direction = heading.normalized()
	definition = settings.validated_copy()
	target = player
	previous_target_position = player.position

func _physics_process(delta: float) -> void:
	if consumed or not ai_enabled or not is_finite(delta) or delta <= 0.0: return
	if not is_instance_valid(target) or target.stats.hp <= 0.0:
		consume()
		return
	var distance := minf(definition.bullet_speed * maxf(delta, 0.0), maxf(0.0, definition.bullet_range - traveled))
	var wall_distance := INF
	if arena_bounds.has_area():
		var safe := arena_bounds.grow(-definition.bullet_radius)
		if not safe.has_point(position):
			consume()
			return
		if direction.x > 0.0: wall_distance = minf(wall_distance, (safe.end.x - position.x) / direction.x)
		elif direction.x < 0.0: wall_distance = minf(wall_distance, (safe.position.x - position.x) / direction.x)
		if direction.y > 0.0: wall_distance = minf(wall_distance, (safe.end.y - position.y) / direction.y)
		elif direction.y < 0.0: wall_distance = minf(wall_distance, (safe.position.y - position.y) / direction.y)
		distance = minf(distance, maxf(0.0, wall_distance))
	var next := position + direction * distance
	# Relative sweep catches a moving player crossing between frame endpoints.
	# A range/wall cutoff exists only for the corresponding fraction of this step.
	var fraction := clampf(distance / maxf(0.000001, definition.bullet_speed * delta), 0.0, 1.0)
	var target_at_end := previous_target_position.lerp(target.position, fraction)
	var relative_start := previous_target_position - position
	var relative_end := target_at_end - next
	var closest := Geometry2D.get_closest_point_to_segment(Vector2.ZERO, relative_start, relative_end)
	if closest.length() <= target.radius + definition.bullet_radius:
		target.receive_hit(definition.bullet_damage)
		consume()
		return
	previous_target_position = target.position
	position = next
	traveled += distance
	if traveled >= definition.bullet_range or distance >= wall_distance: consume()
	queue_redraw()

func consume() -> void:
	consumed = true
	queue_free()

func _draw() -> void:
	if definition != null:
		draw_circle(Vector2.ZERO, definition.bullet_radius + 3.0, Color(definition.bullet_color, 0.2))
		draw_circle(Vector2.ZERO, definition.bullet_radius, definition.bullet_color)
