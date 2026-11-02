extends SceneTree
var failures := 0
var checks := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if value:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene = load("res://effects/VFX-02_weapon_trail/weapon_trail.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.reset_baseline()
	check(scene.history.count == 1 and scene.speed == 1.0, "reset gives one seed, 1x playback")
	for i in range(12):
		scene.simulate(1.0 / 60.0)
	check(scene.history.count > 2, "demo real endpoint motion emits live history")
	scene.toggle_pause()
	var frozen: float = scene.history.clock
	check(scene.paused and scene.pause_button.text == "Play", "pause state reflected by button")
	scene.step_frame()
	check(scene.paused and is_equal_approx(scene.history.clock - frozen, 1.0 / 60.0), "frame advances exactly 1/60 while paused")
	scene.sliders["speed"].value = 2.0
	check(scene.speed == 2.0, "speed control changes host motion")
	var old_direction: float = scene.direction
	scene.turn()
	check(scene.direction == -old_direction, "turn reverses host direction")
	scene.toggle_stop()
	var last_tip: Vector2 = scene.tip_world
	for i in range(40):
		scene.simulate(1.0 / 60.0)
	check(scene.tip_world == last_tip and scene.history.count == 0, "stop keeps pose still and removes all drawable segments")
	scene.teleport()
	check(scene.history.count == 1 and scene.history.teleport_resets == 1, "teleport has no bridging segment")
	scene.apply_preset("short_cool")
	check(is_equal_approx(scene.history.lifetime, 0.1) and scene.history.max_samples == 24 and scene.view.body == Color("77d7ce"), "named jade preset loads canonical runtime config")
	scene.apply_preset("soft_exit")
	check(scene.view.stepped_fade and scene.fade_check.button_pressed, "soft preset enables real stepped alpha")
	scene.sliders["samples"].value = 2
	scene.sliders["life"].value = 0.02
	scene.toggle_stop()
	for i in range(10):
		scene.simulate(1.0 / 60.0)
	check(scene.history.count <= 2, "minimum lifetime/cap live controls stay bounded")
	scene.reset_baseline()
	check(not scene.paused and not scene.stopped and is_equal_approx(scene.history.lifetime, 0.16) and scene.history.max_samples == 32 and not scene.view.stepped_fade, "reset restores all baseline state after edits")
	check(scene.labels["life"].text.contains("0.16") and scene.labels["samples"].text.contains("32"), "reset also restores displayed parameter labels")
	scene.camera_pan = true
	scene.simulate(0.05)
	check(scene.view.camera_world != Vector2.ZERO and scene.view.camera_world == scene.detail.camera_world, "world-grid camera offset consistent at both scales")
	scene.view.width_fraction = NAN
	scene.view.opacity = INF
	scene.view.pixels_per_unit = -10.0
	scene.view.sync()
	check(scene.view.width_fraction == 0.68 and scene.view.opacity == 1.0 and scene.view.pixels_per_unit == 1.0, "nonfinite visual controls recover to safe defaults")
	print("VFX02_DEMO_TESTS_PASSED ", checks, " failures=", failures)
	scene.queue_free()
	quit(0 if failures == 0 else 1)
