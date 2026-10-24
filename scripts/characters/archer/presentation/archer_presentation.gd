class_name ArcherPresentation
extends Node2D
## Cosmetic consumer of movement and real weapon events. Never emits gameplay events.
var actor: PlayerActor
var appearance: ArcherAppearanceDefinition
var clock: ArcherPoseClock
var posture: BowPostureClock
var selector: ArcherPoseClipSelector
var adapter: BowPoseAdapter
var view: ArcherLayeredPoseView
var _practice_owner: Node
var _feedback: ArcherFeedbackOverlay
var _dash_feedback: ArcherDashFeedbackController
var _dash_was_active := false
var _dash_recovery_age := INF
var _dash_guard := false
var _dash_clip: StringName
var _dash_guard_clip: StringName
var _dash_move_recovery := false
var _dash_move_distance := 0.0
var _dash_last_position := Vector2.ZERO

func configure(who: PlayerActor, definition: ArcherAppearanceDefinition) -> void:
	actor = who
	appearance = definition
	clock = appearance.create_pose_clock()
	posture = appearance.create_posture_clock()
	selector = appearance.create_selector()
	adapter = BowPoseAdapter.new()
	add_child(adapter)
	view = ArcherLayeredPoseView.new()
	add_child(view)
	view.configure(appearance)
	_feedback = ArcherFeedbackOverlay.new()
	_feedback.actor = actor
	_feedback.visible = false
	add_child(_feedback)
	_dash_feedback = ArcherDashFeedbackController.new()
	add_child(_dash_feedback)
	_dash_feedback.configure(actor, view, appearance.dash_feedback)
	process_physics_priority = 20

func bind_weapon(weapon: Node, practice_owner: Node) -> void:
	if is_instance_valid(_practice_owner) and _practice_owner.has_signal("practice_restarted"):
		if _practice_owner.practice_restarted.is_connected(reset_pose):
			_practice_owner.practice_restarted.disconnect(reset_pose)
	_practice_owner = practice_owner
	_dash_feedback.owner_arena = practice_owner
	adapter.bind(actor, weapon, clock, practice_owner, posture)
	if is_instance_valid(practice_owner) and practice_owner.has_signal("practice_restarted"):
		practice_owner.practice_restarted.connect(reset_pose)
	reset_pose()

func reset_pose() -> void:
	_dash_was_active = false
	_dash_recovery_age = INF
	_dash_guard = false
	_dash_move_recovery = false
	_dash_move_distance = 0.0
	_dash_last_position = actor.position if is_instance_valid(actor) else Vector2.ZERO
	if _dash_feedback != null: _dash_feedback.reset()
	selector.reset()
	position = Vector2.ZERO
	if view != null:
		view.clear_pose()
		if clock.direction_index < appearance.direction_names.size():
			var direction: String = appearance.direction_names[clock.direction_index]
			selector.direction_prefix = StringName(direction)
			var idle := StringName(direction + "/idle")
			view.show_pose(StringName(direction + "/carry"), 0.0, idle, 0.0, false, appearance.idle_bobs.get(idle, Vector2.ZERO))
	if view != null and is_instance_valid(actor):
		view.self_modulate = Color("ff8e98") if actor.impact_left > 0.0 and actor.impact_kind == "hurt" else Color.WHITE
	if _feedback != null: _feedback.visible = has_visible_pose()
	if is_instance_valid(actor): actor.queue_redraw()

func _physics_process(delta: float) -> void:
	if adapter == null or not is_instance_valid(adapter.weapon): return
	if appearance.direction_names.size() <= clock.direction_index:
		view.clear_pose()
		_feedback.visible = false
		actor.queue_redraw()
		return
	var direction: String = appearance.direction_names[clock.direction_index]
	selector.direction_prefix = StringName(direction)
	var selected := selector.tick(delta, clock, posture, adapter.fired_this_tick)
	var lower_clip := StringName(direction + "/idle")
	var lower_phase := 0.0
	var bob: Vector2 = appearance.idle_bobs.get(lower_clip, Vector2.ZERO)
	if clock.moving and clock.locomotion_index < appearance.movement_clips.size():
		lower_clip = StringName(direction + "/" + appearance.movement_clips[clock.locomotion_index])
		lower_phase = clock.gait_phase
		var bobs: PackedVector2Array = appearance.gait_bobs.get(lower_clip, PackedVector2Array())
		if not bobs.is_empty():
			var sample := lower_phase * bobs.size()
			var index := int(floor(sample)) % bobs.size()
			bob = bobs[index].lerp(bobs[(index + 1) % bobs.size()], sample - floor(sample))
	if not _show_dash_pose(delta, selected):
		# A dash may reconnect the visual stride to its matching planted foot.
		if clock.moving and not is_equal_approx(lower_phase, clock.gait_phase):
			lower_phase = clock.gait_phase
			var entry_bobs: PackedVector2Array = appearance.gait_bobs.get(lower_clip, PackedVector2Array())
			if not entry_bobs.is_empty():
				var entry_sample := lower_phase * entry_bobs.size()
				var entry_index := int(floor(entry_sample)) % entry_bobs.size()
				bob = entry_bobs[entry_index].lerp(entry_bobs[(entry_index + 1) % entry_bobs.size()], entry_sample - floor(entry_sample))
		_feedback.visible = view.show_pose(selected.clip, selected.phase, lower_clip, lower_phase, clock.moving, bob)
	view.self_modulate = Color("ff8e98") if actor.impact_left > 0.0 and actor.impact_kind == "hurt" else Color.WHITE
	if adapter.fired_this_tick: _handoff_new_arrows(delta)

