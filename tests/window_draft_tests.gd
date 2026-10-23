extends SceneTree
## Native acknowledgements must not discard the user's unapplied UI choices.
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func run() -> void:
	var controller := WindowSettingsController.new()
	controller.native_enabled = false
	controller.settings_path = "user://window-draft-contract.cfg"
	DirAccess.remove_absolute(controller.settings_path)
	root.add_child(controller)
	var panel := WindowSettingsPanel.new()
	panel.controller = controller
	root.add_child(panel)
	await process_frame
	var draft := Vector2i(960, 600)
	panel.size_choice.select(panel.sizes.find(draft))
	panel.size_choice.item_selected.emit(panel.size_choice.selected)
	panel.size_choice.grab_focus()
	controller.changed.emit()
	await process_frame
	check(panel.sizes[panel.size_choice.selected] == draft, "late native acknowledgement preserves unapplied size")
	check(root.gui_get_focus_owner() == panel.size_choice, "late native acknowledgement does not steal focus")
	panel.mode_choice.select(panel.modes.find(WindowSettingsController.FULLSCREEN))
	panel.mode_choice.item_selected.emit(panel.mode_choice.selected)
	controller.changed.emit()
	check(panel.mode_choice.get_selected_id() == WindowSettingsController.FULLSCREEN, "late native acknowledgement preserves unapplied mode")
	panel.mode_choice.select(panel.modes.find(WindowSettingsController.WINDOWED))
	panel.mode_choice.item_selected.emit(panel.mode_choice.selected)
	check(panel.sizes[panel.size_choice.selected] == draft, "mode roundtrip preserves window size draft")
	panel.apply_choice()
	check(controller.previewing and controller.active.size == draft, "Apply uses retained selection")
	controller.cancel_preview()
	check(panel.sizes[panel.size_choice.selected] == controller.confirmed.size, "Revert restores confirmed selection")
	panel.size_choice.select(panel.sizes.find(draft))
	panel.size_choice.item_selected.emit(panel.size_choice.selected)
	panel.apply_choice()
	controller.confirm_preview()
	check(not controller.previewing and controller.confirmed.size == draft, "Keep commits selected size")
	panel.queue_free()
	controller.queue_free()
	await process_frame
	DirAccess.remove_absolute("user://window-draft-contract.cfg")
	print("WINDOW DRAFT: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
