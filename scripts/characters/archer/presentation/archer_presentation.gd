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
	process_physics_priority = 20

func bind_weapon(weapon: Node, practice_owner: Node) -> void:
	if is_instance_valid(_practice_owner) and _practice_owner.has_signal("practice_restarted"):
		if _practice_owner.practice_restarted.is_connected(reset_pose):
			_practice_owner.practice_restarted.disconnect(reset_pose)
	_practice_owner = practice_owner
	adapter.bind(actor, weapon, clock, practice_owner, posture)
	if is_instance_valid(practice_owner) and practice_owner.has_signal("practice_restarted"):
		practice_owner.practice_restarted.connect(reset_pose)
	reset_pose()

func reset_pose() -> void:
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
	_feedback.visible = view.show_pose(selected.clip, selected.phase, lower_clip, lower_phase, clock.moving, bob)
	view.self_modulate = Color("ff8e98") if actor.impact_left > 0.0 and actor.impact_kind == "hurt" else Color.WHITE
	if adapter.fired_this_tick: _handoff_new_arrows(delta)

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
