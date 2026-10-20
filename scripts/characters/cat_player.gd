class_name CatPlayer
extends Node2D

signal hit_received(amount: float)
signal died
var radius := 16.0
var stats: CombatStats
var health_state: HealthState
var arena_bounds := Rect2(60, 110, 1160, 620)
var invulnerable := false
var dash_direction := Vector2.RIGHT
var dash_left := 0.0
var dash_cooldown := 0.0
var last_move := Vector2.RIGHT
var aim_direction := Vector2.RIGHT
var regen_buff_left := 0.0
var healed_total := 0.0
var movement_enabled := true

func setup(value: CombatStats) -> void:
	stats = value
	health_state = HealthState.new(stats)

func _physics_process(delta: float) -> void:
	if stats == null: return
	var hp_before_regen := stats.hp
	health_state.tick(delta)
	healed_total += stats.hp - hp_before_regen
	dash_left = maxf(0.0, dash_left - delta)
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	regen_buff_left = maxf(0.0, regen_buff_left - delta)
	var movement := Vector2.ZERO
	if movement_enabled:
		movement = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if movement.length_squared() > 0.0: last_move = movement
	if movement_enabled and Input.is_action_just_pressed("dash") and dash_cooldown <= 0.0:
		dash_direction = last_move
		dash_left = 0.2
		dash_cooldown = 2.0
	var velocity := dash_direction * 760.0 if dash_left > 0.0 else movement * stats.move_speed
	position += velocity * delta
	position = position.clamp(arena_bounds.position + Vector2(18,18), arena_bounds.end - Vector2(18,18))
	var before := stats.hp
	var extra_regen: float = stats.bleed_regen if regen_buff_left > 0.0 else 0.0
	stats.hp = minf(stats.max_hp, stats.hp + extra_regen * delta)
	healed_total += stats.hp - before
	queue_redraw()

func receive_hit(amount: float) -> void:
	if invulnerable or dash_left > 0.0: return
	var result := health_state.receive_hit(amount)
	if bool(result.get("accepted", result.get("hit", false))):
		hit_received.emit(amount)
	if stats.hp <= 0.0: died.emit()

func _draw() -> void:
	draw_circle(Vector2(0,17), 21, Color(0.01,0.02,0.04,0.5))
	if dash_left > 0.0:
		draw_line(-dash_direction*46, -dash_direction*18, Color(0.4,1,0.85,0.7), 15, true)
	var fur := Color("ffd57e")
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
	if dash_cooldown > 0:
		draw_arc(Vector2.ZERO,34,-PI/2,-PI/2+TAU*(1-dash_cooldown/2),24,Color("72efc7"),2,true)
