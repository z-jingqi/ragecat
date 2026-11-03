extends SceneTree
const Demo := preload("hero_state_preview.gd")
func _initialize() -> void:call_deferred("run")
func button(demo: Node, title: String) -> Button:
	for child in demo.get_children():
		if child is Button and child.text == title:return child
	return null
func run() -> void:
	var demo := Demo.new();root.add_child(demo);demo.set_process(false)
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
	print("HERO STATE PREVIEW PASS: Pause/resume, Clear, Replay and 50 repeated flows with no node growth")
	demo.free();quit()
