extends RefCounted
## AudioServer releases stopped playback references on its mixing thread. Fast
## headless tests must let that thread drain before process exit, not suppress
## engine errors or disable playback during the assertions.
static func drain(tree: SceneTree) -> void:
	_stop(tree.root)
	# A death/pause menu may leave the tree paused at test completion. Resume
	# only after stopping voices so the mixer can retire paused playback handles.
	tree.paused = false
	await tree.create_timer(0.5, true, false, true).timeout

static func _stop(node: Node) -> void:
	if node is FeedbackAudio: node.set_enabled(false)
	for child in node.get_children(): _stop(child)
