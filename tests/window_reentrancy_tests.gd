extends SceneTree
## Reentrant UI, focus and write-failure regression contracts. Isolated HOME required.
var checks := 0
var failures := 0
func check(ok: bool, msg: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(msg)
func _initialize() -> void: call_deferred("run")
func tick() -> void:
	for i in range(3): await process_frame
func press(key: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = key
	e.pressed = true
	root.push_input(e)
	e.pressed = false
	root.push_input(e)
func panel(game: Node) -> WindowSettingsPanel: return game.overlay.get_node("ModalScroll/ModalContent").get_child(0)
func run() -> void:
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await tick()
	var blocked_path := "user://window-write-failure-directory"
	DirAccess.make_dir_recursive_absolute(blocked_path)
	game.window_settings.settings_path = blocked_path
	var before: Dictionary = game.window_settings.confirmed.duplicate()
	game.window_settings.begin_preview(3, before.size)
	game.window_settings.confirm_preview()
	check(game.window_settings.last_save_error != OK, "save failure detected")
	check(not game.window_settings.previewing and game.window_settings.active == before and game.window_settings.confirmed == before, "save failure reverts state")
	for i in range(25):
		game.open_display_settings()
		game.close_display_settings()
		game.open_display_settings()
		var live := panel(game)
		game.window_settings.begin_preview(3, before.size)
		await tick()
		check(game.window_settings.previewing, "retired panel cannot cancel current preview")
		check(root.gui_get_focus_owner() == live.revert_button, "reopened live panel gets safe focus")
		press(KEY_DOWN)
		await tick()
		check(root.gui_get_focus_owner() == live.confirmation.get_child(2), "keyboard Down can reach Keep")
		press(KEY_UP)
		await tick()
		check(root.gui_get_focus_owner() == live.revert_button, "keyboard Up returns Revert")
		press(KEY_ESCAPE)
		await tick()
		check(game.current_mode == "display" and not game.window_settings.previewing, "Escape cancels only preview")
		press(KEY_ESCAPE)
		await tick()
		check(game.current_mode == "menu", "second Escape returns menu")
	game.queue_free()
	await tick()
	DirAccess.remove_absolute(blocked_path)
	print("WINDOW REENTRANCY: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
