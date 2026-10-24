extends SceneTree
class PracticeDriver extends "res://scripts/main.gd":
	func _ready() -> void:
		configure_input()
		add_child(ui)
		set_process(false)
class Stepper extends Node:
	var task: SceneTree
	var callback: StringName
	func _physics_process(delta: float) -> void: task.call(callback, delta)
var arena: RageArena
var driver: PracticeDriver
var boss: Mountainbreaker
var mover: EnemyActor
var blocker: EnemyActor
var target: Node2D
var before: Stepper
var after: Stepper
var active := false
var long_frame := false
var long_delta_seen := 0.0
var expect_budget_stop := false
var observed_budget_stop := false
var last_hit_frame := -1
var received_delta := 0.0
var previous_boss := Vector2.ZERO
var previous_state := ""
var starts: Dictionary = {}
var ticks := 0
var checks := 0
var failures := 0
func _initialize() -> void:
	expect_budget_stop = "--centerline-budget" in OS.get_cmdline_user_args()
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("NATIVE TIME SCALE FAIL: " + label)
func advance(count: int = 1) -> void:
	for i in range(count):
		await physics_frame
		await process_frame
func pre_step(delta: float) -> void:
	if not active: return
	received_delta = delta
	previous_boss = boss.position
	previous_state = boss.state
	starts.clear()
	for actor in arena.enemies.get_children(): starts[actor.get_instance_id()] = actor.position
func post_step(delta: float) -> void:
	if not active: return
	ticks += 1
	var cap := minf(arena.occupancy.definition.charge_clearance_speed * delta, arena.occupancy.definition.charge_clearance_cap)
	if previous_state == "charge":
		check(absf(arena.occupancy._charge_limit - cap) < 0.001, "preflight budget uses actual simulation delta and authored cap")
		if arena.occupancy.priority_blocked_this_tick: print("SCALED BLOCK delta=", delta, " cap=", cap, " reason=", arena.occupancy.priority_block_reason)
		if expect_budget_stop and arena.occupancy.priority_blocked_this_tick:
			observed_budget_stop = true
			check(boss.position == previous_boss and boss.state == "recovery", "delta-limited centerline blockage safely ends current segment")
			check(last_hit_frame != Engine.get_physics_frames(), "delta-limited blocked segment has no phantom damage")
		else:
			check(not arena.occupancy.priority_blocked_this_tick, "feasible time-scale fixture keeps authored charge path")
			check(boss.position.distance_to(previous_boss.move_toward(boss.charge_end, boss.charge_speed * delta)) < 0.001, "charge distance integrates actual simulation delta")
	for actor in arena.enemies.get_children():
		var proxy: StaticBody2D = arena.occupancy._entries[actor.get_instance_id()].proxy
		var state: Transform2D = PhysicsServer2D.body_get_state(proxy.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM)
		check(actor.position.distance_to(proxy.position) < 0.001 and state.origin.distance_to(proxy.global_position) < 0.001, "actor/native server synchronize at each scaled real physics frame")
		if actor != boss and actor != mover:
			check(actor.position.distance_to(starts[actor.get_instance_id()]) <= cap + 0.001, "passive motion obeys delta-dependent net cap")
		if actor != boss and previous_state == "charge":
			var nearest := Geometry2D.get_closest_point_to_segment(actor.position, previous_boss, boss.position)
			check(actor.position.distance_to(nearest) >= actor.occupancy_radius + boss.occupancy_radius - 0.1, "whole charge sweep capsule is clear, including long-frame midpoint")
	var actors := arena.enemies.get_children()
	for i in range(actors.size()):
		for j in range(i + 1, actors.size()):
			check(actors[i].position.distance_to(actors[j].position) >= actors[i].occupancy_radius + actors[j].occupancy_radius - 1.0, "scaled/native motion never stacks")
	check(mover.position.x <= blocker.position.x - mover.occupancy_radius - blocker.occupancy_radius + 1.0, "900px/s adversarial ordinary sweep cannot tunnel through blocker")
	if long_frame:
		long_delta_seen = delta
		Engine.physics_ticks_per_second = 60
		long_frame = false
