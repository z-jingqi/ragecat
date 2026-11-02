extends SceneTree
const DemoScene = preload("res://effects/VFX-03_projectile/projectile.tscn")
var failures := 0
var checks := 0
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
func _init() -> void:
	call_deferred("run")
func run() -> void:
	var demo = DemoScene.instantiate()
	root.add_child(demo)
	demo.set_process(false)
	await process_frame
	demo.simulate(0.1)
	demo.toggle_pause()
	var old_age: float = demo.bolt.age
	var old_position: Vector2 = demo.bolt.world_position
	demo._process(0.1)
	check(demo.bolt.age == old_age and demo.bolt.world_position == old_position, "UI pause freezes movement and energy")
	demo.step_frame()
	check(demo.paused and absf(demo.bolt.age - old_age - 1.0/60.0) < 0.00001, "UI step advances exactly one frame and stays paused")
	demo.reset_all()
	check(not demo.paused and demo.loop and not demo.tracking and not demo.turning and demo.speed == 180.0, "UI reset restores preview inputs")
	check(demo.bolt.head_radius == 4.5 and demo.bolt.history.size() == 1, "UI reset restores preset and history")
	demo.apply_preset(2)
	check(demo.bolt.head_radius == 3.0 and demo.bolt.tail_max == 21.0, "named small preset changes actual state")
	demo.apply_preset(1)
	check(demo.bolt.core_color == Color("fff5d6") and demo.bolt.head_radius == 4.5, "palette preset resets previous shape override")
	demo.sliders.speed.value = 320.0
	check(demo.speed == 320.0, "speed slider wired to true demo movement")
	demo.sliders.tail_min.value = 30.0
	demo.sliders.tail_max.value = 0.0
	check(demo.bolt.tail_max == 30.0 and demo.sliders.tail_max.value == 30.0, "cross-bound slider shows actual clamped value")
	demo.reset_all()
	demo.simulate(0.1)
	demo.teleport()
	check(demo.bolt.teleport_count == 1 and demo.bolt.history.size() == 1, "UI teleport clears history")
	demo.reset_all()
	demo.turning = true
	var heading_before: float = demo.heading
	demo.simulate(0.1)
	check(absf(demo.heading - heading_before) <= 0.160001, "demo angular speed bounded")
	demo.stopped = true
	demo.bolt.stop()
	for i in range(60): demo.simulate(1.0/60.0)
	check(not demo.bolt.active, "UI stop cannot be restarted by loop")
	demo.restart()
	check(demo.bolt.active and not demo.stopped, "UI replay exits stopped state")
	print("VFX-03 demo wiring: %d checks; %d failures" % [checks, failures])
	demo.queue_free()
	quit(1 if failures else 0)
