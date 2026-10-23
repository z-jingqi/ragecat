extends SceneTree
## Regression for unbuffed double shots after targetless time or a stalled frame.
var arena: RageArena
var checks := 0
var failures := 0
var launches := 0
var emitted_frames: Array[int] = []

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)
func reset(ranks: Dictionary = {}) -> void:
	arena.clear_enemies()
	for arrow in arena.arrows.get_children(): arrow.free()
	arena.apply_ranks(ranks)
	arena.bow.enabled = true
	arena.bow.attack_clock = 0.0
	arena.bow.burst_remaining = 0
	arena.bow.burst_clock = 0.0
	launches = 0
func target() -> EnemyActor:
	return arena.spawn_enemy("dummy", arena.player.position + Vector2(150, 0))
func tick(delta: float) -> void: arena.bow._physics_process(delta)
func interval() -> float: return 1.0 / (arena.stats.arrow_rate * arena.stats.attack_speed)
func tick_for(duration: float, dt: float) -> void:
	for _i in range(int(ceil(duration / dt))): tick(dt)
func on_volley(_gravity: bool) -> void:
	launches += 1
	emitted_frames.append(Engine.get_physics_frames())

func run() -> void:
	arena = RageArena.new()
	arena.practice = true
	root.add_child(arena)
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	arena.bow.volley_launched.connect(on_volley)
	var original_physics_rate := Engine.physics_ticks_per_second
	for dt in [1.0/30.0, 1.0/60.0, 1.0/144.0]:
		Engine.physics_ticks_per_second = int(round(1.0 / dt))
		reset()
		tick_for(4.0, dt)
		check(launches == 0, "idle does not shoot")
		target()
		tick(dt)
		check(launches == 1, "acquisition fires one arrow")
		tick(dt)
		check(launches == 1, "no next-frame extra arrow after idle dt=%s" % dt)
		check(arena.bow.attack_clock > interval() * 0.8, "fresh target retains nearly full interval")
		reset()
		target()
		tick(0.0)
		var times: Array[float] = [0.0]
		var elapsed := 0.0
		for _i in range(int(10.0 / dt)):
			elapsed += dt
			var before := launches
			tick(dt)
			if launches > before: times.append(elapsed)
		check(absi(launches - 19) <= 1, "normal rate stays close to 1.8 shots/s")
		for i in range(1, times.size()):
			check(times[i] - times[i - 1] >= interval() - dt - 0.0001, "normal minimum cadence")
	Engine.physics_ticks_per_second = original_physics_rate
	for stalled_delta in [0.7, 2.0, 10.0]:
		reset()
		target()
		tick(0.0)
		tick(stalled_delta)
		check(launches == 2, "long frame emits at most one new volley")
		tick(1.0/60.0)
		check(launches == 2, "long frame leaves no next-frame catch-up")
		check(arena.bow.attack_clock > interval() * 0.8, "long frame preserves recovery")
	reset()
	target()
	arena.bow.attack_clock = 0.01
	tick(0.54)
	tick(1.0/60.0)
	tick(1.0/60.0)
	check(launches == 1, "partial-period stall cannot cause compressed followup")
	reset()
	target()
	tick(0.0)
	arena.clear_enemies()
	tick_for(5.0, 1.0/60.0)
	target()
	tick(1.0/60.0)
	tick(1.0/60.0)
	check(launches == 2, "reacquisition has no accumulated volley debt")
	reset()
	target()
	arena.stats.attack_speed = 0.0
	tick_for(3.0, 1.0/60.0)
	arena.stats.attack_speed = 1.0
	tick(1.0/60.0)
	tick(1.0/60.0)
	check(launches == 1, "zero-rate recovery cannot bank shots")
	reset()
	target()
	tick(0.0)
	var remaining := arena.bow.attack_clock
	arena.bow.enabled = false
	tick(3.0)
	check(is_equal_approx(remaining, arena.bow.attack_clock), "disabled weapon freezes cadence")
	arena.bow.enabled = true
	tick(1.0/60.0)
	check(launches == 1, "reenabling cannot prematurely fire")
	reset({"burst":3, "spread_arrow":2})
	target()
	tick(0.0)
	for _i in range(3): tick(arena.stats.burst_spacing)
	check(launches == 4, "legitimate burst retains four volleys")
	check(arena.bow.active_count(false) == 20, "legitimate fan retains five arrows per volley")
	reset()
	target()
	tick(0.0)
	check(launches == 1 and arena.bow.active_count(false) == 1, "new configuration has no inherited fan or burst")
	reset({"fire_enchant":1, "burst":3})
	target()
	tick(0.0)
	arena.clear_enemies()
	tick_for(3.0, 1.0/60.0)
	arena.apply_ranks({"ice_enchant":1})
	target()
	var before_switch := launches
	tick(1.0/60.0)
	tick(1.0/60.0)
	check(launches == before_switch + 1, "clear and element switch discard old burst and idle debt")
	# Actual SceneTree scheduling: idle, acquisition, pause and resume, not direct calls.
	reset()
	emitted_frames.clear()
	arena.process_mode = Node.PROCESS_MODE_PAUSABLE
	arena.set_physics_process(false)
	arena.player.set_physics_process(false)
	await create_timer(0.65).timeout
	check(launches == 0, "real physics idle has no volley")
	target()
	await create_timer(0.08).timeout
	check(launches == 1, "real physics acquisition has only one volley")
	var pause_clock := arena.bow.attack_clock
	paused = true
	await create_timer(0.2).timeout
	check(launches == 1 and is_equal_approx(arena.bow.attack_clock, pause_clock), "real pause freezes firing countdown")
	paused = false
	await create_timer(0.62).timeout
	check(launches == 2, "real resume has no extra volley")
	if emitted_frames.size() >= 2:
		check(emitted_frames[1] - emitted_frames[0] >= 32, "real arrow emissions are not adjacent physics frames")
	else: check(false, "real scheduler recorded two volleys")
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	await preload("res://tests/audio_teardown.gd").drain(self)
	arena.free()
	print("BOW CADENCE: %d checks, %d failures" % [checks, failures])
	await preload("res://tests/audio_teardown.gd").drain(self)
	quit(0 if failures == 0 else 1)
