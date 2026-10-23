extends SceneTree
## Controlled accelerated soak, not a claim of a normal-difficulty human win.
var failed := false
var checks := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failed = true
		push_error("FAIL: " + message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game := load("res://scenes/main.tscn").instantiate() as Node
	root.add_child(game)
	game.start_run(false)
	game.catalog.all_unlocked = true # Full-catalog UI fixture.
	game.process_mode = Node.PROCESS_MODE_DISABLED
	var arena: RageArena = game.arena
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	arena.rng.seed = 7319
	arena.player.invulnerable = true
	arena.player.movement_enabled = false
	var ranks: Dictionary = {}
	for key: String in game.catalog.definitions:
		ranks[key] = game.catalog.definitions[key].values.size() - 1
	arena.apply_ranks(ranks)
	var saw_boss := false
	var upgrades := 0
	var peak_enemies := 0
	var peak_pickups := 0
	var peak_effects := 0
	var peak_arrows := 0
	for frame in range(10800):
		var delta := 1.0 / 30.0
		arena._physics_process(delta)
		if game.current_mode == "upgrade":
			for child: Node in game.overlay.get_node("ModalScroll/ModalContent").get_children():
				if child is Button:
					child.pressed.emit()
					upgrades += 1
					break
		arena.player._physics_process(delta)
		arena.bow._physics_process(delta)
		for enemy: Node in arena.enemies.get_children():
			if enemy is BossActor: saw_boss = true
			if not enemy.is_queued_for_deletion():
				enemy._physics_process(delta)
				for child: Node in enemy.get_children():
					if child is RockWarning and not child.is_queued_for_deletion():
						child._physics_process(delta)
		for arrow: Node in arena.arrows.get_children():
			if not arrow.is_queued_for_deletion(): arrow._physics_process(delta)
		for effect: Node in arena.effects.get_children():
			if not effect.is_queued_for_deletion(): effect._process(delta)
		peak_enemies = maxi(peak_enemies, arena.enemies.get_child_count())
		peak_pickups = maxi(peak_pickups, arena.pickups.size())
		peak_effects = maxi(peak_effects, arena.effects.get_child_count())
		peak_arrows = maxi(peak_arrows, arena.arrows.get_child_count())
		await process_frame
	check(saw_boss, "Continuous clock naturally reaches first boss")
	check(arena.director.boss_count >= 2, "Multiple boss death/next-spawn cycles complete")
	check(arena.director.elapsed > 350.0, "Six simulated minutes remain live")
	check(peak_enemies <= 70, "Long-run enemy cap respected")
	check(peak_pickups <= 250, "Long-run pickup cap respected")
	check(peak_effects <= 73, "Long-run floating effects bounded")
	check(not arena.finished, "Controlled invulnerability remains alive")
	print("ENDLESS SOAK: %d checks, elapsed=%.1f bosses=%d kills=%d upgrades=%d" % [checks, arena.director.elapsed, arena.director.boss_count, arena.kills, upgrades])
	print("SOAK PEAKS: enemies=%d pickups=%d effects=%d arrows=%d" % [peak_enemies,peak_pickups,peak_effects,peak_arrows])
	game.queue_free()
	await process_frame
	quit(1 if failed else 0)
