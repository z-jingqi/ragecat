extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene = load("res://preview.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	assert(scene.materials.size() == 2)
	assert(is_equal_approx(scene._duration(), 0.18))
	scene._step()
	assert(scene.paused)
	assert(is_equal_approx(scene.age, 1.0 / 60.0))
	scene._replay()
	assert(scene.age == 0)
	scene._load_preset(1)
	assert(scene.settings.direction_degrees == 45.0)
	assert(scene.settings.reverse)
	scene._load_preset(2)
	assert(is_equal_approx(scene.settings.curvature, 0.45))
	scene._load_preset(3)
	assert(is_equal_approx(scene._duration(), 0.235))
	scene._load_preset(0)
	assert(not scene.settings.reverse)
	assert(scene.settings.reach_px == 46.0)
	scene.inputs.reach_px.slider.value = 16.0
	assert(scene.settings.thickness_px <= 10.4)
	scene.inputs.direction_degrees.slider.value = 360
	assert(scene.settings.direction_degrees == 360)
	scene.inputs.start_seconds.slider.value = 0.08
	assert(scene.age == 0.0)
	scene.paused = false
	scene.looped = false
	scene._process(0.5)
	assert(is_equal_approx(scene.age, scene._duration()))
	scene._replay()
	scene.looped = true
	scene._process(scene._duration() + 0.46)
	assert(scene.age < 0.011)
	print("PASS: preview defaults, preset/reset, pause/step, live width clamp, direction, timing restart, finish and loop")
	quit()