func setup_case() -> void:
	active = false
	arena.clear_enemies()
	boss = arena.spawn_enemy("mountainbreaker", Vector2(500, 1000)) as Mountainbreaker
	boss.attack_player.connect(func(_amount: float) -> void: last_hit_frame = Engine.get_physics_frames())
	boss.ai_enabled = true
	boss.ability_mode = "charge"
	arena.player.position = Vector2(2500, 1000)
	for x in [580.0, 660.0, 740.0]:
		var body := arena.spawn_enemy("mob", Vector2(x, 1000 if expect_budget_stop else 1018))
		body.ai_enabled = false
	mover = arena.spawn_enemy("mob", Vector2(300, 300))
	mover.target = target
	mover.ai_enabled = true
	mover.speed = 900.0 # Adversarial fixture only; no production Resource changes.
	blocker = arena.spawn_enemy("mob", Vector2(330, 300))
	blocker.ai_enabled = false
	boss.charges_remaining = 1
	boss._start_charge_warning()
	ticks = 0
	active = true
func run() -> void:
	arena = RageArena.new()
	arena.definition = arena.definition.validated_copy()
	arena.definition.practice_bounds = Rect2(0, 0, 5000, 5000)
	arena.practice = true
	arena.lab_ai = false
	arena.sound_enabled = false
	root.add_child(arena)
	arena.set_process(false)
	arena.set_physics_process(false)
	arena.player.set_physics_process(false)
	arena.bow.enabled = false
	driver = PracticeDriver.new()
	root.add_child(driver)
	driver.arena = arena
	target = Node2D.new()
	target.position = Vector2(2000, 300)
	root.add_child(target)
	before = Stepper.new()
	before.task = self
	before.callback = &"pre_step"
	before.process_physics_priority = -20
	root.add_child(before)
	after = Stepper.new()
	after.task = self
	after.callback = &"post_step"
	after.process_physics_priority = 10
	root.add_child(after)
	var scales := [0.5] if expect_budget_stop else [0.5, 2.0, 4.0]
	for scale in scales:
		driver.practice_option("time_scale", scale)
		setup_case()
		await advance(2) # Let an already scheduled startup step finish.
		print("TIME SCALE TRACE scale=", scale, " delta=", received_delta, " ticks=", ticks, " fps=", Engine.physics_ticks_per_second)
		check(absf(received_delta - scale / 60.0) < 0.00001, "practice multiplier reaches real physics callbacks")
		var paused_at := boss.position
		var phase_at := boss.phase_time
		var tick_at := ticks
		driver.practice_option("time_scale", 0.0)
		await advance(3)
		check(paused and boss.position == paused_at and boss.phase_time == phase_at and ticks == tick_at, "practice zero pauses actor, attack and occupancy callbacks")
		driver.practice_option("time_scale", scale)
		var guard := 0
		while boss.state != "recovery" and guard < 400:
			await advance()
			guard += 1
		if expect_budget_stop:
			check(observed_budget_stop and boss.state == "recovery", "centerline negative control actually exercises delta-bound fallback")
		else:
			check(boss.state == "recovery" and boss.position.distance_to(boss.charge_end) < 0.001, "scaled charge completes original940 path")
		print("NATIVE TIME SCALE scale=", scale, " frames=", ticks, " final_delta=", received_delta)
	if expect_budget_stop:
		await finish()
		return
	# One genuine low-rate physics tick supplies delta=.25, then normal fixed
	# rate resumes. No repeated manual _physics_process calls/cache resets.
	driver.practice_option("time_scale", 1.0)
	setup_case()
	while boss.state == "warning": await advance()
	var original_max_steps := Engine.max_physics_steps_per_frame
	Engine.max_physics_steps_per_frame = 1
	long_frame = true
	Engine.physics_ticks_per_second = 4
	await advance()
	check(absf(long_delta_seen - 0.25) < 0.001, "real recoverable long physics step is0.25s")
	Engine.physics_ticks_per_second = 60
	Engine.max_physics_steps_per_frame = original_max_steps
	while boss.state != "recovery" and ticks < 200: await advance()
	check(boss.state == "recovery" and boss.position.distance_to(boss.charge_end) < 0.001, "long-frame charge resumes normal fixed-step progression")
	await finish()

func finish() -> void:
	active = false
	driver.practice_option("time_scale", 1.0)
	before.free()
	after.free()
	driver.free()
	target.free()
	arena.free()
	print("NATIVE TIME SCALE: %d checks, %d failures" % [checks, failures])
	await preload("res://tests/audio_teardown.gd").drain(self)
	quit(0 if failures == 0 else 1)
