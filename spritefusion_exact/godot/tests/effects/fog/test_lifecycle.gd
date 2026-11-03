extends SceneTree
const Fog = preload("res://scripts/effects/fog.gd")
const Frame = preload("res://scripts/core/sf_frame.gd")
var failures: int = 0
var checks: int = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", label)

func first_frames(effect) -> Array:
	var frames = []
	for tick in range(3):
		if tick: effect.update(1.0 / 60.0)
		for origin in [[0.0, 0.0], [-3.5, 1.25]]:
			var direct = Frame.new(32, 20, origin[0], origin[1])
			var adapter = Frame.new(32, 20, origin[0], origin[1])
			for layer in ["back", "front"]:
				effect.draw(direct, layer)
				effect.draw(adapter.as_source(), layer)
			check(direct.color.data == adapter.color.data and direct.light.data == adapter.light.data,
				"Frame/source adapter equality at tick " + str(tick))
			frames.append([direct.color.data.duplicate(), direct.light.data.duplicate(), effect.done()])
	return frames

func _initialize() -> void:
	var options = {"seed": 7.0, "area": {"x": 0.0, "y": 0.0, "w": 64.0, "h": 40.0}}
	var effect = Fog.new().configure(options)
	var initial = first_frames(effect)
	effect.stop()
	var stopped_at: float = effect.stop_at
	effect.stop()
	check(effect.stop_at == stopped_at, "stop is idempotent")
	for i in range(151): effect.update(1.0 / 60.0)
	check(effect.done(), "stopped effect finishes")
	var cleared = Frame.new(32, 20)
	effect.draw(cleared, "back")
	effect.draw(cleared, "front")
	check(cleared.color.data.count(0) == 640 and cleared.light.data.count(0) == 640, "finished draw is empty")
	effect.configure(options)
	check(first_frames(effect) == initial, "reconfigure resets complete first frames")
	effect.dispose()
	effect.dispose()
	effect.configure(options)
	check(first_frames(effect) == initial, "reconfigure after repeated dispose resets frames")
	print("FOG_LIFECYCLE checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)
