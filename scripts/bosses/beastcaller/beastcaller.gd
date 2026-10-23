class_name Beastcaller
extends BossActor
signal shot_requested(at: Vector2, direction: Vector2, settings: SpitterDefinition)
var state := "recovery"
var phase_time := 0.8
var summon_cooldown := 0.0
var projectile_cooldown := 0.0
var summon_positions: Array[Vector2] = []
var shot_direction := Vector2.RIGHT
var retreating := false

func _init() -> void:
	boss_identity = "beastcaller"
	boss_definition = preload("res://resources/bosses/beastcaller.tres")
	radius = 32.0
	mass = 10.0
	tint = Color("9b83d6")

func _ready() -> void:
	super._ready()
	phase_time = boss_definition.initial_recovery

func _physics_process(delta: float) -> void:
	if not is_finite(delta) or delta < 0.0: return
	super._physics_process(delta)
	if transition_remaining > 0.0: return
	if not ai_enabled or is_dead or not is_instance_valid(target): return
	summon_cooldown = maxf(0.0, summon_cooldown - delta)
	projectile_cooldown = maxf(0.0, projectile_cooldown - delta)
	phase_time -= delta
	if phase_time <= 0.0:
		match state:
			"recovery":
				if not update_phase_at_boundary(): return
				var selected := choose_ability("summon", "projectile", summon_cooldown <= 0.0, projectile_cooldown <= 0.0)
				if selected == "summon":
					if not _start_summon(): summon_cooldown = boss_definition.recovery
				elif selected == "projectile": _start_projectile()
			"summon":
				if commit_summons.is_valid(): commit_summons.call(self)
				summon_positions.clear()
				summon_cooldown = current_phase().summon_cooldown
				state = "recovery"
				phase_time = boss_definition.after_summon_delay
			"projectile":
				for angle in current_phase().projectile_angles:
					shot_requested.emit(global_position, shot_direction.rotated(deg_to_rad(angle)), boss_definition.projectile)
				projectile_cooldown = boss_definition.projectile_cooldown
				state = "recovery"
				phase_time = boss_definition.recovery
	queue_redraw()

func _move_ai(delta: float) -> void:
	if transition_remaining > 0.0 or state != "recovery" or not is_instance_valid(target): return
	var distance := position.distance_to(target.position)
	if distance < boss_definition.retreat_start: retreating = true
	elif distance >= boss_definition.retreat_end: retreating = false
	if not retreating: return
	var direction := target.position.direction_to(position)
	if direction.is_zero_approx(): direction = Vector2.RIGHT
	var safe := arena_bounds.grow(-radius)
	var next := position + direction * boss_definition.retreat_speed * delta
	# Slide along a boundary rather than becoming stuck in an invalid retreat ray.
	if not safe.has_point(next):
		var tangent := direction.orthogonal()
		var a := (position + tangent * boss_definition.retreat_speed * delta).clamp(safe.position, safe.end)
		var b := (position - tangent * boss_definition.retreat_speed * delta).clamp(safe.position, safe.end)
		next = a if a.distance_squared_to(target.position) > b.distance_squared_to(target.position) else b
	position = next.clamp(safe.position, safe.end)

func _start_projectile() -> void:
	shot_direction = global_position.direction_to(target.global_position)
	if shot_direction.is_zero_approx(): shot_direction = Vector2.RIGHT
	state = "projectile"
	phase_time = boss_definition.projectile_warning

func _start_summon() -> bool:
	summon_positions = _summon_candidates()
	if summon_positions.is_empty(): return false
	if not reserve_summons.is_valid() or not bool(reserve_summons.call(summon_positions, self)):
		summon_positions.clear()
		return false
	state = "summon"
	phase_time = current_phase().summon_warning
	return true

func _summon_candidates() -> Array[Vector2]:
	var result: Array[Vector2] = []
	var phase := current_phase()
	var count := clampi(phase.summon_count, 0, 128)
	var safe := arena_bounds.grow(-boss_definition.summon_body_radius)
	if safe.size.x <= 0.0 or safe.size.y <= 0.0: return result
	if phase.summon_ring:
		for i in range(count):
			var at := target.global_position + Vector2.from_angle(TAU * i / maxi(1, count)) * boss_definition.summon_ring_radius
			if safe.has_point(at): result.append(at)
		return result
	for attempt in range(boss_definition.summon_attempts):
		var center := Vector2(choice_rng.randf_range(safe.position.x, safe.end.x), choice_rng.randf_range(safe.position.y, safe.end.y))
		if center.distance_to(target.global_position) < boss_definition.summon_clearance + boss_definition.summon_cluster_radius: continue
		result.clear()
		for i in range(count):
			var at := center + Vector2.from_angle(TAU * i / maxi(1, count)) * boss_definition.summon_cluster_radius
			if safe.has_point(at): result.append(at)
		if result.size() == count: return result
	return []

func reset_state() -> void:
	super.reset_state()
	summon_positions.clear()
	state = "recovery"
	phase_time = boss_definition.initial_recovery
	summon_cooldown = 0.0
	projectile_cooldown = 0.0
	retreating = false

func _draw() -> void:
	draw_ellipse_shadow()
	_draw_status_rings()
	var body := _status_body_color()
	draw_circle(Vector2.ZERO, radius, body)
	for i in range(3):
		var center := Vector2((i - 1) * 19, -17)
		draw_circle(center, 13, body.lightened(0.1))
		draw_circle(center + Vector2(0, -2), 4, Color("fff0a3"))
	draw_arc(Vector2.ZERO, radius + 7, age, age + TAU * 0.8, 32, Color("d8a5ff"), 3)
	if state == "summon":
		for at in summon_positions:
			var local := to_local(at)
			draw_circle(local, boss_definition.summon_body_radius + 5, Color(0.65,0.3,1,0.2))
			draw_arc(local, boss_definition.summon_body_radius + 5, 0, TAU, 32, Color("e9a7ff"), 2)
	if state == "projectile":
		for angle in current_phase().projectile_angles:
			var direction := shot_direction.rotated(deg_to_rad(angle))
			draw_line(direction * radius, direction * (radius + 100), Color("ffe7aa"), 3)
	draw_rect(Rect2(-42,-52,84,6),Color("242037"))
	draw_rect(Rect2(-42,-52,84*health/maxf(1,max_health),6),Color("c994ff"))
