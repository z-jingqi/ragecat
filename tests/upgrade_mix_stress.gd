extends SceneTree
## Controlled all-rank fixture, NOT normal difficulty. Disable automatic ticking;
## advance actual bow/projectile/status callbacks with explicit game-time steps.
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	for delta: float in [1.0/60.0,1.0/30.0,0.07]:
		var arena := RageArena.new()
		arena.practice = true
		root.add_child(arena)
		arena.process_mode = Node.PROCESS_MODE_DISABLED
		var ranks: Dictionary = {}
		for key: String in UpgradeCatalog.new().definitions: ranks[key]=3
		arena.apply_ranks(ranks)
		arena.stats.shields=3
		arena.rng.seed=2041
		for i in range(48):
			arena.spawn_enemy("dummy",arena.player.position+Vector2.RIGHT.rotated(i*TAU/48)*180)
		var primary_peak := 0
		var secondary_peak := 0
		var duration := 0.0
		while duration < 30.0:
			var step := minf(delta,30.0-duration)
			arena.bow._physics_process(step)
			for node in arena.arrows.get_children():
				if node is BowArrow: node._physics_process(step)
			for node in arena.enemies.get_children():
				if node is EnemyActor: node._physics_process(step)
			for node in arena.effects.get_children():
				if node is FloatingText: node._process(step)
			primary_peak=maxi(primary_peak,arena.bow.active_count(false))
			secondary_peak=maxi(secondary_peak,arena.bow.active_count(true))
			check(primary_peak<=BowController.PRIMARY_LIMIT and secondary_peak==0,"all-rank live projectiles respect primary budget and never spawn secondary arrows")
			for node in arena.arrows.get_children():
				if node is BowArrow:
					check(node.traveled<=node.max_range+0.001,"all mixed arrows keep absolute range")
			# Flush queue_free without letting any gameplay auto-process.
			await process_frame
			duration += step
		check(arena.hits>100 and int(arena.element_procs.proc_counts.fire)>0,"mixed burst/fan actually exercises direct hits and fire blasts")
		check(secondary_peak==0,"mixed fixture creates no impact projectiles")
		print("UPGRADE MIX dt=%s game_seconds=%.2f hits=%d primary_peak=%d secondary_peak=%d" % [delta,duration,arena.hits,primary_peak,secondary_peak])
		arena.free()
		await process_frame
	print("UPGRADE MIX: %d bounded-frame checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
