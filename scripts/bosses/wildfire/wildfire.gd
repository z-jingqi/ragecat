class_name Wildfire
extends BossActor
var state := "recovery"
var phase_time := 0.8
var skyfire_cooldown := 0.0
var ring_cooldown := 0.0
var skyfires_remaining := 0
var rings_released := 0
var ring_release_clock := 0.0
var ring_center := Vector2.ZERO
var ground_clock := 0.0
var hazards: Array[SkyfireHazard] = []
var _ring_warning_surface: Polygon2D
var _ring_warning_material: ShaderMaterial

func _init() -> void:
	boss_identity = "wildfire"
	boss_definition = preload("res://resources/bosses/wildfire.tres")
	radius = 35.0
	mass = 10.0
	tint = Color("ed7443")

func _ready() -> void:
	super._ready()
	phase_time = boss_definition.initial_recovery
	ground_clock = boss_definition.ground_tick
	_ring_warning_surface = Polygon2D.new()
	_ring_warning_surface.show_behind_parent = true
	_ring_warning_surface.visible = false
	_ring_warning_material = ShaderMaterial.new()
	_ring_warning_material.shader = preload("res://shaders/fire_ring_surface.gdshader")
	_ring_warning_material.set_shader_parameter("arena_rect", Vector4(arena_bounds.position.x, arena_bounds.position.y, arena_bounds.size.x, arena_bounds.size.y))
	_ring_warning_surface.material = _ring_warning_material
	add_child(_ring_warning_surface)

func _physics_process(delta: float) -> void:
	if not is_finite(delta) or delta < 0.0: return
	super._physics_process(delta)
	for child in get_children():
		if child.get_meta("boss_hazard", false): child.ai_enabled = ai_enabled
	if not ai_enabled or is_dead or not is_instance_valid(target): return
	_tick_ground(delta)
	if not ai_enabled or is_dead: return
	if transition_remaining > 0.0: return
	skyfire_cooldown = maxf(0.0, skyfire_cooldown - delta)
	ring_cooldown = maxf(0.0, ring_cooldown - delta)
	phase_time -= delta
	if phase_time <= 0.0:
		match state:
			"recovery":
				if not update_phase_at_boundary(): return
				var selected := choose_ability("rings", "skyfire", ring_cooldown <= 0.0, skyfire_cooldown <= 0.0)
				if selected == "rings": _start_rings()
				elif selected == "skyfire":
					skyfires_remaining = boss_definition.skyfire_count
					_next_skyfire()
			"skyfire_wait": _next_skyfire()
			"skyfire_finish": _finish_combo()
			"ring_warning": _release_ring()
			"ring_gap":
				state = "ring_warning"
				phase_time = boss_definition.ring_warning
			"ring_finish": _finish_combo()
	queue_redraw()

func _move_ai(delta: float) -> void:
	if transition_remaining <= 0.0 and state == "recovery" and is_instance_valid(target):
		position = position.move_toward(target.position, boss_definition.approach_speed * delta)

func _next_skyfire() -> void:
	if skyfires_remaining <= 0: return
	skyfires_remaining -= 1
	var hazard := _create_skyfire(target.global_position, false)
	hazard.impact.connect(_main_impact)
	state = "skyfire_wait" if skyfires_remaining > 0 else "skyfire_finish"
	phase_time = boss_definition.skyfire_warning + (boss_definition.skyfire_delay if skyfires_remaining > 0 else boss_definition.splash_warning + boss_definition.recovery)

func _create_skyfire(at: Vector2, small: bool) -> SkyfireHazard:
	var hazard := SkyfireHazard.new()
	hazard.arena_bounds = arena_bounds
	hazard.radius = boss_definition.splash_radius if small else boss_definition.skyfire_radius
	hazard.warning = boss_definition.splash_warning if small else boss_definition.skyfire_warning
	hazard.impact_damage = boss_definition.splash_damage if small else boss_definition.skyfire_damage
	hazard.burn_duration = boss_definition.splash_ground_duration if small else boss_definition.ground_duration
	hazard.burn_damage = boss_definition.ground_damage
	hazard.splash = small
	hazard.impact.connect(_impact)
	add_child(hazard)
	hazard.global_position = at
	hazards.append(hazard)
	return hazard

func _impact(hazard: SkyfireHazard) -> void:
	if not is_dead and is_instance_valid(target) and hazard.contains(target.global_position, _player_radius()):
		attack_player.emit(hazard.impact_damage)

func _main_impact(hazard: SkyfireHazard) -> void:
	if is_dead or not ai_enabled or hazard.is_queued_for_deletion(): return
	var count := clampi(current_phase().skyfire_splashes,0,16)
	var offset := choice_rng.randf_range(0,TAU)
	var safe := arena_bounds.grow(-boss_definition.splash_radius)
	for i in range(count):
		var at := hazard.global_position + Vector2.from_angle(offset + TAU*i/maxi(1,count)) * boss_definition.splash_distance
		if safe.has_point(at): _create_skyfire(at,true)

