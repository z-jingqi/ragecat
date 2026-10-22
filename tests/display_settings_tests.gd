extends SceneTree
var failures: int = 0
var checks: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func run() -> void:
	var test_path := "user://display-contract-test.cfg"
	var settings := DisplaySettings.new()
	settings.load_settings(test_path + ".missing")
	check(settings.show_enemy_health, "missing settings defaults on")
	var file := FileAccess.open(test_path, FileAccess.WRITE)
	file.store_string("invalid [ config")
	file.close()
	settings.load_settings(test_path)
	check(settings.show_enemy_health, "corrupt settings defaults on")
	var config := ConfigFile.new()
	config.set_value("display", "enemy_health_bars", "not a bool")
	config.save(test_path)
	settings.load_settings(test_path)
	check(settings.show_enemy_health, "wrong type defaults on")
	settings.show_enemy_health = false
	check(settings.save_settings(test_path) == OK, "cosmetic preference writes")
	var reload := DisplaySettings.new()
	reload.load_settings(test_path)
	check(not reload.show_enemy_health, "cosmetic preference survives reload")
	DirAccess.remove_absolute(test_path)
	# Preserve caller's real display setting around main-menu wiring tests.
	var had_file := FileAccess.file_exists(DisplaySettings.PATH)
	var original := FileAccess.get_file_as_bytes(DisplaySettings.PATH) if had_file else PackedByteArray()
	var game := load("res://scenes/main.tscn").instantiate() as Node
	root.add_child(game)
	game.start_run(true)
	var arena: RageArena = game.arena
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	var mob := arena.spawn_enemy("mob")
	var ranged := arena.spawn_enemy("ranged")
	var boss := arena.spawn_enemy("boss")
	game.show_pause()
	var toggle: CheckButton
	for child in game.overlay.get_child(1).get_children():
		if child is CheckButton: toggle = child
	check(toggle != null and toggle.focus_mode == Control.FOCUS_NONE, "pause toggle avoids movement focus capture")
	toggle.button_pressed = true
	check(mob.health_bar_visible() and ranged.health_bar_visible() and boss.health_bar_visible(), "on shows all bars including full HP")
	toggle.button_pressed = false
	check(not mob.health_bar_visible() and not ranged.health_bar_visible(), "off hides melee and ranged")
	check(boss.health_bar_visible(), "boss always visible")
	var before := arena.effects.get_child_count()
	mob.receive_damage(2)
	check(arena.effects.get_child_count() > before, "HP toggle never hides damage floats")
	var later := arena.spawn_enemy("ranged")
	check(not later.health_bar_visible(), "new spawn inherits current display preference")
	game.resume_run()
	game.start_run(false)
	check(not game.arena.show_enemy_health, "restart/mode change preserves cosmetic setting")
	reload.load_settings()
	check(not reload.show_enemy_health, "actual UI toggle persisted")
	game.show_menu()
	game.free()
	if had_file:
		file = FileAccess.open(DisplaySettings.PATH, FileAccess.WRITE)
		file.store_buffer(original)
		file.close()
	else: DirAccess.remove_absolute(DisplaySettings.PATH)
	paused = false
	await process_frame
	print("DISPLAY SETTINGS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
