extends SceneTree
const History = preload("res://effects/VFX-02_weapon_trail/trail_history.gd")
var checks := 0
var failures := 0
func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		push_error("FAIL: " + description)
		failures += 1
		return
	print("PASS: " + description)

func _initialize() -> void:
	var h := History.new()
	h.submit_pose(Vector2.ZERO, Vector2(2, 0))
	for i in range(20):
		h.advance(0.002)
		h.submit_pose(Vector2.ZERO, Vector2(2, 0))
	check(h.count == 1 and h.births[h.head] == 0.0, "motionless does not emit or refresh time")
	h.advance(0.01)
	h.submit_pose(Vector2.ZERO, Vector2(1.9, 0.3))
	check(h.count == 2 and h.remaining(0) < h.remaining(1), "actual rotating tip records chronological history")
	h.stop_emission()
	h.advance(0.17)
	check(h.count == 0, "stop emission expires to empty within lifetime")
	h.begin_trail()
	h.submit_pose(Vector2.ZERO, Vector2(2, 0))
	h.submit_pose(Vector2(10, 0), Vector2(12, 0))
	check(h.count == 1 and h.teleport_resets == 1, "teleport starts new history without bridging")
	h.submit_pose(Vector2(10, 0), Vector2(8, 0))
	check(h.count == 1 and h.teleport_resets == 2, "greater than 120 degree frame jump breaks folded geometry")
	h.begin_trail()
	h.lifetime = 0.6
	h.max_samples = 8
	for i in range(2000):
		h.advance(0.0001)
		h.submit_pose(Vector2(i * 0.06, 0), Vector2(i * 0.06 + 2, 0))
	check(h.count == 8 and h.roots.size() == 64 and h.births.size() == 64, "2000 samples wrap fixed-capacity ring without growth")
	h.max_samples = 2
	h.advance(0.0)
	check(h.count == 2, "live cap reduction trims existing history")
	h.clear()
	var transform := Transform2D(0.73, Vector2(-9.3, 7.1))
	var a := transform * Vector2(0.5, 0)
	var b := transform * Vector2(2.5, 0)
	h.submit_pose(a, b)
	h.submit_pose(a + Vector2(0.1, 0.2), b + Vector2(0.1, 0.2))
	check(h.roots[h.index(0)].is_equal_approx(a) and h.tips[h.index(0)].is_equal_approx(b), "rotation + translation preserve input world endpoints")
	var before: float = h.clock
	h.advance(-1.0)
	h.advance(NAN)
	check(h.clock == before, "negative/nonfinite dt ignored")
	h.lifetime = NAN
	h.min_sample_distance = -10
	h.max_samples = 200
	h.teleport_distance = INF
	h.sanitize()
	check(h.lifetime == 0.16 and h.min_sample_distance == 0.005 and h.max_samples == 64 and h.teleport_distance == 3.0, "configuration extremes clamp safely")
	h.submit_pose(Vector2(NAN, 0), Vector2.ZERO)
	check(h.count == 0, "invalid world position clears history safely")
	h.begin_trail()
	for i in range(60):
		h.advance(1.0 / 60.0)
		var theta := -float(i) * 0.08
		h.submit_pose(Vector2.ZERO, Vector2(cos(theta), sin(theta)) * 2.0)
	check(h.count >= 8 and h.teleport_resets == 2, "continuous reverse rotation stays connected")
	h.advance(1.0)
	check(h.count == 0, "large dt fully cleans history")
	h.submit_pose(h.last_root, h.last_tip)
	check(h.count == 0, "stationary pose does not reseed even after all history expires")
	for direction in [Vector2.RIGHT, Vector2(0.8, 0.6), Vector2.UP]:
		h.begin_trail()
		h.lifetime = 0.16
		for i in range(10):
			h.advance(1.0 / 60.0)
			var offset: Vector2 = direction * float(i) * 0.1
			h.submit_pose(offset, offset + Vector2(0, 2))
		check(h.count >= 8 and h.roots[h.index(h.count - 1)].is_equal_approx(direction * 0.9), "arbitrary translation direction records exact endpoints: " + str(direction))
	print("VFX02_HISTORY_TESTS_PASSED ", checks)
	quit(0 if failures == 0 else 1)
