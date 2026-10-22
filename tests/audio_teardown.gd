extends RefCounted
## Real mixer-thread fence, not simulation time. A SceneTreeTimer created after
## a blocked initial frame can consume that frame's old delta and finish at once.
const MINIMUM_DRAIN_USEC := 500000
const MAXIMUM_DRAIN_USEC := 1500000
static func drain(tree: SceneTree) -> void:
	var handles: Array[WeakRef] = []
	_capture(tree.root, handles)
	_stop(tree.root)
	tree.paused = false
	var start := Time.get_ticks_usec()
	while Time.get_ticks_usec() - start < MINIMUM_DRAIN_USEC:
		await tree.process_frame
	# When called before scene destruction, verify the actual stopped playback
	# references were released. Never retain a strong reference across the await.
	var remaining := _remaining(handles)
	while not remaining.is_empty() and Time.get_ticks_usec() - start < MAXIMUM_DRAIN_USEC:
		await tree.process_frame
		remaining = _remaining(handles)
	if not remaining.is_empty():
		push_error("Audio teardown deadline exceeded; unreclaimed: %s; mixer age: %.3fs" % [", ".join(remaining), AudioServer.get_time_since_last_mix()])

static func _capture(node: Node, handles: Array[WeakRef]) -> void:
	if node is AudioStreamPlayer and node.has_stream_playback():
		handles.append(weakref(node.get_stream_playback()))
	for child in node.get_children(): _capture(child, handles)

static func _remaining(handles: Array[WeakRef]) -> PackedStringArray:
	var result: PackedStringArray = []
	for handle in handles:
		var playback: Object = handle.get_ref()
		if playback != null: result.append("%s:%d" % [playback.get_class(), playback.get_instance_id()])
	return result

static func _stop(node: Node) -> void:
	if node is FeedbackAudio: node.set_enabled(false)
	for child in node.get_children(): _stop(child)
