extends SceneTree
## Bounded event storm: report timing, assert workload/memory budgets, not a
## hardware-dependent FPS promise. All transient metrics go to stdout only.
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var arena := RageArena.new()
	arena.practice = true
	root.add_child(arena)
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	arena.bow.enabled = false
	var targets: Array[EnemyActor] = []
	for i in range(69):
		var enemy := arena.spawn_enemy("mob", Vector2(100 + (i % 10) * 65, 170 + (i / 10) * 65))
		enemy.health = 100000
		targets.append(enemy)
	var peak_visuals := 0
	var peak_popups := 0
	var damage_before := arena.total_damage
	var work_usec := 0
	for frame in range(120):
		var before := Time.get_ticks_usec()
		for index in range(300):
			var enemy := targets[index % targets.size()]
			var event := FeedbackEvent.impact(FeedbackEvent.Source.DIRECT, enemy.position, Vector2.RIGHT)
			arena.deal_damage_packet(enemy,{"damage":1.0,"base_damage":0.5,"elemental_damage":0.5,"element":"ice","crit":index%5==0},event)
			if index % 5 == 0: arena.feedback.status_event("shatter", enemy.position)
		peak_visuals = maxi(peak_visuals, arena.feedback.visuals.get_child_count())
		peak_popups = maxi(peak_popups, arena.effects.get_child_count())
		for enemy in targets: enemy._physics_process(1.0/60.0)
		for visual in arena.feedback.visuals.get_children(): visual._process(1.0/60.0)
		for popup in arena.effects.get_children(): popup._process(1.0/60.0)
		work_usec += Time.get_ticks_usec() - before
		await process_frame
	check(is_equal_approx(arena.total_damage-damage_before,36000),"36000 storm hits retain all damage")
	check(peak_visuals <= arena.feedback.definition.visual_limit,"all shared burst families obey one budget")
	check(peak_popups <= arena.definition.effect_limit,"existing B/E popup budget remains bounded")
	check(arena.feedback.dropped_visuals > 30000,"saturation drops cosmetics rather than queuing")
	check(arena.feedback.audio.active_voice_count() <= 8,"audio capacity stays bounded independently")
	arena.clear_enemies()
	check(arena.feedback.visuals.get_child_count() == 0,"storm reset clears cosmetic nodes")
	arena.free()
	await preload("res://tests/audio_teardown.gd").drain(self)
	print("FEEDBACK PERFORMANCE: %d checks, %d failures; 36000 hits, visual peak %d, popup peak %d, CPU %.3f ms/frame" % [checks,failures,peak_visuals,peak_popups,float(work_usec)/120000.0])
	quit(1 if failures else 0)
