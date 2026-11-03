extends SceneTree
var checks := 0
func require(value, message):
	checks += 1
	if not value:
		push_error(message)
		quit(1)
func _initialize(): call_deferred("run")
func run():
	change_scene_to_file("res://gallery/main.tscn")
	await process_frame
	await process_frame
	require(current_scene.available.size() >= 2, "completed scenes discovered")
	for slug in ["impact", "pickup"]:
		var path = ""
		for entry in current_scene.available:
			if entry.slug == slug: path = entry.path
		require(not path.is_empty(), "known completed effect is listed")
		current_scene.open_effect(path)
		await process_frame
		await process_frame
		require(current_scene.scene_file_path == path, "effect opened")
		var live = current_scene.get("live")
		require(live is Array and not live.is_empty(), "effect initialized with live native instances")
		var event = InputEventKey.new()
		event.keycode = KEY_ESCAPE
		event.pressed = true
		root.get_node("ExactNavigation")._unhandled_key_input(event)
		await process_frame
		await process_frame
		require(current_scene.scene_file_path == "res://gallery/main.tscn", "escape returns")
		require(current_scene.get_children().size() == 1, "menu rebuilt without duplicated controls")
	print("PASS gallery navigation ", checks, " checks")
	quit()
