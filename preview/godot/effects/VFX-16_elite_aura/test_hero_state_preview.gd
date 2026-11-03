extends SceneTree
const Demo := preload("hero_state_preview.gd")
func _initialize() -> void:call_deferred("run")
func button(demo: Node, title: String) -> Button:
	for child in demo.get_children():
		if child is Button and child.text == title:return child
	return null
func run() -> void:
	var demo := Demo.new();root.add_child(demo);demo.set_process(false)
	var commands: Array=demo.geometry()
	assert(commands.size()==2 and commands[0].kind=="circle" and commands[1].kind=="line", "ghosts use body + detached facing marker only")
	assert(commands[0].center==Vector2.ZERO and commands[0].radius==17.0, "body geometry stays unchanged")
	for fps in [30,60,144]:
		demo.reset()
		demo.dash.configure({"interval":.01,"minimum_distance":0.0,"lifetime":1.0,"max_images":24})
		while demo.elapsed<.68:demo._process(1.0/fps)
		assert(not demo.dash.enabled and demo.runner.position==Vector2(230,148), "dash stops after final actual movement")
		var last: Dictionary=demo.dash.snapshots.back()
		assert(is_equal_approx(last.born,.18), "final in-dash capture must not be discarded at end boundary")
		assert(last.transform.origin.is_equal_approx(demo.runner.global_position), "last capture includes the authoritative endpoint")
		for snapshot in demo.dash.snapshots:
			assert(snapshot.geometry.size()==2 and float(snapshot.born)<=.180001, "no eyes or post-dash captures")
		var count_before: int=demo.dash.snapshots.size()
		demo._process(.05)
		assert(demo.dash.snapshots.size()==count_before and demo.dash.snapshots.back().born==last.born, "tail ages without adding stationary ghosts")
		demo.dash.configure()
	demo.reset()
	for i in range(36):demo._process(1.0/60)
	assert(demo.dash.enabled and demo.state.war_active)
	button(demo,"Pause").pressed.emit()
	assert(demo.paused and demo.dash.paused and demo.state.paused)
	var elapsed: float=demo.elapsed;var point: Vector2=demo.runner.position
	demo._process(1)
	assert(demo.elapsed==elapsed and demo.runner.position==point)
	button(demo,"Pause").pressed.emit()
	assert(not demo.paused)
	button(demo,"Clear").pressed.emit()
	assert(demo.paused and demo.dash.snapshots.is_empty() and not demo.state.aura.active)
	var count:=demo.get_child_count()
	for i in range(50):
		button(demo,"Replay").pressed.emit()
		assert(not demo.paused and demo.elapsed==0 and not demo.revived)
		for j in range(156):demo._process(1.0/60)
		assert(demo.revived and not demo.state.war_active and demo.state.return_effect.active)
		assert(demo.get_child_count()==count)
		button(demo,"Clear").pressed.emit()
		assert(not demo.state.return_effect.active)
	print("HERO STATE PREVIEW PASS: body/facing-only snapshots; 30/60/144Hz final-segment-before-stop boundary; Pause/resume, Clear, Replay and 50 repeated flows")
	demo.free();quit()
