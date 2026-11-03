extends SceneTree
const Preview = preload("res://previews/group_three/preview.gd")
const JS = preload("res://scripts/core/sf_js.gd")
var failures = 0
var checks = 0

class SpyEffect extends RefCounted:
	var updates = 0
	var draws = 0
	var disposals = 0
	var finished = false
	func update(_dt): updates += 1
	func draw(_frame, _layer): draws += 1
	func done(): return finished
	func stop(): finished = true
	func dispose(): disposals += 1

func _initialize(): call_deferred("run")
func check(ok, label):
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", label)

func key(preview, code):
	var event = InputEventKey.new()
	event.pressed = true
	event.keycode = code
	preview._unhandled_key_input(event)

func owned(preview):
	var result = []
	for fx in preview.live:
		result.append(fx._effect)
		var scopes = []
		JS._collect_scopes(fx._effect, [], scopes)
		result.append_array(scopes)
	return result

func run():
	# Only Pickup and Sparkle are needed; no expensive weather replay.
	if not FileAccess.file_exists("res://scripts/effects/pickup.gd"):
		printerr("BLOCKED: this control test requires the already-published Pickup port")
		quit(2)
		return
	var preview = Preview.new()
	preview.slug = "pickup"
	preview.paused = true
	root.add_child(preview)
	preview.set_process(false)
	for repeat in range(3):
		var previous = owned(preview)
		key(preview, KEY_R)
		check(previous.all(func(item): return item.is_empty()), "R releases owned effect and all capture scopes")
		check(preview.sim_frame == 0 and preview.accumulator == 0.0 and preview.replay_delay == 0.0, "R resets simulation counters")
		check(preview.paused, "R preserves explicit paused state")
		previous.clear()
	# A spy isolates the host scheduler from effect algorithms and observes calls.
	preview._exit_tree()
	var spy = SpyEffect.new()
	preview.live = [spy]
	preview.c = {"calls":[{"at":0.0}], "situation":"probe", "options":{}}
	preview.call_index = 1
	preview.warmup_remaining = 3
	preview.sim_frame = 7
	preview.accumulator = 0.01
	preview.replay_delay = 0.5
	var color = preview.composite_frame.color.data.duplicate()
	var light = preview.composite_frame.light.data.duplicate()
	preview._process(10.0)
	preview._process(1.0 / 60.0)
	check(spy.updates == 0 and spy.draws == 0, "pause does not call effect update or draw")
	check(preview.sim_frame == 7 and preview.warmup_remaining == 3 and preview.accumulator == 0.01 and preview.replay_delay == 0.5, "pause freezes simulation, warmup, accumulator and replay delay")
	check(preview.composite_frame.color.data == color and preview.composite_frame.light.data == light, "pause retains both buffers")
	preview.paused = false
	preview.replay_delay = 0.0
	preview.accumulator = 0.0
	preview.warmup_remaining = 0
	spy.finished = true
	preview._process(1.0 / 60.0)
	check(preview.replay_delay == 1.0 and spy.updates == 1 and spy.draws == 2, "done enters one-second hold after final update/draw")
	preview._process(0.25)
	check(preview.replay_delay == 0.75 and spy.updates == 1 and spy.draws == 2, "done hold performs no update/draw")
	preview.paused = true
	preview._process(10.0)
	check(preview.replay_delay == 0.75, "pause freezes done hold")
	preview.paused = false
	preview._process(0.8)
	check(spy.disposals == 1 and preview.sim_frame == 0 and preview.live.size() == 3, "expired done hold disposes old state and creates new Pickup cycle")
	var previous = owned(preview)
	preview._exit_tree()
	preview._exit_tree()
	check(preview.live.is_empty() and previous.all(func(item): return item.is_empty()), "repeated exit clears live ownership safely")
	preview.free()
	previous.clear()
	if FileAccess.file_exists("res://scripts/effects/sparkle.gd"):
		var sparkle = Preview.new()
		sparkle.slug = "sparkle"
		sparkle.paused = true
		root.add_child(sparkle)
		sparkle.set_process(false)
		var old = owned(sparkle)
		key(sparkle, KEY_RIGHT)
		check(sparkle.chosen == 1 and sparkle.sim_frame == 0 and sparkle.paused, "right arrow changes situation and resets while paused")
		check(old.all(func(item): return item.is_empty()), "situation change disposes old captured state")
		old.clear()
		key(sparkle, KEY_LEFT)
		check(sparkle.chosen == 0, "left arrow restores first situation")
		sparkle.free()
	else:
		print("SKIP unavailable Sparkle situation switch")
	JS.clear_property_cache()
	print("HOST_CONTROLS checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
