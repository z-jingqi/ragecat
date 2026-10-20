class_name EnemyActor
extends Node2D

signal killed(enemy: EnemyActor)
signal damaged(amount: float, crit: bool, pos: Vector2)

var status: StatusEffects = StatusEffects.new()
var is_dummy: bool = false

var max_health: float = 44.0
var health: float = 44.0
var radius: float = 16.0
var speed: float = 64.0
var target: Node2D
var arena_bounds: Rect2 = Rect2(80, 80, 1120, 560)
var ai_enabled: bool = true
var is_dead: bool = false
var variant: int = 0
var slow_multiplier: float = 1.0
var stun_remaining: float = 0.0
var flash_remaining: float = 0.0
var age: float = 0.0
var tint: Color = Color('#ac89ff')

func _physics_process(delta: float) -> void:
	age += delta
	flash_remaining = maxf(0.0, flash_remaining - delta)
	if not is_dead:
		var tick_damage: float = status.tick(delta)
		if tick_damage > 0.0:
			receive_damage(tick_damage)
	if ai_enabled and not is_dead:
		stun_remaining = maxf(0.0, stun_remaining - delta)
		if not is_dummy and is_instance_valid(target) and stun_remaining <= 0.0:
			_move_ai(delta)
	queue_redraw()

func _move_ai(delta: float) -> void:
	position += position.direction_to(target.position) * speed * slow_multiplier * delta
	_clamp_to_arena()

func knockback(direction: Vector2, force: float = 26.0) -> void:
	if not is_dummy:
		position += direction.normalized() * force
		_clamp_to_arena()

func _clamp_to_arena() -> void:
	position.x = clampf(position.x, arena_bounds.position.x + radius, arena_bounds.end.x - radius)
	position.y = clampf(position.y, arena_bounds.position.y + radius, arena_bounds.end.y - radius)

func receive_damage(amount: float, crit: bool = false) -> void:
	if is_dead or amount <= 0.0:
		return
	health = maxf(0.0, health - amount)
	flash_remaining = 0.11
	damaged.emit(amount, crit, global_position)
	if health <= 0.0:
		is_dead = true
		killed.emit(self)
		queue_free()

func _draw() -> void:
	var body_color: Color = Color.WHITE if flash_remaining > 0.0 else tint
	var bob: float = sin(age * 7.0) * 2.0
	draw_ellipse_shadow()
	_draw_status_rings()
	if variant % 2 == 0:
		var wing: float = sin(age * 12.0) * 6.0
		draw_colored_polygon(PackedVector2Array([Vector2(-6, -5 + bob), Vector2(-27, -16 + wing), Vector2(-24, 8), Vector2(-10, 5 + bob)]), body_color.darkened(0.25))
		draw_colored_polygon(PackedVector2Array([Vector2(6, -5 + bob), Vector2(27, -16 + wing), Vector2(24, 8), Vector2(10, 5 + bob)]), body_color.darkened(0.25))
		draw_circle(Vector2(0, bob), radius * 0.78, body_color)
		draw_colored_polygon(PackedVector2Array([Vector2(-10, -6 + bob), Vector2(-8, -20 + bob), Vector2(-1, -10 + bob)]), body_color)
		draw_colored_polygon(PackedVector2Array([Vector2(10, -6 + bob), Vector2(8, -20 + bob), Vector2(1, -10 + bob)]), body_color)
	else:
		draw_circle(Vector2(0, bob), radius, body_color)
		draw_circle(Vector2(-6, -6 + bob), 5, body_color.lightened(0.25))
	for side: float in [-1.0, 1.0]:
		draw_circle(Vector2(side * 5.0, -2 + bob), 3.5, Color('#191c35'))
		draw_circle(Vector2(side * 5.0, -3 + bob), 1.2, Color('#fff2d6'))
	if health < max_health:
		draw_rect(Rect2(-18, -29, 36, 4), Color('#171b2b'))
		draw_rect(Rect2(-18, -29, 36 * health / max_health, 4), Color('#fd7e94'))
	if stun_remaining > 0.0:
		draw_arc(Vector2(0, -23), 10, age * 4.0, age * 4.0 + 4.0, 12, Color('#ffe396'), 2)

func draw_ellipse_shadow() -> void:
	draw_set_transform(Vector2(0, radius * 0.7), 0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, radius * 1.1, Color(0.02, 0.03, 0.07, 0.35))
	draw_set_transform(Vector2.ZERO)

func _draw_status_rings() -> void:
	if status.has_poison():
		draw_arc(Vector2.ZERO, radius + 4, age * 2.0, age * 2.0 + TAU * 0.85, 28, Color('#91e56f'), 2)
	if status.has_bleed():
		draw_arc(Vector2.ZERO, radius + 8, -age * 2.0, -age * 2.0 + TAU * 0.7, 28, Color('#ff6781'), 2)
