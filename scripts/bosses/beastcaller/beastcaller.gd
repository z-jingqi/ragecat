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
var approaching := false

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
	if distance < boss_definition.retreat_start:
		retreating = true
		approaching = false
	elif distance >= boss_definition.retreat_end: retreating = false
	if distance > boss_definition.ranged_approach_start:
		approaching = true
		retreating = false
	elif distance <= boss_definition.ranged_approach_end:
		approaching = false
	if approaching:
		var step := minf(boss_definition.retreat_speed * slow_multiplier * movement_time(delta), maxf(0.0, distance - boss_definition.ranged_approach_end))
		position = (position + position.direction_to(target.position) * step).clamp(arena_bounds.position + Vector2.ONE * radius, arena_bounds.end - Vector2.ONE * radius)
		return
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
	if not reserve_summons.is_valid(): return false
	var phase := current_phase()
	var attempts := boss_definition.summon_ring_rotation_attempts if phase.summon_ring else boss_definition.summon_attempts
	var reserved := false
	for attempt in range(attempts):
		var angle := TAU * float(attempt) / float(maxi(1, phase.summon_count) * attempts) if phase.summon_ring else 0.0
		summon_positions = _summon_candidates(angle, 1)
		if summon_positions.is_empty(): continue
		if bool(reserve_summons.call(summon_positions, self)):
			reserved = true
			break
	if not reserved:
		summon_positions.clear()
		return false
	state = "summon"
	phase_time = current_phase().summon_warning
	return true

func _summon_candidates(angle_offset: float = 0.0, cluster_attempts: int = -1) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var phase := current_phase()
	var count := clampi(phase.summon_count, 0, 128)
	var safe := arena_bounds.grow(-boss_definition.summon_body_radius)
	if safe.size.x <= 0.0 or safe.size.y <= 0.0: return result
	if phase.summon_ring:
		for i in range(count):
			var at := target.global_position + Vector2.from_angle(TAU * i / maxi(1, count) + angle_offset) * boss_definition.summon_ring_radius
			if safe.has_point(at): result.append(at)
		return result
	for attempt in range(boss_definition.summon_attempts if cluster_attempts < 0 else cluster_attempts):
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
	approaching = false

func _draw() -> void:
	draw_ellipse_shadow()
	_draw_status_rings()
	var body := _status_body_color()
	draw_circle(Vector2.ZERO, radius, body)
	for i in range(3):
		var center := Vector2((i - 1) * 19, -17)
		draw_circle(center, 13, body.lightened(0.1))
		draw_circle(center + Vector2(0, -2), 4, Color("fff0a3"))
	if state == "summon":
		for at in summon_positions:
			var local := to_local(at)
			var visual_radius := boss_definition.summon_body_radius * VfxAtlasRenderer.setting(&"summon_size_factor")
			VfxAtlasRenderer.draw_clip(self, &"summon", 1.0 - phase_time / maxf(0.001, current_phase().summon_warning), Rect2(local - Vector2.ONE * visual_radius, Vector2.ONE * visual_radius * 2.0), Color.WHITE, true, true)
			# Always-readable emergence hints survive exhausted decoration budgets.
			# Summoning is not a circular area-damage attack, so no false AOE ring.
			var gather := clampf(1.0 - phase_time / maxf(0.001, current_phase().summon_warning), 0.0, 1.0)
			var body_radius := boss_definition.summon_body_radius
			for side in [-1.0, 1.0]:
				var foot := local + Vector2(side * body_radius * 0.65, body_radius * 0.15)
				var tip := local + Vector2(side * body_radius * 0.2, -body_radius * (0.25 + gather * 0.7))
				draw_line(foot, tip, Color(VfxAtlasRenderer.color_setting(&"summon_stream_color"), VfxAtlasRenderer.setting(&"summon_stream_opacity") * (0.5 + gather * 0.5)), VfxAtlasRenderer.setting(&"summon_stream_width"), true)
	draw_rect(Rect2(-42,-52,84,6),Color("242037"))
	draw_rect(Rect2(-42,-52,84*health/maxf(1,max_health),6),health_bar_definition.fill_color)
