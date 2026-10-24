extends SceneTree
var checks := 0
var failures := 0
var arena: RageArena
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("NATIVE LIFECYCLE FAIL: " + label)
func advance(count: int = 2) -> void:
	for i in range(count):
		await physics_frame
		await process_frame
func run() -> void:
	arena = RageArena.new()
	arena.practice = true
	arena.run_seed_override = 0
	arena.lab_ai = false
	arena.sound_enabled = false
	root.add_child(arena)
	arena.process_mode = Node.PROCESS_MODE_PAUSABLE
	arena.set_process(false)
	arena.set_physics_process(false)
	arena.bow.enabled = false
	# This isolated harness does not execute the main-scene InputMap bootstrap.
	# Player input is unrelated; enemy/service callbacks remain real and active.
	arena.player.set_physics_process(false)
	var a := arena.spawn_enemy("mob", Vector2(400, 400))
	var b := arena.spawn_enemy("mob", Vector2(400, 400))
	check(a != null and b != null, "samepoint admission keeps both actors")
	check(a.position.distance_to(b.position) >= a.occupancy_radius + b.occupancy_radius, "samepoint admission is separate from motion recovery")
	await advance()
	check(arena.occupancy._entries.size() == 2, "two live native proxies")
	var dead_id := a.get_instance_id()
	a.receive_damage(99999)
	await advance()
	check(not arena.occupancy._entries.has(dead_id), "death retires collision proxy")
	b.queue_free()
	await advance()
	check(arena.occupancy._entries.is_empty(), "external free retires collision proxy")
	var frozen := arena.spawn_enemy("mob", Vector2(500, 400))
	frozen.status.frozen_remaining = 1.0
	frozen.knockback(Vector2.RIGHT, 100)
	var from := frozen.position
	await advance(3)
	check(frozen.status.is_frozen() and frozen.position.distance_to(from) > 0.1, "frozen body still accepts external knockback")
	check(frozen.occupancy_locomotion_displacement(Vector2.ZERO) == Vector2.ZERO, "passive-only motion does not advance locomotion")
	var paused_at := frozen.position
	var paused_clock := frozen.status.frozen_remaining
	paused = true
	await advance(3)
	check(frozen.position == paused_at and frozen.status.frozen_remaining == paused_clock, "pause stops proxy and actor clocks together")
	paused = false
	arena.clear_enemies()
	await advance()
	check(arena.occupancy._entries.is_empty() and arena.occupancy._walls.is_empty(), "practice clear resets actor and wall proxies")
	var boss := arena.spawn_enemy("beastcaller", Vector2(200, 200)) as Beastcaller
	boss.ai_enabled = false
	check(boss._start_summon(), "phase1 reserves a legal complete cluster before warning")
	var warned: Array[Vector2] = boss.summon_positions.duplicate()
	check(warned.size() == 3, "phase1 retains all3 clustered points")
	if warned.size() == 3:
		check(absf(warned[0].distance_to(warned[1]) - sqrt(3.0) * boss.boss_definition.summon_cluster_radius) < 0.01, "cluster is translated as a whole, not scattered")
	var reserved: Dictionary = arena.occupancy._reservations.get(boss.get_instance_id(), {})
	var rids: Array[RID] = []
	if not reserved.is_empty():
		for proxy: StaticBody2D in reserved.proxies:
			rids.append(proxy.get_rid())
			check(proxy.collision_layer == EnemyOccupancySolver.OCCUPANCY_LAYER, "reservation has only enemy occupancy layer")
			var state: Transform2D = PhysicsServer2D.body_get_state(proxy.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM)
			check(state.origin == proxy.global_position, "reservation is immediately registered at visible warning point")
	arena._commit_summons(boss)
	check(arena.occupancy._reservations.is_empty(), "commit consumes reservation ownership")
	var elites: Array[EnemyActor] = []
	for actor in arena.enemies.get_children():
		if actor is EliteHornling: elites.append(actor)
	check(elites.size() == 3, "commit creates whole3 batch")
	for i in range(elites.size()):
		check(elites[i].position == warned[i], "landing equals warning, without late relocation")
		var entry: Dictionary = arena.occupancy._entries[elites[i].get_instance_id()]
		check(entry.proxy.get_rid() == rids[i], "same native RID transferred with no occupancy gap")
	check(boss._start_summon(), "second warning can reserve a new complete batch")
	arena._cancel_summons(boss)
	check(arena.occupancy._reservations.is_empty() and arena._summon_reservations.is_empty(), "explicit cancellation releases both capacity and physics ownership")
	check(boss._start_summon(), "third warning can reserve after cancellation")
	boss.receive_damage(99999)
	await advance()
	check(arena.occupancy._reservations.is_empty(), "boss death cancels reservation atomically")
	arena.clear_enemies()
	await advance()
	arena.player.position = arena.bounds.get_center()
	boss = arena.spawn_enemy("beastcaller", Vector2(200, 200)) as Beastcaller
	boss.ai_enabled = false
	boss.force_phase_for_practice(2)
	check(boss._start_summon(), "phase2 reserves uniform ring")
	warned.assign(boss.summon_positions)
	check(warned.size() == 8, "centered phase2 retains8 slots")
	for at in warned:
		check(absf(at.distance_to(arena.player.position) - boss.boss_definition.summon_ring_radius) < 0.01, "ring uses player snapshot center and authored radius")
	arena.clear_enemies()
	await advance()
	check(arena.occupancy._reservations.is_empty() and arena.occupancy._entries.is_empty(), "reset releases live and reserved proxies")
	print("NATIVE LIFECYCLE: %d checks, %d failures" % [checks, failures])
	arena.free()
	await preload("res://tests/audio_teardown.gd").drain(self)
	quit(0 if failures == 0 else 1)