func _tick_ground(delta: float) -> void:
	ground_clock -= delta
	var due := ground_clock <= 0.0
	if due: ground_clock = boss_definition.ground_tick
	var damage := 0.0
	for i in range(hazards.size()-1,-1,-1):
		var hazard := hazards[i]
		if not is_instance_valid(hazard) or hazard.is_queued_for_deletion():
			hazards.remove_at(i)
			continue
		# Never tick damage immediately on the impact frame.
		if due and hazard.burning() and hazard.elapsed - hazard.warning >= boss_definition.ground_tick and hazard.contains(target.global_position,_player_radius()):
			damage = maxf(damage,hazard.burn_damage)
	if damage > 0.0: attack_player.emit(damage)

func _start_rings() -> void:
	for hazard in hazards:
		if is_instance_valid(hazard):
			remove_child(hazard)
			hazard.queue_free()
	hazards.clear()
	rings_released = 0
	ring_center = global_position
	state = "ring_warning"
	phase_time = boss_definition.ring_warning

func _release_ring() -> void:
	var ring := BossFireRing.new()
	ring.arena_bounds = arena_bounds
	ring.target = target
	ring.speed = boss_definition.ring_speed
	ring.width = boss_definition.ring_width
	ring.damage = boss_definition.ring_damage
	ring.ring_radius = boss_definition.ring_initial_radius
	ring.maximum_radius = arena_bounds.size.length()
	ring.hit.connect(func(amount: float) -> void:
		if not is_dead: attack_player.emit(amount))
	add_child(ring)
	ring.global_position = ring_center
	rings_released += 1
	if rings_released <= current_phase().ring_intervals.size():
		state = "ring_gap"
		phase_time = maxf(0.0,current_phase().ring_intervals[rings_released-1] - boss_definition.ring_warning)
	else:
		state = "ring_finish"
		phase_time = ring.maximum_radius / ring.speed + boss_definition.recovery

func _finish_combo() -> void:
	if state.begins_with("skyfire"): skyfire_cooldown = boss_definition.skyfire_cooldown
	else: ring_cooldown = boss_definition.ring_cooldown
	state = "recovery"
	phase_time = boss_definition.recovery

func _player_radius() -> float:
	return float(target.get("radius")) if is_instance_valid(target) and target.get("radius") != null else 0.0

func reset_state() -> void:
	super.reset_state()
	hazards.clear()
	state = "recovery"
	phase_time = boss_definition.initial_recovery
	skyfire_cooldown = 0.0
	ring_cooldown = 0.0
	skyfires_remaining = 0
	rings_released = 0
	ground_clock = boss_definition.ground_tick
	if is_instance_valid(_ring_warning_surface): _ring_warning_surface.visible = false
	queue_redraw()

func _draw() -> void:
	_sync_ring_warning_surface()
	draw_ellipse_shadow()
	_draw_status_rings()
	var body := _status_body_color()
	for side in [-1,1]:
		draw_colored_polygon(PackedVector2Array([Vector2(0,10),Vector2(side*55,-12),Vector2(side*25,-30)]),body.darkened(.15))
	draw_circle(Vector2.ZERO,radius*.65,body)
	draw_line(Vector2(0,20),Vector2(0,40),Color("ffc670"),5)
	draw_colored_polygon(PackedVector2Array([Vector2(8,-13),Vector2(32,-7),Vector2(8,0)]),Color("ffe2a1"))
	draw_circle(Vector2(7,-14),4,Color("fff2d0"))
	draw_rect(Rect2(-42,-52,84,6),Color("242037"))
	draw_rect(Rect2(-42,-52,84*health/maxf(1,max_health),6),health_bar_definition.fill_color)

func _sync_ring_warning_surface() -> void:
	if not is_instance_valid(_ring_warning_surface): return
	_ring_warning_surface.visible = state == "ring_warning" and not is_dead
	if not _ring_warning_surface.visible: return
	# This only samples the original warning clock. It does not move the locked
	# ring center, advance the release, or alter the original expanding band.
	var warning_progress := clampf(1.0 - phase_time / maxf(.01,boss_definition.ring_warning), 0.0, 1.0)
	var extent := boss_definition.ring_initial_radius + boss_definition.ring_width * .5
	_ring_warning_surface.position = to_local(ring_center)
	_ring_warning_surface.polygon = PackedVector2Array([Vector2(-extent,-extent),Vector2(extent,-extent),Vector2(extent,extent),Vector2(-extent,extent)])
	_ring_warning_material.set_shader_parameter("ring_radius", boss_definition.ring_initial_radius)
	_ring_warning_material.set_shader_parameter("band_width", boss_definition.ring_width)
	_ring_warning_material.set_shader_parameter("phase", warning_progress * boss_definition.ring_warning)
	_ring_warning_material.set_shader_parameter("opacity", VfxAtlasRenderer.setting(&"fire_ring_surface_opacity") * (.60 + .40 * warning_progress))
