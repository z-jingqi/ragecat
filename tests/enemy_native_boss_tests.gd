extends SceneTree
class Stepper extends Node:
	var task: SceneTree
	var method: StringName
	func _physics_process(delta: float) -> void: task.call(method, delta)
var arena: RageArena
var boss: Mountainbreaker
var before: Stepper
var after: Stepper
var case_index := -1
var case_limit := 8
var open_space := false
var allow_entity_stop := false
var previous_position := Vector2.ZERO
var previous_remaining := 0
var last_hit_frame := -1
var proxy_starts: Dictionary = {}
var blocked_segments := 0
var max_work := 0
var max_prepare_usec := 0
var charge_prepare_samples: Array[int] = []
var charge_solve_samples: Array[int] = []
var busiest_queries: Dictionary = {}
var busiest_entries: Dictionary = {}
var busiest_commits: Dictionary = {}
var checks := 0
var failures := 0
var ticks := 0
var expected := Vector2.ZERO
var previous_state := ""
var charges_seen := 0
var peak := 0.0
var path_error := 0.0
var finished_test := false
func _initialize() -> void:
	if "--first-only" in OS.get_cmdline_user_args(): case_limit = 1
	if "--case3-only" in OS.get_cmdline_user_args():
		case_index = 2
		case_limit = 4
	if "--case8-only" in OS.get_cmdline_user_args():
		case_index = 7
		case_limit = 9
	open_space = "--open-space" in OS.get_cmdline_user_args()
	allow_entity_stop = "--allow-entity-stop" in OS.get_cmdline_user_args()
	if open_space: case_limit = 10
	if "--corner-combos" in OS.get_cmdline_user_args():
		case_index = 7
		case_limit = 10
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("NATIVE BOSS FAIL: " + label)
func run() -> void:
	arena = RageArena.new()
	arena.practice = true
	if open_space:
		arena.definition = arena.definition.validated_copy()
		arena.definition.practice_bounds = Rect2(0, 0, 5000, 5000)
	arena.run_seed_override = 0
	arena.lab_ai = false
	arena.sound_enabled = false
	root.add_child(arena)
	arena.set_process(false)
	arena.set_physics_process(false)
	arena.player.set_physics_process(false)
	arena.player.invulnerable = true
	arena.bow.enabled = false
	arena.occupancy.collect_diagnostics = true
	if "--work512" in OS.get_cmdline_user_args(): arena.occupancy.definition.charge_work_limit = 512
	if "--depth16" in OS.get_cmdline_user_args(): arena.occupancy.definition.charge_chain_depth = 16
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
	next_case()
func next_case() -> void:
	case_index += 1
	if case_index >= case_limit:
		stop()
		return
	arena.clear_enemies()
	ticks = 0
	charges_seen = 0
	peak = 0.0
	path_error = 0.0
	blocked_segments = 0
	max_work = 0
	max_prepare_usec = 0
	charge_prepare_samples.clear()
	charge_solve_samples.clear()
	busiest_queries.clear()
	busiest_entries.clear()
	busiest_commits.clear()
	var angle := float(case_index % 8) * PI / 4.0
	var forward := Vector2.from_angle(angle)
	var side := forward.orthogonal()
	var origin := arena.bounds.get_center() - forward * 200.0
	if case_index == 8 and not open_space: origin = Vector2(80, 45)
	if case_index == 9 and not open_space: origin = Vector2(70, 70)
	boss = arena.spawn_enemy("mountainbreaker", origin) as Mountainbreaker
	boss.force_phase_for_practice(2 if case_index >= 8 else 1)
	boss.attack_player.connect(func(_amount: float) -> void: last_hit_frame = Engine.get_physics_frames())
	boss.ai_enabled = true
	boss.ability_mode = "charge"
	arena.player.position = (origin + forward * 300.0).clamp(Vector2(60, 60), arena.bounds.end - Vector2(60, 60))
	var kinds := ["mob", "swiftfang", "elite_hornling", "ranged"]
	for i in range(68):
		var requested := origin + forward * (80.0 + float(i % 17) * 40.0) + side * (float(i / 17) - 1.5) * 35.0
		var actor := arena.spawn_enemy(kinds[i % 4], requested)
		check(actor != null, "keep every one of68 crowd actors")
		if actor != null:
			actor.ai_enabled = false
			if i % 7 == 0: actor.status.frozen_remaining = 3.0
	check(is_equal_approx(boss.charge_speed, 850.0), "actual scene charge speed850")
	check(is_equal_approx(boss.charge_distance, 940.0), "actual scene distance940")
	check(is_equal_approx(boss.warning_duration, 0.7), "actual arena warning0.7")
	check(is_equal_approx(boss.current_phase().repeat_charge_warning, 0.3), "actual combo repeat warning0.3")
	boss.charges_remaining = boss.current_phase().charge_count
	boss._start_charge_warning() # Real configured warning/charge state machine follows.
	previous_state = boss.state
func pre_step(delta: float) -> void:
	if finished_test: return
	if case_index >= 8 and ticks % 30 == 0:
		arena.player.position = arena.bounds.get_center() + Vector2.from_angle(float(ticks) * 0.031) * 180.0
	proxy_starts.clear()
	for actor in arena.enemies.get_children():
		proxy_starts[actor.get_instance_id()] = arena.occupancy._entries[actor.get_instance_id()].proxy.position
	previous_position = boss.position
	previous_remaining = boss.charges_remaining
	expected = boss.position.move_toward(boss.charge_end, boss.charge_speed * delta) if boss.state == "charge" else boss.position
	previous_state = boss.state
