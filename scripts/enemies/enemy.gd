class_name EnemyActor
extends Node2D

signal killed(enemy: EnemyActor)
signal damaged(amount: float, crit: bool, pos: Vector2)

var status: StatusEffects = StatusEffects.new()
var is_dummy: bool = false
var show_health_bar: bool = true

@export var max_health: float = 44.0:
	set(value):
		var was_full := is_equal_approx(health, max_health)
		max_health = maxf(1.0, value) if is_finite(value) else 44.0
		health = max_health if was_full else minf(health, max_health)
var health: float = 44.0
@export_range(0.01, 200, 0.01) var radius: float = 16.0:
	set(value): radius = maxf(0.01, value) if is_finite(value) else 16.0
@export_range(0, 2000, 1) var speed: float = 64.0:
	set(value): speed = maxf(0.0, value) if is_finite(value) else 64.0
@export_range(0, 1000, 1) var default_knockback_force: float = 26.0
var target: Node2D
@export var arena_bounds: Rect2 = Rect2(80, 80, 1120, 560)
var ai_enabled: bool = true
var is_dead: bool = false
var variant: int = 0
var slow_multiplier: float = 1.0
var stun_remaining: float = 0.0
var flash_remaining: float = 0.0
var age: float = 0.0
@export_range(0.0, 2.0, 0.01) var hit_flash_duration: float = 0.11
@export var tint: Color = Color('#ac89ff')

func _physics_process(delta: float) -> void:
	age += delta
	flash_remaining = maxf(0.0, flash_remaining - delta)
	if ai_enabled and not is_dead:
		stun_remaining = maxf(0.0, stun_remaining - delta)
		if not is_dummy and is_instance_valid(target) and stun_remaining <= 0.0:
			_move_ai(delta)
	if not is_dead:
		status.tick(delta)
	queue_redraw()

func _move_ai(delta: float) -> void:
	position += position.direction_to(target.position) * speed * slow_multiplier * status.movement_time(delta)
	_clamp_to_arena()

func knockback(direction: Vector2, force: float = -1.0) -> void:
	if not is_dummy:
		position += direction.normalized() * (default_knockback_force if force < 0.0 else force)
		_clamp_to_arena()

func _clamp_to_arena() -> void:
	var inset := Vector2.ONE * radius
	inset = inset.min(arena_bounds.size * 0.5)
	position = position.clamp(arena_bounds.position + inset, arena_bounds.end - inset)

func receive_damage(amount: float, crit: bool = false) -> void:
	if is_dead or amount <= 0.0:
		return
	var dealt := minf(health, amount)
	health = maxf(0.0, health - dealt)
	flash_remaining = hit_flash_duration
	damaged.emit(dealt, crit, global_position)
	if health <= 0.0:
		is_dead = true
		killed.emit(self)
		queue_free()

func health_bar_visible() -> bool:
	return show_health_bar

func _draw() -> void:
	var body_color: Color = _status_body_color()
	var bob: float = 0.0 if status.is_frozen() else sin(age * 7.0) * 2.0
	draw_ellipse_shadow()
	_draw_status_rings()
	if variant % 2 == 0:
		var wing: float = 0.0 if status.is_frozen() else sin(age * 12.0) * 6.0
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
	if health_bar_visible():
		draw_rect(Rect2(-18, -29, 36, 4), Color('#171b2b'))
		draw_rect(Rect2(-18, -29, 36 * health / max_health, 4), Color('#fd7e94'))
	if stun_remaining > 0.0:
		draw_arc(Vector2(0, -23), 10, age * 4.0, age * 4.0 + 4.0, 12, Color('#ffe396'), 2)

func draw_ellipse_shadow() -> void:
	draw_set_transform(Vector2(0, radius * 0.7), 0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, radius * 1.1, Color(0.02, 0.03, 0.07, 0.35))
	draw_set_transform(Vector2.ZERO)

func _status_body_color() -> Color:
	if flash_remaining > 0.0:
		return Color.WHITE
	if status.is_frozen():
		return tint.lerp(Color('#c7f6ff'), 0.8)
	if status.chill_remaining > 0.0:
		return tint.lerp(Color('#81d8ff'), 0.35)
	return tint

func _draw_status_rings() -> void:
	if status.is_frozen():
		var crystal := PackedVector2Array()
		for i: int in range(6):
			crystal.append(Vector2.from_angle(float(i) * TAU / 6.0 - PI * 0.5) * (radius + 8.0))
		draw_colored_polygon(crystal, Color(0.45, 0.85, 1.0, 0.18))
		crystal.append(crystal[0])
		draw_polyline(crystal, Color('#c7f6ff'), 2.0)
	elif status.chill_remaining > 0.0:
		draw_arc(Vector2.ZERO, radius + 4.0, age, age + TAU * 0.85, 28, Color('#81d8ff'), 2.0)
	for i: int in range(status.frost_stacks):
		var offset := Vector2((float(i) - float(status.frost_stacks - 1) * 0.5) * 7.0, radius + 10.0)
		draw_circle(offset, 2.5, Color('#c7f6ff'))
