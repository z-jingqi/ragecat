extends SceneTree
## Exercise selectors through the real main scene, including paused replacement.
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
func run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var game := scene.instantiate()
	root.add_child(game)
	await process_frame
	check(game.has_method("start_run"), "Main script loaded")
	if not game.has_method("start_run"):
		quit(1)
		return
	game.start_run(true)
	await process_frame
	game.enter_practice_navigation()
	check(paused, "Practice controller menu pauses simulation")
	for identity in ["mountainbreaker", "beastcaller", "wildfire"]:
		game.practice_option("boss_identity", identity)
		for phase in [1, 2]:
			game.practice_option("boss_phase", phase)
			game.practice_command("spawn_boss")
			await process_frame
			var bosses: Array = []
			for enemy in game.arena.enemies.get_children():
				if enemy is BossActor: bosses.append(enemy)
			check(bosses.size() == 1, "Exactly one practice boss after replacement")
			if bosses.size() == 1:
				check(bosses[0].boss_identity == identity, "Selected boss identity " + identity)
				check(bosses[0].phase_number == phase, "Selected phase immediately applied")
			check(paused, "Changing boss/phase does not resume gameplay")
	game.practice_command("spawn_swiftfang")
	game.practice_command("spawn_elite_hornling")
	await process_frame
	check(game.arena.enemies.get_child_count() == 3, "New mob practice commands spawn alongside boss")
	game.practice_command("clear")
	await process_frame
	check(game.arena.enemies.get_child_count() == 0, "Clear removes practice actors")
	game.start_run(true)
	await process_frame
	check(game.arena.practice_boss_identity == "mountainbreaker" and game.arena.practice_boss_phase == 1, "Practice selectors reset with new lab run")
	game.queue_free()
	paused = false
	await process_frame
	print("PRACTICE BOSS INTEGRATION: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
