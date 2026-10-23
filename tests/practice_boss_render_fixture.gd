extends SceneTree
## Rendered-only fixture. Run without --headless and pass -- --locale=zh_CN --output=/tmp/lab.png.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Practice render fixture requires a real rendering display")
		quit(1)
		return
	var locale := "en"
	var output := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--locale="): locale = argument.trim_prefix("--locale=")
		elif argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_run(true)
	TranslationServer.set_locale(locale)
	GameLocale.refresh_tree(game)
	await process_frame
	game.enter_practice_navigation()
	for node in game.lab.find_children("*", "Button", true, false):
		if str(node.get_meta("practice_option", "")) == "boss_phase" and int(node.get_meta("practice_value", 0)) == 2:
			node.grab_focus()
			break
	for frame in range(5): await process_frame
	await RenderingServer.frame_post_draw
	if not output.is_empty():
		var error := root.get_texture().get_image().save_png(output)
		if error != OK:
			push_error("Unable to save practice render: " + error_string(error))
			quit(1)
			return
	print("PRACTICE RENDER READY: " + locale)
	game.queue_free()
	paused = false
	await process_frame
	quit()
