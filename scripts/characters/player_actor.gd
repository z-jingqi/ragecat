class_name PlayerActor
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
var practice_panel_navigation := false
var _last_joypad_device := -1
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
		movement = _movement_input()
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


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		_last_joypad_device = event.device

func _movement_input() -> Vector2:
	# Live practice reserves the D-pad for controls, while the left stick and
	# WASD continue gameplay. Outside that panel, ordinary D-pad movement remains.
	if practice_panel_navigation:
		var dpad_held := false
		var stick := Vector2.ZERO
		var devices := Input.get_connected_joypads()
		if _last_joypad_device >= 0 and not devices.has(_last_joypad_device): devices.append(_last_joypad_device)
		for device in devices:
			for button in [JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN]:
				dpad_held = dpad_held or Input.is_joy_button_pressed(device, button)
			var current := Vector2(Input.get_joy_axis(device, JOY_AXIS_LEFT_X), Input.get_joy_axis(device, JOY_AXIS_LEFT_Y))
			if current.length_squared() > stick.length_squared(): stick = current
		if dpad_held:
			var keyboard := Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
			if stick.length() <= 0.2: stick = Vector2.ZERO
			else: stick = stick.normalized() * minf(1.0, (stick.length() - 0.2) / 0.8)
			return (keyboard + stick).limit_length()
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")
