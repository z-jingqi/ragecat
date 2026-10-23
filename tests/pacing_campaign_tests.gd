extends SceneTree
## Controlled contracts, not survival/balance evidence.
var failures := 0
var checks := 0
var victories := 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("PACING: " + label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var settings := ArenaDefinition.new()
	var d := RunDirector.new()
	d.configure(settings)
	check(is_equal_approx(d.base_spawn_interval(), 1.35), "opening cadence")
	check(not d.tick(119.0).spawn_boss and d.tick(1.0).spawn_boss, "first Boss exactly120 active seconds")
	check(not d.tick(300.0).spawn_boss, "long Boss fight never overlaps")
	d.boss_killed()
	check(d.boss_count == 1 and is_equal_approx(d.next_boss_at, 540.0), "next Boss120 after actual defeat")
	check(is_equal_approx(d.relief_remaining, 15.0), "post-Boss relief")
	check(d.spawn_interval_now() > d.base_spawn_interval(), "relief lowers arrivals without stopping")
	d.boss_killed()
	check(d.boss_count == 1, "duplicate death cannot advance director")
	check(not d.tick(119.0).spawn_boss and d.tick(1.0).spawn_boss, "second Boss relative to death, not fixed grid")
	d.configure(settings)
	check(d.elapsed == 0 and d.boss_count == 0 and not d.boss_alive and not d.endless and d.relief_remaining == 0, "configure resets complete run")
	for bad in [0.0, -1.0, INF, NAN]:
		var event := d.tick(bad)
		check(not event.spawn_mob and not event.spawn_boss and d.elapsed == 0, "invalid/zero delta is inert")
	for pair in [[44.0, 0], [45.0, 1], [149.0, 1], [150.0, 2], [255.0, 3], [360.0, 4]]:
		d.elapsed = pair[0]
		check(d.ranged_admission_limit() == pair[1], "ranged admission boundary " + str(pair[0]))
	d.boss_alive = true
	check(d.ranged_admission_limit() == 2, "Boss ranged admission cap")
	d.boss_alive = false
	d.elapsed = 600
	check(absf(d.base_spawn_interval() - 0.67218) < 0.001, "ten-minute cadence is not old spawn floor")
	check(is_equal_approx(d.mob_health_multiplier(), 3.0), "ten-minute base HP102")
	d.elapsed = 1200
	check(d.health_pressure() == 1.0, "campaign never applies optional-endless pressure")
	d.endless = true
	check(is_equal_approx(d.health_pressure(), 2.0), "20-minute provisional endless multiplier2")
	d.elapsed = 1800
	check(d.health_pressure() > 3.5, "late pressure continues past20min")
	d.elapsed = 1e30
	check(is_finite(d.mob_health_multiplier()) and d.health_pressure() <= settings.endless_health_multiplier_cap, "very long simulation remains bounded")
	d.configure(settings)
	check(d.tick(10000).spawn_mob, "one opportunity after stall")
	check(not d.tick(0.001).spawn_mob, "no spawn backlog after stall")
	d.boss_spawn_failed()
	check(not d.boss_alive and d.tick(0.001).spawn_boss, "unsafe Boss placement retries pending single encounter")
	var bad_settings := ArenaDefinition.new()
	bad_settings.spawn_ramp_time = 0
	bad_settings.pressure_period = NAN
	bad_settings.relief_initial_rate = 0
	bad_settings.spawn_position_attempts = 10000
	bad_settings.ranged_cap_period = -1
	bad_settings.endless_pressure_exponent = INF
	var safe := bad_settings.validated_copy()
	check(safe.spawn_ramp_time > 0 and is_finite(safe.pressure_period) and safe.relief_initial_rate > 0 and safe.spawn_position_attempts == 128 and safe.ranged_cap_period > 0 and is_finite(safe.endless_pressure_exponent), "resource validation covers pacing fields")
	var replay := RageArena.new()
	replay.run_seed_override = 0
	root.add_child(replay)
	replay.process_mode = Node.PROCESS_MODE_DISABLED
	var control_rng := RandomNumberGenerator.new()
	control_rng.seed = 0
	check(replay.run_seed == 0 and replay.rng.randi() == control_rng.randi(), "pre-ready seed zero is honored and offer reset consumes no combat RNG")
	var separate_offer := OfferRunState.new()
	separate_offer.reset(0)
	check(replay.offer_state.rng.state == separate_offer.rng.state, "run offers begin from reproducible separately salted seed")
	replay.offer_state.serial = 4
	replay.offer_state.misses["damage"] = 2
	var offer_snapshot := replay.offer_state.snapshot()
	replay.apply_ranks({"damage": 1})
	check(replay.offer_state.snapshot() == offer_snapshot, "stats rebuild preserves offer RNG history and pity")
	replay.run_phase = "victory"
	replay.continue_endless()
	check(replay.offer_state.snapshot() == offer_snapshot and replay.offer_context().phase == "endless", "endless continuation preserves offers and updates context")
	check(replay.offer_context().campaign_duration == replay.definition.campaign_expected_duration and replay.definition.campaign_expected_duration == 600.0, "offer timing estimate includes fights and derives from explicit resource")
	replay.queue_free()
	await process_frame
	var arena := RageArena.new()
	root.add_child(arena)
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	arena.victory_reached.connect(func(): victories += 1)
	var hp := arena.stats.hp
	var ranks := arena.ranks.duplicate(true)
	for count in range(3):
		var boss := arena.spawn_enemy("boss", arena.bounds.get_center() + Vector2(200, 0)) as Mountainbreaker
		check(boss != null, "controlled Boss spawn")
		boss.receive_damage(boss.health + 1, false)
		if count < 2: check(victories == 0 and not paused, "no early victory")
		await process_frame
	check(victories == 1 and paused and arena.run_phase == "victory", "third Boss pauses and emits victory exactly once")
	check(arena.pickups.size() == 36 and arena.director.boss_count == 3, "third Boss reward bookkeeping preserved")
	var old_elapsed := arena.director.elapsed
	var old_relief := arena.director.relief_remaining
	arena._physics_process(10)
	check(arena.director.elapsed == old_elapsed and arena.director.relief_remaining == old_relief, "victory blocks direct arena advancement")
	check(arena.continue_endless() and not arena.continue_endless(), "continue is one-way and idempotent")
	check(arena.stats.hp == hp and arena.ranks == ranks and arena.director.boss_count == 3 and arena.director.endless, "continue retains build health and Boss history")
	check(paused, "main UI owns actual resume")
	paused = false
	for count in range(3):
		var boss := arena.spawn_enemy("boss", arena.bounds.get_center() + Vector2(200, 0)) as Mountainbreaker
		boss.receive_damage(boss.health + 1, false)
		await process_frame
	check(victories == 1 and not paused and arena.run_phase == "endless", "sixth Boss does not repeat victory")
	arena.definition.spawn_player_clearance = 10000
	var child_count := arena.enemies.get_child_count()
	check(arena.spawn_enemy("mob") == null and arena.enemies.get_child_count() == child_count, "unsafe spawn skipped without leaked node")
	arena.definition.spawn_player_clearance = 180
	for corner: Vector2 in [arena.bounds.position, arena.bounds.end, arena.bounds.get_center()]:
		arena.player.position = corner
		for attempt in range(20):
			var at := arena._safe_spawn_position()
			check(not at.is_finite() or at.distance_to(corner) >= 180, "spawn clearance after clamping")
	arena.queue_free()
	await process_frame
	# Genuine synchronous damage ordering: health is zero, damaged emits player
	# death, then killed resolves. This is not damage newly applied after death.
	var terminal := RageArena.new()
	root.add_child(terminal)
	terminal.process_mode = Node.PROCESS_MODE_DISABLED
	terminal.director.boss_count = 2
	var lethal := terminal.spawn_enemy("boss", terminal.bounds.get_center())
	var late := terminal.spawn_enemy("mob", terminal.bounds.get_center())
	var later := terminal.spawn_enemy("mob", terminal.bounds.get_center())
	lethal.damaged.connect(func(_amount: float, _crit: bool, _at: Vector2): terminal._on_death())
	lethal.receive_damage(lethal.health + 1, false)
	check(terminal.finished and terminal.director.boss_count == 3 and terminal.kills == 1 and terminal.run_phase == "campaign", "reentrant death wins terminal priority without losing resolved Boss kill")
	check(terminal.progression.metrics.kills == 1 and terminal.progression.metrics.bosses == 1 and terminal.pickups.size() == 12, "terminal resolved damage retains achievement and drop credit")
	terminal._on_enemy_killed(lethal)
	late.receive_damage(late.health + 1, false)
	check(terminal.kills == 1, "duplicate killed and new same-frame postdeath damage cannot farm rewards")
	await process_frame
	later.receive_damage(later.health + 1, false)
	check(terminal.kills == 1 and not terminal._terminal_rewards_open and not terminal.progression._active, "deferred boundary closes reward credit and profile")
	terminal.queue_free()
	await process_frame
	var reverse := RageArena.new()
	root.add_child(reverse)
	reverse.process_mode = Node.PROCESS_MODE_DISABLED
	reverse.director.boss_count = 2
	var won_boss := reverse.spawn_enemy("boss", reverse.bounds.get_center())
	won_boss.receive_damage(won_boss.health + 1, false)
	reverse._on_death()
	check(reverse.finished and reverse.director.boss_count == 3 and reverse.kills == 1 and not reverse.continue_endless(), "Boss-first then player-death retains rewards but cannot continue dead run")
	paused = false
	reverse.queue_free()
	await process_frame
	print("PACING CAMPAIGN: %d checks, %d failures; controlled contracts only" % [checks, failures])
	quit(1 if failures else 0)