func post_step(_delta: float) -> void:
	if finished_test: return
	ticks += 1
	if arena.occupancy._charge_work > max_work:
		busiest_queries = arena.occupancy.priority_query_counts.duplicate()
		busiest_entries = arena.occupancy.priority_entry_counts.duplicate()
		busiest_commits = arena.occupancy.priority_commit_counts.duplicate()
	max_work = maxi(max_work, arena.occupancy._charge_work)
	if previous_state == "charge":
		charge_prepare_samples.append(arena.occupancy._priority_prepare_usec)
		charge_solve_samples.append(arena.occupancy.last_solve_usec)
	max_prepare_usec = maxi(max_prepare_usec, arena.occupancy._priority_prepare_usec)
	if boss.state == "charge" and previous_state != "charge": charges_seen += 1
	if allow_entity_stop and arena.occupancy.priority_blocked_this_tick:
		blocked_segments += 1
		check(last_hit_frame != Engine.get_physics_frames(), "blocked segment never emits a phantom charge damage sweep")
		check(previous_state == "charge" and boss.position == previous_position, "entity fallback never advances boss before ending segment")
		check(boss.charges_remaining == previous_remaining - 1, "entity fallback consumes exactly the current segment")
		check(boss.state == ("warning" if boss.charges_remaining > 0 else "recovery"), "entity fallback takes existing wall-end state branch")
		expected = previous_position
		print("EXPECTED ENTITY STOP case=", case_index, " reason=", arena.occupancy.priority_block_reason)
	path_error = maxf(path_error, boss.position.distance_to(expected))
	var actors := arena.enemies.get_children()
	for actor in actors:
		var proxy: StaticBody2D = arena.occupancy._entries[actor.get_instance_id()].proxy
		if actor.position.distance_to(proxy.position) > 0.001: check(false, "actor/proxy mismatch after final charge step")
		var server_transform: Transform2D = PhysicsServer2D.body_get_state(proxy.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM)
		if server_transform.origin.distance_to(proxy.global_position) > 0.001: check(false, "server/proxy mismatch after final charge step")
		if actor != boss and proxy.position.distance_to(proxy_starts[actor.get_instance_id()]) > 40.001: check(false, "passive net push exceeds original40px bound")
	if arena.occupancy._charge_work > arena.occupancy.definition.charge_work_limit: check(false, "entry/query/commit work exceeded configured hard cap")
	for i in range(actors.size()):
		for j in range(i + 1, actors.size()):
			peak = maxf(peak, actors[i].occupancy_radius + actors[j].occupancy_radius - actors[i].position.distance_to(actors[j].position))
	if arena.occupancy.charge_failure or path_error > 0.001 or peak > 1.0:
		print("FAILURE COST prepare_usec=", arena.occupancy._priority_prepare_usec, " total_occupancy_usec=", arena.occupancy.last_solve_usec, " prior_max_prepare_usec=", max_prepare_usec)
		print("QUERY COUNTS ", arena.occupancy.priority_query_counts, " ENTRY COUNTS ", arena.occupancy.priority_entry_counts, " COMMIT COUNTS ", arena.occupancy.priority_commit_counts, " CANDIDATES ", arena.occupancy.priority_candidate_trace)
		print("BLOCK TRACE reason=", arena.occupancy.priority_block_reason, " work=", arena.occupancy._charge_work, " boss=", boss.position, " expected=", expected, " state=", boss.state)
		check(false, "case%d frame%d exact_path_error=%.5f overlap=%.5f charge_failure=%s" % [case_index, ticks, path_error, peak, arena.occupancy.charge_failure])
		stop()
		return
	if previous_state == "charge" and boss.state == "recovery":
		check(charges_seen == boss.current_phase().charge_count, "configured charge count completed")
		if "--depth16" in OS.get_cmdline_user_args() and case_index == 8:
			check(blocked_segments > 0, "explicit low-depth negative control actually exercises safe entity-stop fallback")
		print("NATIVE REAL BOSS case=%d phase=%d frames=%d charges=%d peak_px=%.5f exact_path_error=%.5f" % [case_index, boss.phase_number, ticks, charges_seen, peak, path_error])
		charge_prepare_samples.sort()
		charge_solve_samples.sort()
		print("BOSS WORK max_work=", max_work, " diagnostic_max_prepare_usec=", max_prepare_usec, " blocked_segments=", blocked_segments)
		print("INSTRUMENTED CHARGE p95_prepare_usec=", charge_prepare_samples[int(charge_prepare_samples.size() * 0.95)], " p95_total_occupancy_usec=", charge_solve_samples[int(charge_solve_samples.size() * 0.95)], " max_total_usec=", charge_solve_samples[-1])
		print("BUSIEST QUERIES ", busiest_queries, " BUSIEST ENTRIES ", busiest_entries, " BUSIEST COMMITS ", busiest_commits)
		next_case()
	elif ticks > 600:
		check(false, "state machine timed out")
		stop()
func stop() -> void:
	finished_test = true
	before.set_physics_process(false)
	after.set_physics_process(false)
	call_deferred("finish")
func finish() -> void:
	print("NATIVE REAL BOSS: %d checks, %d failures" % [checks, failures])
	arena.free()
	await preload("res://tests/audio_teardown.gd").drain(self)
	quit(0 if failures == 0 else 1)
