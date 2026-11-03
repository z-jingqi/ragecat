extends SceneTree
const Warning = preload("res://effects/VFX-17_boss_warning/hostile_warning.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var w := Warning.new()
	root.add_child(w)
	for shape in ["circle", "capsule", "line"]:
		for radius in [0.25, 7.0, 23.0, 62.0, 400.0, 10000.0]:
			for endpoint in [Vector2.ZERO, Vector2(456, 0), Vector2(-913, 522), Vector2(0, -10000)]:
				w.play(shape, Vector2.ZERO, endpoint, radius)
				check(w.active and w.radius == radius and w.endpoint == endpoint, "caller geometry preserved")
				var points: PackedVector2Array = w.boundary_points()
				check(points.size() >= 49 and points[0].is_equal_approx(points[-1]), "complete closed outline")
				for p in points:
					var nearest: Vector2 = endpoint if shape == "circle" else Geometry2D.get_closest_point_to_segment(p, Vector2.ZERO, endpoint)
					check(absf(p.distance_to(nearest) - radius) <= 0.002 + radius * 0.00001, "boundary matches supplied circle/capsule")
				w.seek(0.63)
				check(w.progress == 0.63 and w.boundary_points() == points, "progress never moves boundary")
				await process_frame
				check(w.progress == 0.63 and w.active, "externally clocked pause")
				w.seek(1.0)
				check(w.active and w.progress == 1.0, "full warning retained during charge")
				w.seek(-3)
				check(w.progress == 0, "progress lower bound")
				w.seek(4)
				check(w.progress == 1, "progress upper bound")
				w.seek(NAN)
				check(w.progress == 1, "invalid seek ignored")
				w.stop()
				w.seek(0.5)
				check(not w.active and w.boundary_points().is_empty(), "cancel clears geometry and cannot revive")
	for i in range(100):
		w.play("capsule", Vector2(31, -9), Vector2(76, 21), 23)
		w.seek(0.9)
		w.play("circle", Vector2.ZERO, Vector2(-52, 62), 62)
		check(w.progress == 0 and w.origin == Vector2.ZERO and w.shape == "circle", "replay replaces prior state")
		w.stop()
	for bad in [0.0, -1.0, NAN, INF]:
		w.play("circle", Vector2.ZERO, Vector2.ZERO, bad)
		check(not w.active, "invalid radius fails closed")
	w.play("sector", Vector2.ZERO, Vector2.ZERO, 62)
	check(not w.active, "unsupported shape fails closed")
	w.play("line", Vector2(INF, 0), Vector2.ZERO, 7)
	check(not w.active, "invalid origin fails closed")
	w.play("circle", Vector2.ZERO, Vector2(NAN, 0), 62)
	check(not w.active, "invalid endpoint fails closed")
	check(not w.is_processing() and not w.is_physics_processing(), "no autonomous gameplay clock")
	w.free()
	print("HOSTILE WARNING: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
