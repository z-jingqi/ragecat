extends SceneTree
var arena: RageArena
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("NATIVE RESERVATION FAIL: " + label)
func advance(count: int = 2) -> void:
	for i in range(count):
		await physics_frame
		await process_frame
func make_boss() -> Beastcaller:
	var boss := arena.spawn_enemy("beastcaller", Vector2(200, 200)) as Beastcaller
	boss.ai_enabled = false
	return boss
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
	arena.player.invulnerable = true
	arena.bow.enabled = false
	var boss := make_boss()
	arena.definition.enemy_limit = 4
	check(boss._start_summon(), "whole3 reservation fits final capacity4")
	check(arena._reserved_summon_count() == 3, "all capacity claimed during warning")
	check(arena.spawn_enemy("mob", Vector2(700, 400)) == null, "ordinary spawn cannot steal reserved capacity")
	arena.definition.enemy_limit = 2
	boss.ai_enabled = true
	await advance(ceili(boss.current_phase().summon_warning * 60.0) + 2)
	check(arena.enemies.get_child_count() == 1, "capacity shrink aborts complete landing, never half a batch")
	check(arena.occupancy._reservations.is_empty() and arena._summon_reservations.is_empty(), "aborted real warning releases all occupancy and capacity")
	arena.definition.enemy_limit = 72
	boss.ai_enabled = false
	check(boss._start_summon(), "new warning after aborted landing")
	boss.force_phase_for_practice(2)
	check(arena.occupancy._reservations.is_empty() and arena._summon_reservations.is_empty(), "phase change cancels both representations")
	check(boss._start_summon(), "phase2 warning before owner free")
	boss.queue_free()
	await advance()
	check(arena._reserved_summon_count() == 0 and arena.occupancy._reservations.is_empty(), "external owner free cannot leak ghost capacity or native blockers")
	arena.clear_enemies()
	await advance()
	boss = make_boss()
	var ordinary := arena.spawn_enemy("mob", Vector2(500, 400))
	var points: Array[Vector2] = [ordinary.position, Vector2(600, 400), Vector2(650, 400)]
	check(not arena._reserve_summons(points, boss), "occupied whole batch is rejected without deleting its blocker")
	check(not ordinary.is_dead and arena.enemies.get_child_count() == 2, "failed reservation preserves existing actors")
	check(arena.occupancy._reservations.is_empty() and arena._summon_reservations.is_empty(), "rejected batch leaves no partial reservation")
	arena.clear_enemies()
	await advance()
	boss = arena.spawn_enemy("beastcaller", Vector2(900, 100)) as Beastcaller
	boss.ai_enabled = false
	arena.player.position = Vector2(45, 400)
	boss.force_phase_for_practice(2)
	check(boss._start_summon(), "near-edge ring reserves every in-map survivor as one batch")
	var edge_points: Array[Vector2] = boss.summon_positions.duplicate()
	check(edge_points.size() > 0 and edge_points.size() < 8, "authored out-of-map omission is retained, not arbitrary blocked-slot omission")
	for at in edge_points:
		var relative := at - arena.player.position
		check(absf(relative.length() - boss.boss_definition.summon_ring_radius) < 0.01, "edge survivors keep the common player snapshot/radius")
		check(absf(wrapf(relative.angle(), 0.0, TAU) / (PI / 4.0) - roundf(wrapf(relative.angle(), 0.0, TAU) / (PI / 4.0))) < 0.001, "edge survivors remain points of the same uniform8 lattice")
	arena._cancel_summons(boss)
	ordinary = arena.spawn_enemy("mob", edge_points[0])
	check(not arena._reserve_summons(edge_points, boss), "one occupied surviving ring point rejects the complete survivor batch")
	check(arena.occupancy._reservations.is_empty() and not ordinary.is_dead, "failed edge reservation neither drops blocked slots nor deletes existing enemies")
	var old_bounds := boss.arena_bounds
	boss.arena_bounds = Rect2(0, 0, 100, 100)
	arena.player.position = Vector2(50, 50)
	boss.force_phase_for_practice(1)
	check(not boss._start_summon() and boss.summon_positions.is_empty() and boss.state != "summon", "zero-space phase1 fails before creating a warning, no deferred queue")
	boss.force_phase_for_practice(2)
	check(not boss._start_summon() and boss.summon_positions.is_empty(), "out-of-map ring points preserve omission policy and create no empty warning")
	boss.arena_bounds = old_bounds
	arena.clear_enemies()
	await advance()
	check(arena.occupancy._entries.is_empty() and arena.occupancy._reservations.is_empty(), "final reset has no actor or reservation proxies")
	print("NATIVE RESERVATION: %d checks, %d failures" % [checks, failures])
	arena.free()
	await preload("res://tests/audio_teardown.gd").drain(self)
	quit(0 if failures == 0 else 1)
