class_name CatPlayer
extends Node2D

signal hit_received(amount: float)
signal hit_feedback(kind: String, amount: float)
signal died
var radius: float
var stats: CombatStats
var health_state: HealthState
@export var arena_bounds: Rect2 = Rect2(60, 110, 1160, 620)
var invulnerable := false
var dash_direction := Vector2.RIGHT
var dash_left := 0.0
var dash_cooldown := 0.0
var last_move := Vector2.RIGHT
var aim_direction := Vector2.RIGHT
var healed_total := 0.0
var movement_enabled := true
var impact_left := 0.0
var impact_kind := ""

func setup(value: CombatStats) -> void:
	stats = value
	radius = stats.collision_radius
	health_state = HealthState.new(stats)

func _physics_process(delta: float) -> void:
	if stats == null: return
	var hp_before_regen := stats.hp
	health_state.tick(delta)
	healed_total += stats.hp - hp_before_regen
	impact_left = maxf(0.0, impact_left - delta)
	dash_left = maxf(0.0, dash_left - delta)
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	var movement := Vector2.ZERO
	if movement_enabled:
		movement = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if movement.length_squared() > 0.0: last_move = movement
	if movement_enabled and Input.is_action_just_pressed("dash") and dash_cooldown <= 0.0:
		dash_direction = last_move
		dash_left = stats.dash_duration
		dash_cooldown = stats.dash_cooldown_duration
	var velocity := dash_direction * stats.dash_speed if dash_left > 0.0 else movement * stats.move_speed
	position += velocity * delta
	position = position.clamp(arena_bounds.position + Vector2.ONE * stats.arena_padding, arena_bounds.end - Vector2.ONE * stats.arena_padding)
	queue_redraw()

func heal(amount: float) -> float:
	var restored := health_state.heal(amount)
	healed_total += restored
	return restored

func receive_hit(amount: float) -> void:
	if invulnerable or (dash_left > 0.0 and stats.dash_grants_immunity): return
	var result := health_state.receive_hit(amount)
	if bool(result.get("accepted", result.get("hit", false))):
		impact_kind = ("break" if stats.shields == 0 else "block") if bool(result.shielded) else "hurt"
		impact_left = stats.hit_feedback_duration
		hit_feedback.emit(impact_kind, float(result.damage))
		hit_received.emit(amount)
		queue_redraw()
	if stats.hp <= 0.0: died.emit()

func _draw() -> void:
	draw_circle(Vector2(0,17), 21, Color(0.01,0.02,0.04,0.5))
	if dash_left > 0.0:
		draw_line(-dash_direction*46, -dash_direction*18, Color(0.4,1,0.85,0.7), 15, true)
	# A persistent dark/light rim separates the cat from overlapping boss art.
	draw_circle(Vector2(0,-4), 22, Color("111b2c"))
	draw_arc(Vector2(0,-4),22,0,TAU,40,Color("fff1c8"),1.5,true)
	var fur := Color("ffd57e")
	if impact_left > 0.0 and impact_kind == "hurt": fur = Color("ff8e98")
	draw_arc(Vector2(-14,10), 14, 1.8, 5.5, 16, fur, 6, true)
	draw_circle(Vector2(0,9), 15, Color("eaa762"))
	draw_circle(Vector2(0,-4), 19, fur)
	draw_colored_polygon(PackedVector2Array([Vector2(-18,-13),Vector2(-17,-31),Vector2(-3,-20)]), fur)
	draw_colored_polygon(PackedVector2Array([Vector2(18,-13),Vector2(17,-31),Vector2(3,-20)]), fur)
	draw_colored_polygon(PackedVector2Array([Vector2(-15,-17),Vector2(-14,-26),Vector2(-7,-20)]), Color("e99491"))
	draw_colored_polygon(PackedVector2Array([Vector2(15,-17),Vector2(14,-26),Vector2(7,-20)]), Color("e99491"))
	for side in [-1.0,1.0]:
		draw_line(Vector2(side*6,-7), Vector2(side*12,-9),Color("29313a"),3,true)
		draw_circle(Vector2(side*8,-3),2,Color("29313a"))
		draw_line(Vector2(side*12,2),Vector2(side*24,0),Color("fff1c8"),1.5,true)
		draw_line(Vector2(side*12,5),Vector2(side*24,7),Color("fff1c8"),1.5,true)
	draw_colored_polygon(PackedVector2Array([Vector2(-3,2),Vector2(3,2),Vector2(0,5)]), Color("b95b68"))
	var angle := aim_direction.angle()
	var bow := aim_direction*26
	draw_arc(bow,18,angle-1.25,angle+1.25,18,Color("8d5c43"),4,true)
	draw_line(bow+Vector2.from_angle(angle-1.25)*18,bow+Vector2.from_angle(angle+1.25)*18,Color("f7efd3"),1.5,true)
	if stats != null and stats.shields > 0:
		draw_arc(Vector2.ZERO,29,0,TAU,40,Color(0.35,0.8,1,0.65),2,true)
	if dash_cooldown > 0 and stats != null and stats.dash_cooldown_duration > 0:
		draw_arc(Vector2.ZERO,34,-PI/2,-PI/2+TAU*(1-dash_cooldown/stats.dash_cooldown_duration),24,Color("72efc7"),2,true)

	if impact_left > 0.0:
		var fade := impact_left / stats.hit_feedback_duration
		var impact_color := Color("ff637d") if impact_kind == "hurt" else Color("7fe5ff")
		impact_color.a = fade
		var impact_radius := 31.0 + (1.0 - fade) * 22.0
		if impact_kind == "break":
			for i in range(8):
				var direction := Vector2.from_angle(i * TAU / 8.0)
				draw_line(direction * impact_radius, direction * (impact_radius + 11.0), impact_color, 4.0, true)
		else:
			draw_arc(Vector2.ZERO,impact_radius,0,TAU,48,impact_color,4.0,true)
