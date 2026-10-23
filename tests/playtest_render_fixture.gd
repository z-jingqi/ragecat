extends SceneTree
## Real rendering of the live lab and actor-independent red health palette.
var output := "user://playtest-render"
var checks := 0
var failures := 0
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
func settle() -> void:
	for i in range(10): await process_frame
func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(name + ".png")) == OK, "Capture " + name)
func run() -> void:
	check(DisplayServer.get_name() != "headless", "Fixture requires actual renderer")
	if failures: quit(1); return
	DirAccess.make_dir_recursive_absolute(output)
	var prefs := DisplaySettings.new()
	prefs.sound_enabled = false
	prefs.save_settings()
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await settle()
	for resolution in [Vector2i(960, 600), Vector2i(1280, 800)]:
		game.window_settings.begin_preview(WindowSettingsController.WINDOWED, resolution)
		await settle()
		game.window_settings.confirm_preview()
		for locale in ["en", "zh_CN"]:
			game.set_language(locale)
			game.start_run(true)
			game.arena.bow.enabled = false
			await settle()
			var prefix := "%s_%dx%d" % [locale, resolution.x, resolution.y]
			check(game.lab.visible and not paused, "Initial panel is visible and live")
			check(Rect2(0,0,1280,800).encloses(game.lab.get_global_rect()), "Panel fits logical viewport")
			await capture(prefix + "_expanded")
			game.practice_command("spawn_ranged")
			game.practice_option("enemy_ai", true)
			var enemy: EnemyActor = game.arena.enemies.get_child(0)
			enemy.position = Vector2(1150, 400)
			var before := enemy.position
			for i in range(12): await physics_frame
			check(enemy.position.x < before.x, "Spawned ranged starts moving before closing panel")
			game.combat_hud.practice_button.pressed.emit()
			check(not game.lab.visible and not paused, "One-click collapse removes controls without pause modal")
			game.arena.set_enemy_ai(false)
			game.arena.clear_enemies()
			for i in range(4):
				var actor: EnemyActor = game.arena.spawn_enemy(["mob", "ranged", "swiftfang", "elite_hornling"][i], Vector2(340 + 180 * i, 330))
				actor.health = actor.max_health * 0.55
				actor.queue_redraw()
			var boss: BossActor = game.arena.spawn_enemy("beastcaller", Vector2(640, 500))
			boss.health = boss.max_health * 0.65
			game.update_hud()
			await settle()
			await capture(prefix + "_health")
			game.combat_hud.practice_button.pressed.emit()
			await settle()
			check(game.lab.visible and game.overlay == null, "Direct re-open leaves no pause modal")
			game.lab.find_child("CollapsePractice", true, false).pressed.emit()
			check(not game.lab.visible and game.arena.player.movement_enabled, "Panel X returns gameplay input")
			game.show_menu()
	game.queue_free()
	await settle()
	print("PLAYTEST RENDER: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
