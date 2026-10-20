extends SceneTree
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game := load("res://scenes/main.tscn").instantiate() as Node
	root.add_child(game)
	game.start_run(true)
	var arena: RageArena = game.arena
	arena.set_physics_process(false)
	arena.bow.enabled = false
	var target := arena.spawn_enemy("dummy")
	target.set_physics_process(false)
	var before := target.health
	target.status.apply_poison(10.0, 2.0)
	target.status.apply_bleed(6.0, 2.0)
	target._physics_process(0.5)
	check(is_equal_approx(before - target.health, 8.0), "Combined DOT deals known health loss")
	check(is_equal_approx(arena.total_damage, 8.0), "DAMAGE includes poison and bleed ticks")
	target.receive_damage(12.0, true)
	check(is_equal_approx(arena.total_damage, 20.0), "Total combines direct and DOT once")
	target.health = 3.0
	target.receive_damage(100.0)
	check(is_equal_approx(arena.total_damage, 23.0), "Total counts effective health lost, not overkill")
	game.update_hud()
	check("APPS" in game.lab._metrics.text, "Status application counters are explicitly labeled")
	var player := arena.player
	player.invulnerable = false
	arena.stats.shield_capacity = 2
	arena.stats.shields = 2
	var hp_before := arena.stats.hp
	player.receive_hit(10.0)
	check(player.get("impact_kind") == "block", "Shield absorption has distinct field feedback")
	check(arena.stats.hp == hp_before and arena.stats.shields == 1, "Shield blocks without HP loss")
	player.health_state.tick(0.5)
	player.receive_hit(10.0)
	check(player.get("impact_kind") == "break", "Final shield has distinct break feedback")
	player.health_state.tick(0.5)
	player.receive_hit(10.0)
	check(player.get("impact_kind") == "hurt", "HP damage has distinct hurt feedback")
	check(arena.stats.hp == hp_before - 10.0, "Feedback preserves actual health damage")
	var effect_count := arena.effects.get_child_count()
	player.receive_hit(10.0)
	check(arena.effects.get_child_count() == effect_count, "Immunity does not repeat impact text")
	check(player.z_index > arena.enemies.z_index, "Player remains visible above enemies")
	arena.stats.hp = 60.0
	var healed_before := player.healed_total
	game.practice_command("heal")
	check(is_equal_approx(player.healed_total - healed_before, 40.0), "Lab Heal contributes actual restored HP to HEAL")
	game.practice_command("heal")
	check(is_equal_approx(player.healed_total - healed_before, 40.0), "Heal at full health adds no phantom healing")
	arena.stats.hp = 90.0
	game.choose_upgrade("heal")
	check(is_equal_approx(player.healed_total - healed_before, 50.0), "Cat Nap counts capped restoration, not nominal healing")
	game.queue_free()
	await process_frame
	print("FEEDBACK TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
