extends SceneTree
## Native-only: run with --wid <real host XID/HWND>, never a mocked flag.
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func run() -> void:
	if not Engine.is_embedded_in_editor() or DisplayServer.get_name() == "headless":
		print("EMBEDDED WINDOW SMOKE: skipped; actual native host required")
		quit()
		return
	print("EMBEDDED ENGINE: true; runtime --wid visible: ", WindowSettingsController.has_parent_window(OS.get_cmdline_args()), "; root.is_embedded: ", root.is_embedded())
	var before_mode := root.mode
	var before_size := root.size
	var before_fixed := root.unresizable
	var path := "user://embedded-window-smoke.cfg"
	var config := ConfigFile.new()
	config.set_value("window", "mode", WindowSettingsController.EXCLUSIVE)
	config.set_value("window", "size", Vector2i(1280, 800))
	config.save(path)
	var before_file := FileAccess.get_file_as_string(path)
	var controller := WindowSettingsController.new()
	controller.settings_path = path
	root.add_child(controller)
	check(controller.is_host_embedded(), "native editor host detected without command-line flag")
	check(controller.apply_error_key == "DISPLAY_EMBEDDED" and not controller.apply_pending, "startup preference blocked before native mutations")
	var panel := WindowSettingsPanel.new()
	panel.controller = controller
	root.add_child(panel)
	check(panel.mode_choice.disabled and panel.size_choice.disabled and panel.apply_button.disabled, "unsupported controls disabled")
	check(panel.status.visible, "short standalone guidance visible")
	controller.begin_preview(WindowSettingsController.EXCLUSIVE, Vector2i(960, 600))
	controller.apply_native_request({"mode": WindowSettingsController.EXCLUSIVE, "size": Vector2i(960, 600)})
	controller.confirm_preview()
	for frame in range(30): await process_frame
	check(not controller.previewing and not controller.apply_pending, "no preview or retry loop in embedded mode")
	check(root.mode == before_mode and root.size == before_size and root.unresizable == before_fixed, "native host mode size and flags untouched")
	check(FileAccess.get_file_as_string(path) == before_file, "standalone saved preference preserved")
	panel.queue_free()
	controller.queue_free()
	await process_frame
	DirAccess.remove_absolute(path)
	print("EMBEDDED WINDOW SMOKE: ", checks, " checks, ", failures, " failures; backend ", DisplayServer.get_name())
	quit(1 if failures else 0)
