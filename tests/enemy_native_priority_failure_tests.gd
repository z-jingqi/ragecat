extends SceneTree
var arena: RageArena
var checks := 0
var failures := 0
var hits := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("NATIVE PRIORITY FAIL: " + label)
func advance(count: int = 1) -> void:
	for i in range(count):
		await physics_frame
		await process_frame
func run() -> void:
	arena = RageArena.new()
	arena.practice = true
	arena.lab_ai = false
	arena.run_seed_override = 0
	arena.sound_enabled = false
	root.add_child(arena)
	arena.set_process(false)
	arena.set_physics_process(false)
	arena.player.set_physics_process(false)
	arena.player.invulnerable = false
	arena.bow.enabled = false
	for scenario in range(3):
		arena.clear_enemies()
		await advance(2)
		arena.occupancy.definition.charge_work_limit = 16 if scenario < 2 else 256
		var boss := arena.spawn_enemy("mountainbreaker", Vector2(500, 400)) as Mountainbreaker
		boss.force_phase_for_practice(2 if scenario == 1 else 1)
		boss.ai_enabled = true
		boss.ability_mode = "charge"
		arena.player.position = Vector2(800, 400)
		var crowd: Array[EnemyActor] = []
		for row in range(-6 if scenario < 2 else 0, 7 if scenario < 2 else 1):
			var body := arena.spawn_enemy("mob", Vector2(545, 400 + row * 28.1))
			body.ai_enabled = false
			crowd.append(body)
		hits = 0
		boss.attack_player.connect(func(_damage: float) -> void: hits += 1)
		boss.charges_remaining = boss.current_phase().charge_count
		boss._start_charge_warning()
		var guard := 0
		while boss.state == "warning" and guard < 120:
			await advance()
			guard += 1
		check(boss.state == "charge", "real configured warning reaches charge state")
		if scenario == 2:
			arena.occupancy._wall(Vector2(570, 356), Vector2(100, 10))
			arena.occupancy._wall(Vector2(570, 444), Vector2(100, 10))
		arena.player.position = Vector2(550, 400) # Inside a would-be charge hit sweep.
		var hp := arena.stats.hp
		var boss_at := boss.position
		var remaining := boss.charges_remaining
		var snapshot := PackedVector2Array()
		for body in crowd: snapshot.append(body.position)
		await advance()
		check(arena.occupancy.priority_blocked_this_tick, "deliberate work/space limit reports solid blockage")
		check(boss.position == boss_at, "blocked proposal never advances boss actor")
		check(hits == 0 and arena.stats.hp == hp, "blocked proposal emits no phantom hit or HP loss")
		check(boss.charges_remaining == remaining - 1, "blocked segment consumes exactly one original combo segment")
		check(boss.state == ("warning" if scenario == 1 else "recovery"), "blocked segment follows ordinary next-warning/recovery path")
		if scenario == 1: check(absf(boss.phase_time - boss.current_phase().repeat_charge_warning) < 0.001, "repeat warning remains configured0.3s")
		for i in range(crowd.size()): check(crowd[i].position == snapshot[i], "failed side trial rolls back every passive displacement")
		for entry: Dictionary in arena.occupancy._entries.values():
			var actor: EnemyActor = entry.actor.get_ref()
			var proxy: StaticBody2D = entry.proxy
			var state: Transform2D = PhysicsServer2D.body_get_state(proxy.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM)
			check(actor.position == proxy.position and state.origin == proxy.global_position, "failed preflight leaves actor/proxy/server synchronized")
			check(proxy.collision_mask == EnemyOccupancySolver.OCCUPANCY_LAYER, "failed trial restores ordinary collision mask")
		boss.ai_enabled = false
	arena.clear_enemies()
	await advance(2)
	var body := arena.spawn_enemy("mob", Vector2(500, 400))
	var radius := body.occupancy_radius
	var hurtbox := body.radius
	body.occupancy_radius = radius + 5.0
	check(body.occupancy_configuration_rejected and body.occupancy_radius == radius, "live footprint expansion explicitly rejected")
	check(body.radius == hurtbox and arena.occupancy._entries[body.get_instance_id()].shape.radius == radius, "hurtbox unchanged and native/actor footprints share snapshot")
	arena.definition.hornling_definition.occupancy_radius = radius + 5.0
	arena.clear_enemies()
	await advance(2)
	body = arena.spawn_enemy("mob", Vector2(500, 400))
	check(body.occupancy_radius == radius + 5.0, "new spawn after reset adopts revised footprint Resource")
	print("NATIVE PRIORITY FAILURE: %d checks, %d failures" % [checks, failures])
	arena.free()
	await preload("res://tests/audio_teardown.gd").drain(self)
	quit(0 if failures == 0 else 1)
