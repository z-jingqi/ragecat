extends SceneTree
var checks := 0
var failed := false

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failed = true
		push_error("FAIL: " + message)

func find_button(node: Node, caption: String) -> Button:
	if node is Button and node.text == caption: return node as Button
	for child: Node in node.get_children():
		var found := find_button(child, caption)
		if found != null: return found
	return null

func press(game: Node, caption: String) -> void:
	var control := find_button(game.ui, caption)
	check(control != null, "Button exists: " + caption)
	if control != null: control.pressed.emit()

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game := load("res://scenes/main.tscn").instantiate() as Node
	root.add_child(game)
	TranslationServer.set_locale("en")
	GameLocale.refresh_tree(game)
	press(game, "PRACTICE LAB")
	await process_frame
	check(game.arena.player.movement_enabled, "Practice panel allows dedicated gameplay controls")
	press(game, "Paused")
	check(paused, "Inline time controls pause simulation")
	press(game, GameLocale.text("LAB_TIME_SLOW"))
	check(not paused and Engine.time_scale == 0.25, "Inline time controls select slow motion")
	press(game, GameLocale.text("LAB_TIME_NORMAL"))
	check(not paused and Engine.time_scale == 1.0, "Inline time controls restore normal time")
	press(game, "Charge")
	check(game.arena.boss_mode == "charge", "Inline boss controls select charge")
	press(game, "Rocks")
	check(game.arena.boss_mode == "rocks", "Inline boss controls select rocks")
	press(game, GameLocale.text("LAB_ALTERNATE"))
	check(game.arena.boss_mode == "alternate", "Inline boss controls restore alternate")
	for i in range(12):
		press(game, "Shield + critical")
		press(game, GameLocale.text("NAME_MOUNTAINBREAKER"))
		press(game, GameLocale.text("LAB_SPAWN_BOSS"))
		game.arena.player.invulnerable = false
		game.arena.player.receive_hit(10.0)
		press(game, "Refill shield")
		press(game, "Reset lab")
		await process_frame
		check(game.arena.practice and game.arena.enemies.get_child_count() == 0, "Reset clears actual UI-created lab")
		check(game.arena.stats.shields == 0 and game.arena.hits == 0, "Reset clears build and metrics")
		game.show_pause()
		press(game, "RESUME")
		await process_frame
		check(game.current_mode == "practice_ui" and not paused, "Resume button restores practice")
	game.arena.player.invulnerable = false
	game.arena.player.receive_hit(10000.0)
	await process_frame
	check(game.current_mode == "practice_ui" and not paused, "Practice death automatically restarts")
	check(game.arena.stats.hp == game.arena.stats.max_hp, "Practice restart restores full HP")
	game.show_pause()
	press(game, "MAIN MENU")
	await process_frame
	press(game, "Start Run")
	await process_frame
	game.arena.player.receive_hit(10000.0)
	press(game, "ONE MORE RUN")
	await process_frame
	check(game.current_mode == "campaign" and not game.arena.practice and not paused, "Endless death button preserves endless mode")
	game.show_upgrades()
	var box: Node = game.overlay.get_node("ModalScroll/ModalContent")
	for child: Node in box.get_children():
		if child is Button:
			child.pressed.emit()
			break
	await process_frame
	check(game.current_mode == "campaign" and not paused, "Upgrade button resumes safely")
	game.show_pause()
	press(game, "MAIN MENU")
	await process_frame
	check(game.current_mode == "menu" and game.arena == null, "Menu button retires arena")
	game.queue_free()
	await process_frame
	print("%s: %d UI lifecycle checks" % ["FAIL" if failed else "PASS", checks])
	await preload("res://tests/audio_teardown.gd").drain(self)
	quit(1 if failed else 0)
