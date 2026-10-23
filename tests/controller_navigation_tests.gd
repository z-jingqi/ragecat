extends SceneTree
# Synthetic input contracts, not physical-controller or console certification.
var checks := 0
var failed := false

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failed = true
		push_error("FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game := load("res://scenes/main.tscn").instantiate() as Node
	root.add_child(game)
	await process_frame
	await process_frame
	var focus: Control = root.gui_get_focus_owner()
	check(focus is Button and game.overlay.is_ancestor_of(focus), "Main menu has initial actionable focus")
	var down := InputEventKey.new()
	down.keycode = KEY_DOWN
	down.pressed = true
	root.push_input(down)
	await process_frame
	check(root.gui_get_focus_owner() != focus, "Injected keyboard Down navigates menu focus")
	down.pressed = false
	root.push_input(down)
	var pad_up := InputEventJoypadButton.new()
	pad_up.button_index = JOY_BUTTON_DPAD_UP
	pad_up.pressed = true
	root.push_input(pad_up)
	await process_frame
	check(root.gui_get_focus_owner() == focus, "Injected gamepad D-pad returns to previous menu item")
	pad_up.pressed = false
	root.push_input(pad_up)
	var axis := InputEventJoypadMotion.new()
	axis.axis = JOY_AXIS_LEFT_Y
	axis.axis_value = 1.0
	axis.device = 7
	Input.parse_input_event(axis)
	await process_frame
	check(root.gui_get_focus_owner() != focus, "Raw left-stick motion navigates menu on arbitrary device")
	axis.axis_value = 0.0
	Input.parse_input_event(axis)
	focus.grab_focus()
	var event_count := InputMap.action_get_events("ui_accept").size()
	game.configure_input()
	check(InputMap.action_get_events("ui_accept").size() == event_count, "Input setup is idempotent")
	var space := InputEventKey.new()
	space.physical_keycode = KEY_SPACE
	space.pressed = true
	check(space.is_action_pressed("dash") and not space.is_action_pressed("ui_accept"), "Space is exclusively dash, not Confirm")
	var shoulder := InputEventJoypadButton.new()
	shoulder.button_index = JOY_BUTTON_RIGHT_SHOULDER
	shoulder.pressed = true
	check(shoulder.is_action_pressed("dash") and not shoulder.is_action_pressed("ui_accept") and not shoulder.is_action_pressed("ui_cancel"), "Gamepad dash does not overlap Confirm or Back")
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_X
	stick.axis_value = 1.0
	check(stick.is_action_pressed("move_right"), "Left stick is mapped to semantic movement")
	var menu_scroll: ScrollContainer = game.overlay.get_node("ModalScroll")
	check(menu_scroll.follow_focus, "Menus scroll to focused controls")
	var confirm := InputEventJoypadButton.new()
	confirm.button_index = JOY_BUTTON_A
	confirm.device = 7
	confirm.pressed = true
	check(confirm.is_action_pressed("ui_accept"), "Raw pad Confirm works on arbitrary device")
	root.push_input(confirm)
	confirm.pressed = false
	root.push_input(confirm)
	await process_frame
	check(game.current_mode == "campaign", "Raw pad Confirm activates focused main-menu Start")
	game.start_run(false)
	game.catalog.all_unlocked = true # Full-catalog UI fixture.
	await process_frame
	var start := InputEventJoypadButton.new()
	start.button_index = JOY_BUTTON_START
	start.pressed = true
	game._unhandled_input(start)
	check(game.current_mode == "pause" and paused, "Synthetic gamepad Start pauses")
	await process_frame
	check(root.gui_get_focus_owner() != null, "Paused UI obtains focus")
	game.resume_run()
	check(game.current_mode == "campaign" and not paused, "Resume exits paused UI")
	game.show_upgrades()
	await process_frame
	var keys: Array[String] = []
	for node in game.overlay.find_children("*", "Button", true, false):
		if node.has_meta("upgrade_key"): keys.append(str(node.get_meta("upgrade_key")))
	focus = root.gui_get_focus_owner()
	check(focus != null and focus.has_meta("upgrade_key"), "Upgrade selection has card focus")
	game.set_language("zh_CN")
	await process_frame
	check(root.gui_get_focus_owner() == focus, "Locale change preserves focused card")
	var translated_keys: Array[String] = []
	for node in game.overlay.find_children("*", "Button", true, false):
		if node.has_meta("upgrade_key"): translated_keys.append(str(node.get_meta("upgrade_key")))
	check(keys == translated_keys, "Locale change does not reroll cards")
	game.choose_upgrade(keys[0])
	check(game.current_mode == "campaign" and not paused, "Choosing card resumes gameplay")
	game.start_run(true)
	game.show_pause()
	game.enter_practice_navigation()
	await process_frame
	check(game.current_mode == "practice_ui" and not paused, "Practice controls are a live explicit mode")
	var detail_key: String = game.lab._rank_controls.keys()[0]
	var detail_name: Control = game.lab._rank_controls[detail_key].get_parent().get_child(0)
	detail_name.grab_focus()
	confirm.pressed = true
	root.push_input(confirm)
	confirm.pressed = false
	root.push_input(confirm)
	await process_frame
	check(is_instance_valid(game.lab._details_popup), "Raw pad Confirm opens focused upgrade details")
	var back := InputEventJoypadButton.new()
	back.button_index = JOY_BUTTON_B
	back.device = 7
	back.pressed = true
	check(back.is_action_pressed("ui_cancel"), "Raw pad Back works on arbitrary device")
	root.push_input(back)
	back.pressed = false
	root.push_input(back)
	await process_frame
	check(not is_instance_valid(game.lab._details_popup), "Raw pad Back closes details")
	check(game.current_mode == "practice_ui" and not paused, "Detail Back does not fall through to pause or gameplay")
	game.practice_option("time_scale", 0.25)
	check(not paused, "Changing lab speed takes effect immediately")
	back.pressed = true
	root.push_input(back)
	back.pressed = false
	root.push_input(back)
	await process_frame
	check(game.current_mode == "practice" and not paused, "Back from lab returns directly to live practice")
	focus = root.gui_get_focus_owner()
	check(focus == null, "Lab exit releases UI focus for gameplay")
	game.resume_run()
	game.enter_practice_navigation()
	game.lab.navigation_closed.emit()
	check(game.current_mode == "practice" and not paused, "Mouse-launched lab returns to gameplay")
	game.set_language("en")
	game.queue_free()
	paused = false
	Engine.time_scale = 1.0
	await process_frame
	await preload("res://tests/audio_teardown.gd").drain(self)
	print("%s: %d controller navigation contracts (synthetic input only)" % ["FAIL" if failed else "PASS", checks])
	quit(1 if failed else 0)
