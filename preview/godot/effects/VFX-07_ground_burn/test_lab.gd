extends SceneTree
var checks := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failed += 1
		push_error(label)
func run() -> void:
	var lab = load("res://effects/VFX-07_ground_burn/lab.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	check(lab.effects.size() == 4, "actual, detail and two-overlap preview instances")
	lab.tick(1.0)
	check(lab.effects[0].age == 1.0 and lab.effects[1].age == 1.0, "native and nearest views share absolute time")
	lab.paused = true
	lab._process(1.0)
	check(lab.elapsed == 1.0, "pause keeps externally driven preview time")
	lab.tick(1.0/60.0)
	check(is_equal_approx(lab.elapsed, 1.0 + 1.0/60.0), "manual single frame works while paused")
	lab.clear_effects()
	check(lab.effects.all(func(fx): return not fx.visible), "clear removes all four previews")
	lab.replay()
	check(lab.elapsed == 0.0 and lab.effects.all(func(fx): return fx.visible), "replay after clear restarts every preview")
	lab.radius = 52.0; lab.height = 8.0; lab.intensity = 0.4; lab.replay()
	check(lab.effects[0].radius == 52.0 and is_equal_approx(lab.effects[3].radius,67.6), "radius applies to both overlap geometries")
	check(lab.effects[0].settings.flame_height == 8.0 and lab.effects[0].settings.intensity == 0.4, "parameters apply through runtime contract")
	lab.tick(4.0)
	check(lab.effects.all(func(fx): return not fx.visible), "all previews clear at exact lifetime")
	lab.tick(0.3)
	check(lab.effects.all(func(fx): return not fx.visible), "clear gap stays empty")
	lab.tick(0.4)
	check(lab.elapsed == 0 and lab.effects.all(func(fx): return fx.visible), "next cycle reuses rather than leaking instances")
	check(lab.effects.all(func(fx): return fx.get_child_count() == 2), "cycles retain fixed surface count")
	lab.free()
	print("GROUND BURN LAB: %d checks, %d failed" % [checks,failed])
	quit(1 if failed else 0)
