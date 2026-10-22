class_name RangedEnemy
extends EnemyActor
## Never pursues: idle outside the retreat band, move directly away inside it.
signal shot_requested(origin: Vector2, direction: Vector2, definition: RangedDefinition)
@export var definition: RangedDefinition = preload("res://resources/settings/ranged.tres")
var retreating: bool = false
var warning_remaining: float = 0.0
var shot_cooldown: float = 0.0
var locked_direction := Vector2.RIGHT
var shot_pending: bool = false

func _ready() -> void:
	if definition == null: definition = RangedDefinition.new()
	definition = definition.validated_copy()
	speed = definition.move_speed
	mass = definition.mass
	radius = definition.radius
	tint = definition.body_color
	shot_cooldown = definition.shot_interval

func _move_ai(delta: float) -> void:
	var distance := position.distance_to(target.position)
	if distance < definition.retreat_start:
		retreating = true
	elif distance >= definition.retreat_end:
		retreating = false
	if retreating:
		var away := target.position.direction_to(position)
		if away.is_zero_approx(): away = Vector2.RIGHT
		# Stop exactly at the outer band; clamping only removes outward travel.
		_ai_displacement = away * minf(speed * slow_multiplier * status.movement_time(delta), maxf(0.0, definition.retreat_end - distance))
	# Ice stops translation only: cooldowns, warnings and locked shots continue.
	if shot_pending:
		warning_remaining = maxf(0.0, warning_remaining - delta)
		if warning_remaining <= 0.0:
			shot_pending = false
			shot_requested.emit(position, locked_direction, definition)
			shot_cooldown = maxf(0.0, definition.shot_interval - definition.telegraph_duration)
	else:
		shot_cooldown = maxf(0.0, shot_cooldown - delta)
		if shot_cooldown <= 0.0 and distance <= definition.shoot_range:
			locked_direction = position.direction_to(target.position)
			if locked_direction.is_zero_approx(): locked_direction = Vector2.RIGHT
			warning_remaining = definition.telegraph_duration
			shot_pending = true

func receive_damage(amount: float, crit: bool = false) -> void:
	super.receive_damage(amount, crit)
	if is_dead:
		shot_pending = false
		warning_remaining = 0.0

func _draw() -> void:
	draw_ellipse_shadow()
	_draw_status_rings()
	var color := _status_body_color()
	# Angular cyan sentry contrasts with the purple winged melee silhouette.
	draw_colored_polygon(PackedVector2Array([Vector2(0,-radius*1.4),Vector2(radius,0),Vector2(0,radius),Vector2(-radius,0)]), color)
	draw_circle(Vector2.ZERO, radius * 0.35, Color("192d3e"))
	if shot_pending:
		draw_line(Vector2.ZERO, locked_direction * definition.shoot_range, Color(definition.warning_color, 0.3), 2.0)
		draw_arc(Vector2.ZERO, radius + 5.0, 0, TAU, 32, definition.warning_color, 2.0)
	if health_bar_visible():
		draw_rect(Rect2(-18,-30,36,4),Color("172333"))
		draw_rect(Rect2(-18,-30,36 * health/max_health,4),color)
