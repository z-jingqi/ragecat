extends SceneTree
## Controlled real-render preview of the production damage popup path.
## Pass --output=/tmp/damage-palette.png; images never belong in the repository.
var arena: RageArena
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1280, 800)
	root.content_scale_size = Vector2i(1280, 800)
	root.title = "Damage palette preview"
	arena = RageArena.new()
	# Normal-width arena, with simulation stopped below, keeps all columns in bounds.
	arena.practice = false
	arena.sound_enabled = false
	root.add_child(arena)
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	arena.player.visible = false
	var columns := [Vector2(210, 300), Vector2(640, 300), Vector2(1070, 300), Vector2(210, 570), Vector2(640, 570), Vector2(1070, 570)]
	var captions := ["NORMAL", "CRITICAL", "FIRE", "LIGHTNING", "ICE", "DARK"]
	var elements := ["", "", "fire", "lightning", "ice", "dark"]
	for i in range(columns.size()):
		var at: Vector2 = columns[i]
		var label := Label.new()
		label.text = captions[i]
		label.position = at + Vector2(-60, -115)
		label.add_theme_color_override("font_color", Color("aeb5c5"))
		arena.add_child(label)
		var enemy := arena.spawn_enemy("dummy", at)
		enemy.health = 1000
		enemy.max_health = 1000
		var crit := i == 1
		arena.deal_damage_packet(enemy, {"damage": 56.0 if i > 1 else 36.0, "base_damage": 36.0, "elemental_damage": 20.0 if i > 1 else 0.0, "element": elements[i], "crit": crit})
		if i > 1:
			# Second enemy shows element critical still uses the same element color.
			var critical_target := arena.spawn_enemy("dummy", at + Vector2(105, 55))
			critical_target.health = 1000
			critical_target.max_health = 1000
			arena.deal_damage_packet(critical_target, {"damage": 112.0, "base_damage": 72.0, "elemental_damage": 40.0, "element": elements[i], "crit": true})
	for effect in arena.effects.get_children():
		if effect is FloatingText:
			effect.life = 60.0
			effect.set_process(false)
	for frame in range(8): await process_frame
	await RenderingServer.frame_post_draw
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			var path := argument.trim_prefix("--output=")
			if path.is_absolute_path() and not path.begins_with(ProjectSettings.globalize_path("res://")):
				var error := root.get_texture().get_image().save_png(path)
				print("Damage palette image: ", path, " result=", error)
	arena.queue_free()
	await process_frame
	await preload("res://tests/audio_teardown.gd").drain(self)
	quit()
