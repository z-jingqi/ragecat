extends SceneTree
const FixedPath := preload("fixed_path.gd")
const Chain := preload("chain.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
func state(fx: Node2D) -> Array:
	var out := []
	for link in fx.links:
		out.append([link.bolt.age, link.bolt.active, link.bolt.visible, link.bolt.points.duplicate()])
	return out
func run() -> void:
	var fx := FixedPath.new()
	root.add_child(fx)
	var path := PackedVector2Array([Vector2(10, 65), Vector2(43, 61), Vector2(76, 29), Vector2(100, 70), Vector2(132, 35), Vector2(164, 63)])
	var original := path.duplicate()
	check(fx.done and not fx.is_processing() and not fx.is_physics_processing(), "no autonomous clock")
	check(not fx.has_signal("target_hit"), "no combat notification")
	fx.play_path(path)
	check(fx.duration == 0.18 and not fx.done, "caller default preserves game feedback duration")
	check(fx.links.size() == 5 and fx.get_child_count() == 5, "one bounded visual per path segment")
	for key in Chain.DEFAULTS:
		if key in FixedPath.DEFAULTS: check(Chain.DEFAULTS[key] == FixedPath.DEFAULTS[key], "canonical visual default " + key)
	for i in range(fx.links.size()):
		check(fx.links[i].start == path[i] and fx.links[i].end == path[i + 1], "exact caller order")
		check(not fx.links[i].bolt.automatic and not fx.links[i].bolt.is_processing(), "child clock disabled")
	path[1] = Vector2(-500, -500)
	var exported := fx.snapshot_points()
	exported[2] = Vector2(500, 500)
	check(fx.snapshot_points() == original, "input and output snapshot isolation")
	fx.position = Vector2(123.5, -84.25)
	fx.rotation = 0.3
	fx.scale = Vector2(2, 2)
	check(fx.links[0].bolt.points[0] == original[0] and fx.links[0].bolt.points[-1] == original[1], "local geometry unaffected by host transform")
	fx.advance(0.03)
	var saved := state(fx)
	fx.paused = true
	fx.advance(100)
	check(fx.age == 0.03 and state(fx) == saved, "pause freezes every child")
	fx.paused = false
	for bad in [-1.0, 0.0, INF, NAN]: fx.advance(bad)
	check(fx.age == 0.03 and state(fx) == saved, "invalid deltas ignored")
	fx.seek(NAN)
	check(fx.age == 0.03, "invalid seek ignored")
	fx.seek(0.1)
	fx.seek(0.03)
	check(state(fx) == saved, "backwards seek restores deterministic geometry")
	for hz in [30, 60, 144]:
		fx.play_path(original)
		for i in range(hz): fx.advance(1.0 / hz)
		check(fx.done and not fx.visible and fx.age == fx.duration, "exact expiry at any cadence")
	fx.replay()
	check(not fx.done and fx.age == 0 and fx.visible, "replay after expiry")
	fx.advance(100)
	check(fx.done and fx.age == 0.18, "large delta expires without callbacks")
	fx.replay()
	fx.advance(0.03)
	check(state(fx) == saved, "expired geometry reconstructs deterministically")
	fx.stop()
	check(fx.done and not fx.visible, "immediate visual stop")
	fx.replay()
	check(not fx.done, "stop allows explicit replay")
	fx.reset()
	fx.replay()
	check(fx.done and fx.age == 0 and fx.get_child_count() == 0 and fx.snapshot_points().is_empty(), "reset forgets all path and replay state")
	for invalid in [PackedVector2Array(), PackedVector2Array([Vector2.ZERO]), PackedVector2Array([Vector2.ZERO, Vector2(NAN, 1)]), PackedVector2Array([Vector2.ZERO, Vector2(2049, 0)])]:
		fx.play_path(invalid)
		check(fx.done and fx.get_child_count() == 0, "invalid path rejected without rerouting")
	fx.play_path(PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2(40, 0)]))
	check(not fx.done and fx.links.size() == 2 and not fx.links[0].drawable and fx.links[1].end == Vector2(40, 0), "zero-length edge does not reroute remaining path")
	fx.advance(0.06)
	check(fx.links[1].bolt.visible, "valid segment after repeated point animates")
	fx.play_path(PackedVector2Array([Vector2.ZERO, Vector2.ZERO]))
	check(fx.done and not fx.visible, "all coincident points are inert")
	var maximum := PackedVector2Array()
	for i in range(FixedPath.MAX_POINTS): maximum.append(Vector2(i * 2, 0))
	fx.play_path(maximum)
	check(fx.links.size() == 128 and not fx.done, "bounded maximum path")
	fx.advance(20)
	check(fx.done, "maximum path expires in one large delta")
	maximum.append(Vector2(300, 0))
	fx.play_path(maximum)
	check(fx.done and fx.links.is_empty(), "over-limit input rejected instead of truncated")
	var options := {"duration": 0.72, "width": 99.0, "jitter": NAN, "branches": -1, "core": Color(INF, 0, 0, 0)}
	fx.play_path(original, options)
	options.duration = 1.5
	check(fx.duration == 0.72 and fx.config.width == 3.0 and fx.config.jitter == 7.0 and fx.config.branches == 0, "sanitized isolated options")
	check(fx.config.core == Color(FixedPath.DEFAULTS.core), "invalid color fallback")
	var geometry: PackedVector2Array = fx.links[0].bolt.points.duplicate()
	fx.advance(0.12)
	check(fx.links[0].bolt.points == geometry, "no per-frame geometry regeneration")
	# Native temporal ratios are scaled into the caller's visual duration only.
	fx.play_path(original, {"duration": 0.63})
	fx.advance(0.03)
	check(fx.links[0].bolt.phase().reach > 0 and fx.links[0].bolt.phase().reach < 1 and not fx.links[1].bolt.visible, "partial leader growth before next visual segment")
	fx.advance(0.075)
	check(fx.links[0].bolt.visible and fx.links[1].bolt.visible, "old residue overlaps next link")
	for i in range(300):
		fx.play_path(original, {"seed": i})
		fx.advance(1)
		fx.reset()
		check(fx.done and fx.get_child_count() == 0, "repeated reset cleanup")
	fx.free()
	print("FIXED_PATH_CHECKS_PASSED ", checks, " failures=", failures)
	quit(1 if failures else 0)