func _show_dash_pose(delta: float, selected: Dictionary) -> bool:
	var movement := actor.position.distance_to(_dash_last_position)
	_dash_last_position = actor.position
	var motion := appearance.dash_motion
	if motion == null or motion.normalized_times.is_empty(): return false
	var active := actor.dash_left > 0.0
	if active and not _dash_was_active:
		_dash_recovery_age = INF
		_dash_move_recovery = false
		_dash_move_distance = 0.0
		_dash_guard = posture.height < motion.guard_height_threshold and not adapter.fired_this_tick
	if adapter.fired_this_tick or posture.height > motion.guard_height_threshold:
		# An actual launch always wins over a non-firing guard visual.
		_dash_guard = false
	var direction: String = appearance.direction_names[clock.direction_index]
	var travel_index := posmod(int(round(actor.dash_direction.angle() / (TAU / 8.0))), 8)
	var relative_index := posmod(travel_index - clock.direction_index, 8)
	_dash_clip = StringName(direction + "/dash_" + str(relative_index))
	_dash_guard_clip = StringName(direction + "/guard")
	var move_clip := StringName(direction + "/guard_move")
	var duration := maxf(actor.stats.dash_duration, 0.001)
	var recovery_ratio := maxf(0.0, motion.normalized_times[-1] - 1.0)
	var recovery_distance: float = motion.guard_move_distances.get(move_clip, 0.0)
	if _dash_was_active and not active:
		_dash_recovery_age = 0.0
		_dash_move_recovery = _dash_guard and clock.moving and recovery_distance > 0.0
		if clock.moving and not _dash_guard:
			clock.gait_phase = motion.gait_entry_phases.get(_dash_clip, clock.gait_phase)
			_dash_recovery_age = INF
	_dash_was_active = active
	if not active and _dash_move_recovery:
		_dash_move_distance += movement
		var progress := clampf(_dash_move_distance / maxf(recovery_distance, 0.001), 0.0, 1.0)
		if not _dash_guard:
			# New target/release interrupts only visuals, never the firing event.
			clock.gait_phase = lerpf(motion.gait_entry_phases.get(_dash_clip, clock.gait_phase), motion.guard_move_exit_phases.get(move_clip, clock.gait_phase), progress)
			_dash_move_recovery = false
			_dash_recovery_age = INF
		elif not clock.moving:
			# A released movement input must not leave distance-driven recovery stuck.
			_dash_move_recovery = false
			_dash_recovery_age = duration * recovery_ratio * progress
		elif progress >= 1.0:
			clock.gait_phase = motion.guard_move_exit_phases.get(move_clip, clock.gait_phase)
			_dash_move_recovery = false
			_dash_recovery_age = INF
		else:
			var move_phase := motion.sample_phase(1.0 + progress * recovery_ratio)
			var move_shown := view.show_single_pose(motion.guard, move_clip, move_phase, motion.bob_for(move_clip, move_phase))
			if move_shown: _feedback.visible = true
			return move_shown
	if not active:
		_dash_recovery_age += maxf(delta, 0.0)
		if _dash_recovery_age > duration * recovery_ratio: return false
	var time := (duration - actor.dash_left) / duration if active else 1.0 + _dash_recovery_age / duration
	var phase := motion.sample_phase(time)
	var shown := false
	if _dash_guard and relative_index == 0:
		shown = view.show_single_pose(motion.guard, _dash_guard_clip, phase, motion.bob_for(_dash_guard_clip, phase))
	else:
		shown = view.show_pose(selected.clip, selected.phase, _dash_clip, phase, false, motion.bob_for(_dash_clip, phase), motion.body)
	if shown: _feedback.visible = true
	return shown

func has_visible_pose() -> bool:
	return view != null and view.has_pose()

func _handoff_new_arrows(delta: float) -> void:
	if not has_visible_pose(): return
	if clock.direction_index >= appearance.muzzle_positions.size(): return
	var muzzle := actor.position + view.position + appearance.muzzle_positions[clock.direction_index]
	if not muzzle.is_finite(): return
	for node in adapter.weapon.arrows.get_children():
		var arrow := node as BowArrow
		if arrow == null or arrow.secondary or arrow.retired or arrow.gravity_field != null: continue
		if arrow.presentation_spawn_frame != Engine.get_physics_frames(): continue
		if arrow.traveled > arrow.speed * maxf(delta, 0.0) + 0.001: continue
		if arrow.presentation_blend_distance > 0.0 or arrow.speed <= 0.0: continue
		var blend := minf(clampf(appearance.muzzle_handoff_distance, 0.0, 24.0), arrow.speed * clampf(appearance.muzzle_handoff_max_duration, 0.0, 0.05))
		if blend <= 0.0 or arrow.max_range <= blend: continue
		var near_hit := false
		for candidate in adapter.weapon.enemies.get_children():
			var enemy := candidate as EnemyActor
			if enemy != null and not enemy.is_dead and enemy.health > 0.0:
				if enemy.position.distance_to(arrow.position) <= enemy.radius + blend + maxf(0.0, appearance.muzzle_near_hit_clearance):
					near_hit = true
					break
		if near_hit: continue
		var axis := arrow.direction.normalized()
		if axis.is_zero_approx(): continue
		var start := arrow.position - axis * arrow.traveled
		var correction := muzzle - start
		# Axial mismatch is already covered by the visible shaft length.
		correction -= axis * correction.dot(axis)
		arrow.presentation_origin_offset = correction.limit_length(clampf(appearance.muzzle_handoff_limit, 0.0, 8.0))
		arrow.presentation_blend_distance = blend
		arrow.queue_redraw()
