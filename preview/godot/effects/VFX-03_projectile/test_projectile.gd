extends SceneTree
const Bolt = preload("res://effects/VFX-03_projectile/projectile_state.gd")
var failures := 0
var checks := 0
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
func _init() -> void:
	var b := Bolt.new()
	b.reset(Vector2.ZERO, Vector2(180, 0))
	check(b.active and b.age == 0.0 and b.history.size() == 1, "reset state")
	for i in range(60):
		b.tick(1.0 / 120.0, Vector2((i + 1) * 1.5, 0), Vector2(180, 0))
	check(absf(b.age - 0.5) < 0.0001, "age seconds")
	check(b.tail_length > 22.0 and b.tail_length < 23.0, "velocity-driven length")
	check(b.path_points().size() > 3, "real history exists")
	var p := b.world_position
	var age := b.age
	var length := b.tail_length
	var flow := b.flow_time
	var count := b.history.size()
	b.paused = true
	b.tick(1.0, p + Vector2(999, 999), Vector2.ZERO)
	check(b.world_position == p and b.age == age and b.tail_length == length and b.flow_time == flow and b.history.size() == count, "pause freezes ALL state")
	b.reset(Vector2(12, 7), Vector2.LEFT * 100)
	check(not b.paused and not b.exiting and b.age == 0.0 and b.history.size() == 1 and b.flow_time == 0.0, "reset clears paused and all clocks/history")
	b.tick(0.1, Vector2(2, 7), Vector2.LEFT * 100)
	b.stop()
	b.tick(0.04, Vector2(-2, 7), Vector2.LEFT * 100)
	check(b.active and b.exiting and b.envelope() < 1.0, "graceful stop exits")
	b.tick(0.06, Vector2(-20, 7), Vector2.LEFT * 100)
	check(not b.active and b.history.is_empty(), "stop fully clears within 90 ms")
	b.reset(Vector2.ZERO, Vector2.RIGHT)
	b.tick(0.2, Vector2(10, 0), Vector2.RIGHT * 50)
	b.stop(true)
	check(not b.active and b.history.is_empty() and b.tail_length == 0.0, "immediate clear")
	b.reset(Vector2.ZERO, Vector2.RIGHT * 180)
	b.tick(0.1, Vector2(18, 0), Vector2.RIGHT * 180)
	b.tick(0.01, Vector2(400, 100), Vector2.RIGHT * 180)
	check(b.teleport_count == 1 and b.history.size() == 1 and b.path_points().size() == 1, "teleport never bridges old trail")
	b.reset(Vector2.ZERO, Vector2.RIGHT * 180)
	b.lifetime = 0.2
	b.tick(0.19, Vector2(20, 0), Vector2.RIGHT * 180)
	check(b.active and not b.exiting, "lifetime alive before deadline")
	b.tick(0.02, Vector2(22, 0), Vector2.RIGHT * 180)
	check(b.exiting and absf(b.exit_age - 0.01) < 0.0001, "lifetime boundary carries overshoot")
	b.tick(0.1, Vector2(30, 0), Vector2.RIGHT * 180)
	check(not b.active, "lifetime terminates")
	b.reset(Vector2.ZERO, Vector2.RIGHT)
	b.lifetime = 0.2
	b.tick(10.0, Vector2(10, 0), Vector2.RIGHT)
	check(not b.active, "large delta terminates")
	b.configure({"head_radius": -3, "tail_min": 99, "tail_max": -1, "flow_strength": 8, "speed_response": 0, "lifetime": -1})
	check(b.head_radius == 2.0 and b.tail_min == 30.0 and b.tail_max == 30.0 and b.flow_strength == 1.0 and b.speed_response == 0.01 and b.lifetime == 0.1, "extreme configuration clamped consistently")
	b.configure({"tail_min": 9, "tail_max": 42, "lifetime": 10})
	b.reset(Vector2.ZERO, Vector2.RIGHT * 10)
	for i in range(2400):
		b.tick(1.0 / 240.0, Vector2((i + 1) * 0.06, 0), Vector2.RIGHT * 14.4)
		check(b.history.size() <= Bolt.HISTORY_CAP, "history memory bound")
	b.reset(Vector2.ZERO, Vector2.RIGHT * 180)
	b.tick(0.3, Vector2(54, 0), Vector2.RIGHT * 180)
	var before := b.tail_length
	b.tick(0.1, Vector2(54, 0), Vector2.ZERO)
	check(b.tail_length < before * 0.2, "stationary body retracts tail")
	var results := []
	for fps in [30, 60, 144]:
		var c := Bolt.new()
		c.reset(Vector2.ZERO, Vector2.RIGHT * 180)
		for i in range(fps):
			c.tick(1.0 / fps, Vector2(180.0 * (i + 1) / fps, 0), Vector2.RIGHT * 180)
		results.append([c.world_position.x, c.tail_length, c.age])
	for result in results:
		check(absf(result[0] - 180.0) < 0.0001 and absf(result[1] - results[0][1]) < 0.0001 and absf(result[2] - 1.0) < 0.0001, "30/60/144 FPS independence")
	b.reset(Vector2(0.23, 0.17), Vector2(123.12, 0.0))
	b.tick(0.01, Vector2(1.4612, 0.17), Vector2(123.12, 0.0))
	check(absf(b.world_position.x - 1.4612) < 0.00001 and absf(b.world_position.y - 0.17) < 0.00001, "simulation never pixel quantizes")
	var unchanged := b.world_position
	b.tick(-1.0, Vector2.ZERO, Vector2.ZERO)
	b.tick(NAN, Vector2.ZERO, Vector2.ZERO)
	b.tick(0.1, Vector2(NAN, 0), Vector2.ZERO)
	check(b.world_position == unchanged, "invalid inputs ignored")
	b.configure({"head_radius": NAN, "tail_max": INF})
	check(is_finite(b.head_radius) and is_finite(b.tail_max), "nonfinite config retains valid state")
	b.reset(Vector2(NAN, 0), Vector2(INF, 0))
	check(b.world_position.is_finite() and b.velocity.is_finite(), "nonfinite reset inputs sanitized")
	print("VFX-03 state tests: %d checks; %d failures" % [checks, failures])
	quit(1 if failures else 0)
