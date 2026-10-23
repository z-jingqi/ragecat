extends SceneTree
## Synthetic controller-navigation contracts, not physical console certification.
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
func run() -> void:
	var panel := PracticePanel.new()
	panel.size = Vector2(340, 620)
	root.add_child(panel)
	panel.setup(UpgradeCatalog.new())
	await process_frame
	var changes: Array = []
	var commands: Array = []
	panel.option_changed.connect(func(key: String, value: Variant) -> void: changes.append([key, value]))
	panel.command.connect(func(action: String) -> void: commands.append(action))
	panel.enter_navigation()
	var identities: Array = []
	var phases: Array = []
	for node in panel.find_children("*", "Button", true, false):
		var button := node as Button
		if button.has_meta("practice_option"):
			var key := str(button.get_meta("practice_option"))
			var value: Variant = button.get_meta("practice_value")
			if key not in ["boss_identity", "boss_phase"]: continue
			check(button.focus_mode == Control.FOCUS_ALL, key + " controller focus enabled")
			check(not button.focus_neighbor_bottom.is_empty(), key + " has navigation successor")
			check(button.tooltip_text.is_empty(), key + " does not require hover")
			button.grab_focus()
			button.pressed.emit()
			check(changes.back() == [key, value], key + " emits correct semantic value")
			if key == "boss_identity": identities.append(value)
			else: phases.append(value)
		elif button.has_meta("practice_action"):
			var action := str(button.get_meta("practice_action"))
			if action in ["spawn_swiftfang", "spawn_elite_hornling", "spawn_boss"]:
				button.pressed.emit()
				check(commands.back() == action, action + " routes command")
	check(identities == ["mountainbreaker", "beastcaller", "wildfire"], "All three boss identities selectable")
	check(phases == [1, 2], "Both boss phases selectable")
	for locale in ["en", "zh_CN"]:
		TranslationServer.set_locale(locale)
		GameLocale.refresh_tree(panel)
		await process_frame
		for node in panel.find_children("*", "Button", true, false):
			var button := node as Button
			if not button.has_meta("practice_option"): continue
			if str(button.get_meta("practice_option")) not in ["boss_identity", "boss_phase"]: continue
			check(not button.text.begins_with("LAB_") and not button.text.begins_with("NAME_"), locale + " resolves selectable labels")
			check(button.get_theme_font_size("font_size") >= TextFit.ACTION_MIN, locale + " respects font floor")
	panel.exit_navigation()
	for control: Control in panel._navigation_controls:
		check(control.focus_mode == Control.FOCUS_NONE, "Gameplay navigation relinquished")
	panel.queue_free()
	await process_frame
	print("PRACTICE BOSS CONTROLS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
