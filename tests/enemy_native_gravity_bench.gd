extends SceneTree
## Actual EnemyActor callbacks and native PhysicsServer steps, not hand-called
## actor/solver ticks. Real GravityField and live roster/resources; DOT disabled
## only to retain all69 stress bodies, as in the previous geometry benchmark.
class Stepper extends Node:
	var task: SceneTree
	var method: StringName
	func _physics_process(delta: float) -> void: task.call(method, delta)
var arena: RageArena
var field: GravityField
var before: Stepper
var after: Stepper
var frame := 0
var peak := 0.0
var steady_peak := 0.0
var samples: Array[float] = []
var failures := 0
var minimum_live := 69
var server_error := 0.0
var maximum_admission_offset := 0.0

func _initialize() -> void: call_deferred("run")
func run() -> void:
	arena = RageArena.new()
	arena.practice = true
	arena.run_seed_override = 0
	arena.lab_ai = true
	arena.sound_enabled = false
	root.add_child(arena)
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	arena.enemies.process_mode = Node.PROCESS_MODE_ALWAYS
	arena.occupancy.process_mode = Node.PROCESS_MODE_ALWAYS
	arena.bow.enabled = false
	arena.apply_ranks({"element_type": "dark", "enchant_rank": 3, "element_skill_rank": 3})
	field = GravityField.new()
	field.configure(arena.stats, arena.enemies, func(_enemy: EnemyActor, _damage: float, _element: String) -> void: pass)
	arena.add_child(field)
	field.position = Vector2(300, 400)
	var kinds := ["mob", "swiftfang", "elite_hornling", "ranged"]
	for i in range(69):
		var requested := field.position + Vector2.from_angle(i * 2.39996323) * sqrt(float(i)) * 16.0
		var body := arena.spawn_enemy("mountainbreaker" if i == 0 else kinds[i % kinds.size()], requested)
		if body == null:
			failures += 1
			continue
		maximum_admission_offset = maxf(maximum_admission_offset, body.position.distance_to(requested))
		if body is BossActor: body.ai_enabled = false
		field.attach_enemy(body)
	before = Stepper.new()
	before.task = self
	before.method = &"pre_step"
	before.process_physics_priority = -20
	root.add_child(before)
	after = Stepper.new()
	after.task = self
	after.method = &"post_step"
	after.process_physics_priority = 10
	root.add_child(after)

func pre_step(delta: float) -> void:
	var previous := field.position
	field.position.x = 300.0 + float(frame + 1) * arena.stats.arrow_speed / 60.0
	field.tick(delta, previous)

func post_step(_delta: float) -> void:
	var bodies := arena.enemies.get_children()
	minimum_live = mini(minimum_live, bodies.size())
	if frame >= 60: samples.append(float(arena.occupancy.last_solve_usec) / 1000.0)
	for i in range(bodies.size()):
		for j in range(i + 1, bodies.size()):
			var depth: float = bodies[i].occupancy_radius + bodies[j].occupancy_radius - bodies[i].position.distance_to(bodies[j].position)
			peak = maxf(peak, depth)
			if frame >= 240: steady_peak = maxf(steady_peak, depth)
	for entry: Dictionary in arena.occupancy._entries.values():
		var proxy: StaticBody2D = entry.proxy
		var transform: Transform2D = PhysicsServer2D.body_get_state(proxy.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM)
		server_error = maxf(server_error, transform.origin.distance_to(proxy.global_position))
	if arena.occupancy.charge_failure: failures += 1
	frame += 1
	if frame >= 360:
		before.set_physics_process(false)
		after.set_physics_process(false)
		call_deferred("finish")

func finish() -> void:
	samples.sort()
	print("NATIVE REAL GRAVITY ENGINE STEP count_min=%d frames=%d p50_ms=%.3f p95_ms=%.3f max_ms=%.3f every_frame_peak_px=%.5f steady_peak_px=%.5f server_error_px=%.5f max_spawn_offset_px=%.3f" % [minimum_live, frame, samples[samples.size()/2], samples[int(samples.size()*0.95)], samples.back(), peak, steady_peak, server_error, maximum_admission_offset])
	var passed := failures == 0 and minimum_live == 69 and peak <= 1.0 and server_error < 0.001
	arena.free()
	await preload("res://tests/audio_teardown.gd").drain(self)
	quit(0 if passed else 1)
