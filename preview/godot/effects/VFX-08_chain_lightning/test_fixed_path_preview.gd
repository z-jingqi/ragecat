extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, text: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(text)
func run() -> void:
	var demo: Node2D = load("res://effects/VFX-08_chain_lightning/fixed_path_preview.tscn").instantiate()
	root.add_child(demo)
	demo.set_process(false)
	check(demo.fx.duration == 0.18 and demo.fx.links.size() == 5, "default demo matches180ms path")
	demo.toggle_pause()
	demo.fx.advance(1)
	check(demo.fx.age == 0 and demo.fx.paused and demo.paused, "pause freezes source")
	demo.step()
	check(is_equal_approx(demo.fx.age, 1.0 / 60) and demo.fx.paused, "single step while paused")
	demo.trigger()
	check(demo.fx.age == 0 and demo.fx.paused, "replay retains preview pause")
	demo.toggle_speed()
	check(demo.fx.duration == 0.72 and demo.slow and demo.fx.paused, "slow review isolated from pause")
	demo.reset_all()
	check(demo.fx.duration == 0.18 and not demo.paused and not demo.fx.paused and demo.seed == 31, "reset restores baseline")
	demo.fx.reset()
	demo.step()
	check(not demo.fx.done and demo.fx.paused and is_equal_approx(demo.fx.age, 1.0 / 60), "frame after clear replays cleanly")
	for i in range(30):
		demo.trigger()
		demo.toggle_speed()
		demo.reset_all()
		check(demo.fx.get_child_count() == 5, "repeated controls do not leak children")
	demo.free()
	print("FIXED_PATH_PREVIEW_PASSED ", checks, " failures=", failures)
	quit(1 if failures else 0)
