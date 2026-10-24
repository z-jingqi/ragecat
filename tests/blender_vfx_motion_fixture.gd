extends SceneTree
## Deterministic motion proof using live production actors, bows and hazard nodes.
## Run on a real rendering display, not headless. No outputs belong in the repo.
## --capture-dir=/tmp/vfx-motion --size=960x600 --fps=24 [--section=fire]
## Encode: ffmpeg -framerate 24 -i /tmp/vfx-motion/frame_%04d.png -pix_fmt yuv420p preview.mp4
var output := "/tmp/vfx-motion"
var capture_size := Vector2i(960, 600)
var fps := 24
var only_section := ""
var frame_number := 0
var game: Node
var arena: RageArena
var marker: Label
var active_boss: BossActor
var sample_enemies: Array[EnemyActor] = []
var shatter_done := false
const SECTIONS := ["fire", "lightning", "ice", "dark", "charge", "rocks", "summon", "orb", "skyfire", "ring"]

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
		elif arg.begins_with("--fps="): fps = clampi(int(arg.trim_prefix("--fps=")), 12, 60)
		elif arg.begins_with("--section="): only_section = arg.trim_prefix("--section=")
		elif arg.begins_with("--size="):
			var parts := arg.trim_prefix("--size=").split("x")
			if parts.size() == 2: capture_size = Vector2i(int(parts[0]), int(parts[1]))
	call_deferred("run")

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Motion fixture needs a rendering display; headless is not visual proof.")
		quit(1)
		return
	if not output.begins_with("/tmp/"):
		push_error("Motion capture output must be under /tmp, never inside the repository.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_language("en")
	game.start_run(true, 72103)
	game.return_from_practice_navigation()
	game.window_settings.begin_preview(WindowSettingsController.WINDOWED, capture_size)
	while game.window_settings.apply_pending:
		await process_frame
	game.window_settings.confirm_preview()
	if root.size != capture_size:
		push_error("Native capture size was not applied")
		quit(1)
		return
	arena = game.arena
	arena.set_sound_enabled(false)
	arena.player.invulnerable = true
	arena.player.movement_enabled = false
	paused = true
	var layer := CanvasLayer.new()
	root.add_child(layer)
	marker = Label.new()
	marker.position = Vector2(24, 100)
	marker.add_theme_font_size_override("font_size", 16)
	layer.add_child(marker)
	for section: String in SECTIONS:
		if not only_section.is_empty() and section != only_section: continue
		await reset_section(section)
		var seconds := 2.0 if section in ["fire", "lightning", "ice", "dark"] else 2.8
		for index in range(ceili(seconds * fps)):
			var time := float(index) / fps
			if section == "rocks" and time > 0.25:
				arena.player.position.x += 85.0 / fps
				arena.player.queue_redraw()
			if section == "ice" and time >= 0.42 and not shatter_done:
				shatter_done = true
				var arrow := BowArrow.new()
				# Actual direct-hit path consumes freeze and emits the production shatter.
				arena._on_arrow_hit(arrow, sample_enemies[0])
				arrow.free()
			# Use fixed 120 Hz substeps, independent of render or PNG write speed.
			var substeps := maxi(1, int(ceil(120.0 / fps)))
			for _step in range(substeps):
				manual_tick(arena, 1.0 / fps / substeps, true)
			manual_tick(arena, 1.0 / fps, false)
			game.update_hud()
			await process_frame
			await RenderingServer.frame_post_draw
			var result := root.get_texture().get_image().save_png(output.path_join("frame_%04d.png" % frame_number))
			if result != OK:
				push_error("Capture failed: " + error_string(result))
				quit(1)
				return
			frame_number += 1
	print("VFX MOTION CAPTURE: %d frames, %d fps, %s, production nodes and fixed game delta" % [frame_number, fps, capture_size])
	game.show_menu()
	game.queue_free()
	layer.queue_free()
	await process_frame
	await process_frame
	quit(0)

func manual_tick(node: Node, delta: float, physics: bool) -> void:
	if not is_instance_valid(node) or node.is_queued_for_deletion(): return
	# Do not run the arena director, upgrades or player input in this fixture.
	if node != arena and node != arena.player:
		var method := "_physics_process" if physics else "_process"
		if node.has_method(method): node.call(method, delta)
	for child in node.get_children(): manual_tick(child, delta, physics)

func reset_section(section: String) -> void:
	arena.clear_enemies()
	arena.element_procs.clear()
	arena.bow.remove_gravity(true)
	for container: Node in [arena.arrows, arena.enemy_bullets, arena.effects]:
		for child in container.get_children():
			container.remove_child(child)
			child.queue_free()
	await process_frame
	arena.player.position = Vector2(390, 400)
	arena.player.queue_redraw()
	arena.apply_ranks({})
	arena.bow.enabled = false
	arena.bow.attack_clock = 0.0
	arena.bow.burst_clock = 0.0
	arena.bow.burst_remaining = 0
	active_boss = null
	sample_enemies.clear()
	shatter_done = false
	marker.text = "Controlled production VFX: " + section.capitalize()
	if section in ["fire", "lightning", "ice", "dark"]:
		var ranks := {section + "_enchant": 3, section + "_bow": 3}
		if section in ["fire", "lightning"]:
			ranks["burst"] = 3
			ranks["spread_arrow"] = 2
		arena.apply_ranks(ranks)
		for index in range(9 if section != "ice" else 2):
			var at := Vector2(620 + index % 3 * 65, 335 + index / 3 * 65)
			if section == "ice": at = Vector2(640 + index * 150, 400)
			var enemy := arena.spawn_enemy("mob", at)
			enemy.ai_enabled = false
			enemy.health = 100000
			enemy.max_health = 100000
			enemy.show_health_bar = false
			sample_enemies.append(enemy)
		arena.bow.enabled = section != "ice"
		if section == "ice":
			for enemy in sample_enemies:
				for _hit in range(arena.stats.element_skill.frost_threshold): enemy.status.apply_ice(arena.stats.element_skill, arena.stats.element_skill_rank)
		return
	arena.set_enemy_ai(true)
	arena.player.position = Vector2(780, 420)
	var identity := "mountainbreaker" if section in ["charge", "rocks"] else ("beastcaller" if section in ["summon", "orb"] else "wildfire")
	active_boss = arena.spawn_enemy(identity, Vector2(390, 390)) as BossActor
	active_boss.ai_enabled = true
	active_boss.force_phase_for_practice(2)
	active_boss.health = active_boss.max_health
	match section:
		"charge": (active_boss as Mountainbreaker)._start_charge_warning()
		"rocks": (active_boss as Mountainbreaker)._start_rocks()
		"summon": (active_boss as Beastcaller)._start_summon()
		"orb": (active_boss as Beastcaller)._start_projectile()
		"skyfire":
			var boss := active_boss as Wildfire
			boss.skyfires_remaining = boss.boss_definition.skyfire_count
			boss._next_skyfire()
		"ring": (active_boss as Wildfire)._start_rings()
