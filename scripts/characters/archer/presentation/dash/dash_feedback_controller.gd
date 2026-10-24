class_name ArcherDashFeedbackController
extends Node
var actor: PlayerActor
var view: ArcherLayeredPoseView
var settings: ArcherDashFeedbackDefinition
var owner_arena: Node
var marker: ArcherDashReadyMarker
var _previous_left := 0.0
var _age := 0.0
var _next_ghost := 0
var _spawned: Array[Node] = []
func configure(who: PlayerActor, pose_view: ArcherLayeredPoseView, data: ArcherDashFeedbackDefinition) -> void:
	actor = who
	view = pose_view
	settings = data
	process_physics_priority = 30
	marker = ArcherDashReadyMarker.new()
	marker.name = "DashReadyMarker"
	marker.actor = actor
	marker.settings = settings
	actor.add_child(marker)
	marker.update_state()
func reset() -> void:
	_previous_left = 0.0
	_age = 0.0
	_next_ghost = 0
	for item in _spawned:
		if is_instance_valid(item): item.queue_free()
	_spawned.clear()
	if is_instance_valid(marker): marker.update_state()
func _exit_tree() -> void:
	reset()
	if is_instance_valid(marker): marker.queue_free()
func _physics_process(delta: float) -> void:
	if is_instance_valid(marker):
		marker.settings = settings
		marker.update_state()
	if not is_instance_valid(actor) or settings == null or not settings.enabled: return
	var left := actor.dash_left
	var began := left > _previous_left + 0.0001
	if began:
		_age = 0.0
		_next_ghost = 0
		_emit_dust()
	if left > 0.0:
		_age += maxf(delta, 0.0)
		while _next_ghost < settings.afterimage_times.size() and _age >= settings.afterimage_times[_next_ghost]:
			_emit_afterimage()
			_next_ghost += 1
	_previous_left = left
	_spawned = _spawned.filter(func(item): return is_instance_valid(item))
func _container() -> Node:
	if not is_instance_valid(owner_arena): return null
	var result = owner_arena.get("effects")
	return result as Node
func _emit_afterimage() -> void:
	var container := _container()
	if container == null or view == null or not view.has_pose(): return
	var ghost := ArcherDashAfterimage.new()
	container.add_child(ghost)
	ghost.capture(view, settings)
	ghost.z_index = actor.z_index - 1 - (container.z_index if container is CanvasItem else 0)
	_spawned.append(ghost)
func _emit_dust() -> void:
	var container := _container()
	if container == null or settings.dust_count <= 0: return
	var dust := ArcherDashDust.new()
	dust.settings = settings
	dust.direction = actor.dash_direction.normalized()
	container.add_child(dust)
	dust.global_position = actor.global_position + settings.foot_offset
	dust.z_index = actor.z_index - 1 - (container.z_index if container is CanvasItem else 0)
	_spawned.append(dust)
