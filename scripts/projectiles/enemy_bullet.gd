class_name EnemyBullet
extends Node2D
## Swept contact prevents tunneling. Contact consumes the shot even if damage is blocked.
var definition: SpitterDefinition
var target: Archer
var direction := Vector2.RIGHT
var traveled: float = 0.0
var ai_enabled: bool = true
var consumed: bool = false

func setup(at: Vector2, heading: Vector2, settings: SpitterDefinition, player: Archer) -> void:
	position = at
	direction = heading.normalized()
	definition = settings.validated_copy()
	target = player

func _physics_process(delta: float) -> void:
	if consumed or not ai_enabled: return
	if not is_instance_valid(target) or target.stats.hp <= 0.0:
		consume()
		return
	var distance := minf(definition.bullet_speed * maxf(delta, 0.0), maxf(0.0, definition.bullet_range - traveled))
	var next := position + direction * distance
	var closest := Geometry2D.get_closest_point_to_segment(target.position, position, next)
	if target.position.distance_to(closest) <= target.radius + definition.bullet_radius:
		target.receive_hit(definition.bullet_damage)
		consume()
		return
	position = next
	traveled += distance
	if traveled >= definition.bullet_range: consume()
	queue_redraw()

func consume() -> void:
	consumed = true
	queue_free()

func _draw() -> void:
	if definition != null:
		draw_circle(Vector2.ZERO, definition.bullet_radius + 3.0, Color(definition.bullet_color, 0.2))
		draw_circle(Vector2.ZERO, definition.bullet_radius, definition.bullet_color)
