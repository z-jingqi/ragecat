class_name BowPoseAdapter
extends Node
## Read-only bridge. The owner supplies a visual clock, actor and bow.
## No rendering, projectile creation, random calls or combat writes are permitted.
var clock: RefCounted
var posture: RefCounted
var actor: Node2D
var weapon: Node
var _practice_owner: Node
var _shot_interval := 0.55
var _pending := false
var fired_this_tick := false

func _ready() -> void:
	process_physics_priority = 10

func bind(new_actor: Node2D, new_weapon: Node, new_clock: RefCounted, practice_owner: Node = null, new_posture: RefCounted = null) -> void:
	_unbind()
	actor = new_actor
	weapon = new_weapon
	clock = new_clock
	posture = new_posture
	_practice_owner = practice_owner
	if is_instance_valid(weapon): weapon.volley_launched.connect(_on_launch)
	if is_instance_valid(_practice_owner) and _practice_owner.has_signal("practice_restarted"):
		_practice_owner.practice_restarted.connect(reset_pose)
	reset_pose()

func _unbind() -> void:
	if is_instance_valid(weapon) and weapon.volley_launched.is_connected(_on_launch):
		weapon.volley_launched.disconnect(_on_launch)
	if is_instance_valid(_practice_owner) and _practice_owner.has_signal("practice_restarted"):
		if _practice_owner.practice_restarted.is_connected(reset_pose):
			_practice_owner.practice_restarted.disconnect(reset_pose)

func _exit_tree() -> void:
	_unbind()

func reset_pose() -> void:
	_pending = false
	fired_this_tick = false
	if posture != null: posture.reset()
	if clock != null and is_instance_valid(actor): clock.reset(actor.position)

func _on_launch(_gravity: bool) -> void:
	# Ordinary launch is signaled before the bow updates aim and attack clocks.
	_pending = true

func _physics_process(delta: float) -> void:
	fired_this_tick = false
	if clock == null or not is_instance_valid(actor) or not is_instance_valid(weapon): return
	var stats = actor.stats
	if stats == null: return
	var gravity: bool = stats.gravity_mode()
	var gravity_live: bool = gravity and is_instance_valid(weapon.active_gravity_arrow)
	var next_shot := INF
	if gravity:
		if not gravity_live: next_shot = maxf(0.0, weapon.gravity_gap_remaining)
	else:
		next_shot = maxf(0.0, weapon.burst_clock if weapon.burst_remaining > 0 else weapon.attack_clock)
	var fired := _pending
	fired_this_tick = fired
	if _pending:
		if gravity:
			_shot_interval = maxf(0.001, stats.gravity_gap)
		else:
			# The final burst may be followed by a nearly-ready normal volley.
			# Fit this visual cycle to the actual post-weapon gate, not base rate.
			_shot_interval = maxf(0.001, next_shot)
		clock.notify_release()
		_pending = false
	var has_target: bool = weapon.nearest_enemy() != null and not gravity_live
	var projectile_budget_ready: bool = gravity or weapon.active_count(false) + stats.spread_arrow_count <= stats.primary_projectile_limit
	var enabled: bool = projectile_budget_ready and weapon.enabled and stats.hp > 0.0 and stats.arrow_rate > 0.0 and stats.attack_speed > 0.0
	var legal_step: float = maxf(stats.move_speed, stats.dash_speed) * maxf(delta, 0.0) + 0.01
	var visual_aim: Vector2 = actor.aim_direction
	if not has_target and not fired and clock.pose not in ["release", "recover"]:
		var actual_step: Vector2 = clock.displacement_to(actor.position)
		if actual_step.length_squared() > 0.0001:
			visual_aim = actual_step.normalized()
		else:
			visual_aim = Vector2.from_angle(float(clock.direction_index) * TAU / 8.0)
	clock.tick(delta, actor.position, visual_aim, actor.dash_left > 0.0,
		legal_step, next_shot, _shot_interval, has_target, enabled)
	if posture != null:
		posture.tick(delta, has_target, enabled, fired, _shot_interval, clock.pose, clock.pose_phase)
