extends Node

@export var arena_definition: ArenaDefinition = preload("res://resources/settings/arena.tres")
@export var ranged_definition: SpitterDefinition = preload("res://resources/enemies/spitter.tres")
@export var character_definition: CharacterDefinition = preload("res://resources/characters/archer.tres")

const CATALOG = preload("res://scripts/upgrades/upgrade_catalog.gd")
var catalog := UpgradeCatalog.new()
var display_settings := DisplaySettings.new()
var window_settings: WindowSettingsController
var display_return := "menu"
var arena: RageArena
var ui := CanvasLayer.new()
var hud: Label
var combat_hud: CombatHud
var details_return := "campaign"
var details_was_paused := false
var details_scroll_fraction := 0.0
var details_scroll_tick := 0
var health_bar: ProgressBar
var xp_bar: ProgressBar
var xp_label: Label
var overlay: Control
var lab: PracticePanel
var current_mode := "menu"
var lab_scale := 1.0
var snapshot_requested := false
var practice_panel_open := false
var progression := AchievementProfile.new()
var achievement_page := 0
var achievement_return := "menu"
var unlock_queue: Array[String] = []
var unlock_toast: Label
var unlock_remaining := 0.0

func _ready() -> void:
	progression.load_profile()
	progression.unlocked.connect(func(key: String) -> void: unlock_queue.append(key))
	progression.save_failed.connect(func(error: Error) -> void: push_warning("Achievement save failed: " + error_string(error)))
	display_settings.load_settings()
	TranslationServer.set_locale(display_settings.resolved_language())
	window_settings = WindowSettingsController.new()
	add_child(window_settings)
	process_mode = Node.PROCESS_MODE_ALWAYS
	configure_input()
	add_child(ui)
	show_menu()
	var args := OS.get_cmdline_user_args()
	if "--practice" in args: start_run(true)
	if "--endless" in args: start_run(false)
	if "--showcase" in args:
		start_run(true)
		practice_command("preset_fire")
		practice_command("spawn_group")
		practice_command("spawn_boss")
	if "--screenshot" in args:
		await get_tree().create_timer(2.0).timeout
		var image := get_viewport().get_texture().get_image()
		image.save_png("res://screenshots/gameplay.png")

func configure_input() -> void:
	# Keep gameplay and UI confirmation separate. Space is dash, never Confirm.
	for event in InputMap.action_get_events("ui_accept"):
		if event is InputEventKey and (event.keycode == KEY_SPACE or event.physical_keycode == KEY_SPACE):
			InputMap.action_erase_event("ui_accept", event)
	for entry in [["move_left", KEY_A], ["move_right", KEY_D], ["move_up", KEY_W], ["move_down", KEY_S], ["dash", KEY_SPACE], ["pause", KEY_ESCAPE]]:
		if not InputMap.has_action(entry[0]): InputMap.add_action(entry[0], 0.2)
		var event := InputEventKey.new()
		event.physical_keycode = entry[1]
		if not InputMap.action_has_event(entry[0], event): InputMap.action_add_event(entry[0], event)
	for entry in [["move_left", JOY_AXIS_LEFT_X, -1.0], ["move_right", JOY_AXIS_LEFT_X, 1.0], ["move_up", JOY_AXIS_LEFT_Y, -1.0], ["move_down", JOY_AXIS_LEFT_Y, 1.0], ["ui_left", JOY_AXIS_LEFT_X, -1.0], ["ui_right", JOY_AXIS_LEFT_X, 1.0], ["ui_up", JOY_AXIS_LEFT_Y, -1.0], ["ui_down", JOY_AXIS_LEFT_Y, 1.0]]:
		var event := InputEventJoypadMotion.new()
		event.device = -1
		event.axis = entry[1]
		event.axis_value = entry[2]
		if not InputMap.action_has_event(entry[0], event): InputMap.action_add_event(entry[0], event)
	for entry in [["move_left", JOY_BUTTON_DPAD_LEFT], ["move_right", JOY_BUTTON_DPAD_RIGHT], ["move_up", JOY_BUTTON_DPAD_UP], ["move_down", JOY_BUTTON_DPAD_DOWN], ["dash", JOY_BUTTON_RIGHT_SHOULDER], ["pause", JOY_BUTTON_START], ["ui_accept", JOY_BUTTON_A], ["ui_cancel", JOY_BUTTON_B], ["ui_left", JOY_BUTTON_DPAD_LEFT], ["ui_right", JOY_BUTTON_DPAD_RIGHT], ["ui_up", JOY_BUTTON_DPAD_UP], ["ui_down", JOY_BUTTON_DPAD_DOWN]]:
		var event := InputEventJoypadButton.new()
		event.device = -1
		event.button_index = entry[1]
		if not InputMap.action_has_event(entry[0], event): InputMap.action_add_event(entry[0], event)

func _input(event: InputEvent) -> void:
	if current_mode != "details": return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close_run_details()
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down"):
		# The details are read-only: navigation scrolls the full text instead of
		# jumping over a long element description to the next focusable row.
		get_viewport().set_input_as_handled()
		scroll_run_details(-32 if event.is_action_pressed("ui_up") else 32)
	elif event.is_action_pressed("ui_page_up") or event.is_action_pressed("ui_page_down"):
		get_viewport().set_input_as_handled()
		scroll_run_details(-400 if event.is_action_pressed("ui_page_up") else 400)

func scroll_run_details(amount: float) -> void:
	if current_mode != "details" or not is_instance_valid(overlay): return
	details_scroll_fraction += amount
	var pixels := int(details_scroll_fraction)
	details_scroll_fraction -= pixels
	var scroll := overlay.get_node("ModalScroll") as ScrollContainer
	scroll.scroll_vertical += pixels

func _unhandled_input(event: InputEvent) -> void:
	if current_mode == "details" and (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		close_run_details()
		return
	if current_mode == "display" and (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		if window_settings.previewing: window_settings.cancel_preview()
		else: close_display_settings()
		return
	if current_mode == "achievements" and (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		close_achievements()
		return
	if (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")) and arena != null:
		get_viewport().set_input_as_handled()
		if current_mode in ["upgrade", "dead", "victory"]: return
		if current_mode == "practice_ui":
			return_from_practice_navigation()
		elif current_mode == "pause": resume_run()
		else: show_pause()
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_F12:
		DirAccess.make_dir_recursive_absolute("user://screenshots")
		get_viewport().get_texture().get_image().save_png("user://screenshots/capture_%d.png" % Time.get_ticks_msec())

func focus_menu(box: Control, preferred_key: String = "") -> void:
	var controls: Array[Control] = []
	for control in box.find_children("*", "Control", true, false):
		if control.focus_mode == Control.FOCUS_ALL: controls.append(control)
	for i in range(controls.size()):
		var control := controls[i]
		var previous := controls[maxi(0, i - 1)]
		var following := controls[mini(controls.size() - 1, i + 1)]
		control.focus_neighbor_top = control.get_path_to(previous)
		control.focus_neighbor_bottom = control.get_path_to(following)
		control.focus_previous = control.get_path_to(previous)
		control.focus_next = control.get_path_to(following)
		# Horizontal language choices stay on their row; other rows cannot leak focus.
		control.focus_neighbor_left = control.get_path_to(previous if control.has_meta("language_choice") and previous.has_meta("language_choice") else control)
		control.focus_neighbor_right = control.get_path_to(following if control.has_meta("language_choice") and following.has_meta("language_choice") else control)
	var initial: Control = controls[0] if not controls.is_empty() else null
	for control in controls:
		if control.get_meta("translation_key", "") == preferred_key and not preferred_key.is_empty(): initial = control
		if control.has_meta("practice_controls") and preferred_key == "practice": initial = control
	if initial != null: call_deferred("grab_live_focus", initial)

func grab_live_focus(control: Control) -> void:
	if is_instance_valid(control) and control.is_inside_tree(): control.grab_focus()

func toggle_practice_navigation() -> void:
	if current_mode == "practice_ui": return_from_practice_navigation()
	elif current_mode in ["practice", "pause"]: enter_practice_navigation()

func enter_practice_navigation() -> void:
	if not is_instance_valid(lab): return
	practice_panel_open = true
	if overlay != null: retire_node(overlay)
	overlay = null
	current_mode = "practice_ui"
	get_tree().paused = lab_scale == 0.0
	arena.player.movement_enabled = false
	lab.show()
	lab.enter_navigation()

func return_from_practice_navigation() -> void:
	if current_mode != "practice_ui": return
	lab.exit_navigation()
	lab.hide()
	practice_panel_open = false
	arena.player.movement_enabled = true
	resume_run()


func retire_node(node: Node) -> void:
	# UI callbacks may still be emitting on descendants. Detach immediately so
	# stale controls cannot receive input, but destroy only after signals return.
	if not is_instance_valid(node): return
	if node.get_parent() != null: node.get_parent().remove_child(node)
	node.queue_free()

func clear_ui() -> void:
	for child in ui.get_children(): retire_node(child)
	overlay = null
	lab = null

func title_label(text: String, size: int = 24) -> Label:
	var label := Label.new()
	GameLocale.bind(label, text)
	TextFit.attach(label, size, 16 if size >= 24 else 14, 100 if size >= 24 else 0)
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",Color("ebf2ed"))
	return label

func button(text: String, action: Callable) -> Button:
	var item := Button.new()
	GameLocale.bind(item, text)
	item.focus_mode = Control.FOCUS_ALL
	TextFit.attach(item, 18, TextFit.ACTION_MIN, 68)
	item.custom_minimum_size=Vector2(260,48)
	item.add_theme_font_size_override("font_size",18)
	item.pressed.connect(action)
	return item

func backdrop() -> VBoxContainer:
	overlay=Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(overlay)
	var shade := ColorRect.new()
	shade.color=Color(0.025,0.035,0.065,0.94)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	var scroll := ScrollContainer.new()
	scroll.name = "ModalScroll"
	scroll.follow_focus = true
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 240
	scroll.offset_right = -240
	scroll.offset_top = 48
	scroll.offset_bottom = -48
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	overlay.add_child(scroll)
	var box := VBoxContainer.new()
	box.name = "ModalContent"
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 16)
	scroll.add_child(box)
	return box

func show_menu() -> void:
	progression.end_run()
	get_tree().paused=false
	Engine.time_scale=1.0
	if is_instance_valid(arena): retire_node(arena)
	arena=null
	clear_ui()
	current_mode="menu"
	var box:=backdrop()
	box.add_theme_constant_override("separation", 8)
	var brand:=title_label("RAGE CAT",68)
	brand.add_theme_color_override("font_color",Color("ffd57e"))
	box.add_child(brand)
	box.add_child(button("MENU_START",func()->void: start_run(false)))
	box.add_child(button("MENU_PRACTICE",func()->void: start_run(true)))
	box.add_child(button("ACH_TITLE", open_achievements))
	box.add_child(health_bar_toggle())
	box.add_child(sound_toggle())
	box.add_child(language_picker())
	box.add_child(button("DISPLAY_TITLE", open_display_settings))
	box.add_child(button("MENU_QUIT",func()->void: get_tree().quit()))
	box.add_child(title_label("MENU_CONTROLS",15))
	focus_menu(box)

func start_run(practice: bool, seed_override: Variant = null) -> void:
	progression.end_run()
	progression.begin_run(practice)
	unlock_queue.clear()
	get_tree().paused=false
	Engine.time_scale=1.0
	lab_scale=1.0
	practice_panel_open=false
	if is_instance_valid(arena): retire_node(arena)
	clear_ui()
	arena=RageArena.new()
	arena.definition=arena_definition
	arena.ranged_definition=ranged_definition
	arena.character_definition=character_definition
	arena.practice=practice
	arena.progression=progression
	arena.run_seed_override=seed_override
	arena.process_mode=Node.PROCESS_MODE_PAUSABLE
	arena.show_enemy_health = display_settings.show_enemy_health
	arena.sound_enabled = display_settings.sound_enabled
	add_child(arena)
	catalog=arena.stats.catalog
	arena.level_ready.connect(show_upgrades)
	arena.run_ended.connect(show_death)
	arena.victory_reached.connect(show_victory)
	arena.hud_changed.connect(update_hud)
	current_mode="practice" if practice else "campaign"
	combat_hud = CombatHud.new()
	ui.add_child(combat_hud)
	combat_hud.details_requested.connect(open_run_details)
	combat_hud.pause_requested.connect(show_pause)
	combat_hud.set_practice_available(practice)
	combat_hud.practice_requested.connect(toggle_practice_navigation)
	hud = combat_hud.health_text
	health_bar = combat_hud.health_bar
	xp_bar = combat_hud.xp_bar
	xp_label = combat_hud.level_text
	if practice:
		lab=PracticePanel.new()
		lab.arena_definition=arena.definition
		lab.position=Vector2(856,64)
		lab.size=Vector2(400,712)
		lab.hide()
		ui.add_child(lab)
		lab.setup(catalog)
		lab.ranks_changed.connect(func(value: Dictionary) -> void:
			var old_shield_rank := int(arena.ranks.get("shield",0))
			arena.apply_ranks(value)
			if int(value.get("shield",0)) > old_shield_rank: arena.stats.shields=arena.stats.shield_capacity
		)
		lab.command.connect(practice_command)
		lab.option_changed.connect(practice_option)
		lab.navigation_closed.connect(return_from_practice_navigation)
		lab.navigation_requested.connect(enter_practice_navigation)
		enter_practice_navigation()
	update_hud()

func update_hud() -> void:
	if not is_instance_valid(arena) or hud == null: return
	if current_mode == "dead" and is_instance_valid(overlay):
		for control in overlay.find_children("*", "Label", true, false):
			if control.has_meta("death_summary"):
				GameLocale.bind(control, "DEATH_STATS", [int(arena.director.elapsed)/60, int(arena.director.elapsed)%60, arena.kills, arena.director.boss_count])
	var s:=arena.stats
	combat_hud.update_state(arena)
	if current_mode == "details": update_run_details()
	if lab != null:
		lab.set_metrics(GameLocale.text("LAB_METRICS") % [UpgradeDefinition.number(arena.stats.base_damage), UpgradeDefinition.number(arena.stats.element_damage), GameLocale.element_name(arena.stats.active_element), arena.hits, arena.crits, arena.total_damage, int(arena.ranks.get("enchant_rank", 0)), arena.stats.element_skill_rank] + "\n" + s.effective_pierce_text())
		if s.gravity_mode():
			lab.set_metrics(GameLocale.text("LAB_GRAVITY_METRICS") % [UpgradeDefinition.number(s.gravity_dps), UpgradeDefinition.number(s.arrow_speed), UpgradeDefinition.number(s.gravity_outer_radius), UpgradeDefinition.number(s.gravity_inner_radius), arena.bow.gravity_gap_remaining] + "\n" + s.effective_pierce_text())

func open_display_settings() -> void:
	if current_mode == "display": return
	display_return = "pause" if is_instance_valid(arena) else "menu"
	if overlay != null: retire_node(overlay)
	current_mode = "display"
	get_tree().paused = is_instance_valid(arena)
	var box := backdrop()
	var panel := WindowSettingsPanel.new()
	panel.controller = window_settings
	panel.closed.connect(close_display_settings)
	box.add_child(panel)

func close_display_settings() -> void:
	window_settings.cancel_preview()
	if overlay != null: retire_node(overlay)
	overlay = null
	if display_return == "pause" and is_instance_valid(arena): show_pause()
	else: show_menu()
	focus_menu(overlay.get_node("ModalScroll/ModalContent"), "DISPLAY_TITLE")

func show_pause() -> void:
	if current_mode == "pause": return
	if is_instance_valid(lab):
		lab.exit_navigation()
		lab.hide()
	current_mode="pause"
	get_tree().paused=true
	var box:=backdrop()
	box.add_child(title_label("PAUSE_TITLE",40))
	box.add_child(health_bar_toggle())
	box.add_child(sound_toggle())
	box.add_child(language_picker())
	box.add_child(button("DISPLAY_TITLE", open_display_settings))
	box.add_child(button("RUN_DETAILS", open_run_details))
	if arena.practice:
		var practice_button := button("PRACTICE_UI_OPEN", enter_practice_navigation)
		practice_button.set_meta("practice_controls", true)
		box.add_child(practice_button)
	box.add_child(button("ACH_TITLE", open_achievements))
	box.add_child(button("PAUSE_RESUME",resume_run))
	box.add_child(button("PAUSE_RESTART",func()->void: start_run(arena.practice)))
	box.add_child(button("MENU_MAIN",show_menu))
	focus_menu(box)

func resume_run() -> void:
	if is_instance_valid(lab): lab.hide()
	if overlay != null: retire_node(overlay)
	overlay=null
	current_mode="practice" if arena.practice else arena.run_phase
	get_tree().paused=arena.practice and lab_scale==0.0
	arena.player.movement_enabled = true
	if arena.practice and practice_panel_open: enter_practice_navigation()

func show_upgrades() -> void:
	if current_mode in ["victory", "dead"]: return
	catalog=arena.stats.catalog
	if arena.practice or current_mode=="upgrade": return
	current_mode="upgrade"
	get_tree().paused=true
	var box:=backdrop()
	var heading := title_label("UPGRADE_TITLE", 32)
	GameLocale.bind(heading, "UPGRADE_TITLE", [arena.level])
	box.add_child(heading)
	var offer: Dictionary = catalog.generate_offer(arena.stats, arena.offer_state, arena.offer_context(), arena.definition.upgrade_choices)
	var candidates: Array = offer["keys"]
	var serial: int = offer.serial
	var count := candidates.size()
	for i in range(count):
		var key:String=candidates[i]
		var item:=button(upgrade_card_text(key),func()->void: accept_offer_choice(key, serial))
		item.set_meta("upgrade_key", key)
		item.custom_minimum_size=Vector2(0,128)
		TextFit.attach(item, 18, TextFit.ACTION_MIN, 160)
		box.add_child(item)
	if count==0:
		box.add_child(title_label("UPGRADE_COMPLETE",20))
		box.add_child(button("UPGRADE_CONTINUE",func()->void: accept_offer_choice("continue", serial)))
	elif bool(offer.can_keep_build):
		var keep := button("UPGRADE_KEEP_BUILD", func() -> void: accept_offer_choice("continue", serial))
		keep.set_meta("action", "keep_build")
		box.add_child(keep)

	focus_menu(box)

func accept_offer_choice(key: String, serial: int) -> void:
	if current_mode != "upgrade" or not is_instance_valid(arena): return
	if int(arena.offer_state.pending.get("serial", -1)) != serial: return
	choose_upgrade(key)

func choose_upgrade(key: String) -> void:
	arena.offer_state.resolve_offer()
	if key=="refill": arena.stats.shields=arena.stats.shield_capacity
	elif key=="heal": arena.player.heal(arena.stats.max_hp*arena.definition.heal_fraction)
	elif key!="continue":
		arena.select_upgrade(key)
		if key=="shield": arena.stats.shields=arena.stats.shield_capacity
	resume_run()

func show_death() -> void:
	# Live lab controls and their high-layer details must not cover death UI.
	if is_instance_valid(lab):
		lab.exit_navigation()
		lab.hide()
	practice_panel_open = false
	if is_instance_valid(overlay): retire_node(overlay)
	overlay = null
	current_mode="dead"
	get_tree().paused=true
	var box:=backdrop()
	box.add_child(title_label("DEATH_TITLE",38))
	var summary := title_label("DEATH_STATS", 24)
	GameLocale.bind(summary, "DEATH_STATS", [int(arena.director.elapsed)/60,int(arena.director.elapsed)%60,arena.kills,arena.director.boss_count])
	summary.set_meta("death_summary", true)
	box.add_child(summary)
	box.add_child(button("ACH_TITLE", open_achievements))
	box.add_child(button("DEATH_RETRY",func()->void: start_run(arena.practice)))
	box.add_child(button("MENU_MAIN",show_menu))
	focus_menu(box)

func practice_command(action: String) -> void:
	match action:
		"spawn_dummy", "spawn_mob", "spawn_boss", "spawn_ranged", "spawn_swiftfang", "spawn_elite_hornling": arena.spawn_enemy(action.trim_prefix("spawn_"),arena.player.position+arena.definition.practice_spawn_offset)
		"spawn_line":
			for i in range(arena.definition.practice_line_count): arena.spawn_enemy("dummy",arena.player.position+Vector2(arena.definition.practice_line_start+i*arena.definition.practice_line_spacing,0))
		"spawn_group":
			for i in range(arena.definition.practice_group_count): arena.spawn_enemy("mob",arena.player.position+Vector2.from_angle(i*TAU/arena.definition.practice_group_count)*arena.definition.practice_group_radius)
		"clear": arena.clear_enemies()
		"reset": start_run(true)
		"heal": arena.player.heal(arena.stats.max_hp)
		"refill": arena.stats.shields=arena.stats.shield_capacity
		_:
			if arena.definition.practice_presets.has(action):
				arena.apply_ranks(arena.definition.practice_presets[action])
				if action=="preset_shieldcrit": arena.stats.shields=arena.stats.shield_capacity
	if lab!=null: lab.set_ranks(arena.ranks)
	update_hud()

func practice_option(key: String, value: Variant) -> void:
	match key:
		"invulnerability": arena.player.invulnerable=bool(value)
		"enemy_ai":
			arena.set_enemy_ai(bool(value))
		"time_scale":
			lab_scale=float(value)
			get_tree().paused=lab_scale==0.0
			Engine.time_scale=maxf(.01,lab_scale)
		"boss_identity":
			arena.practice_boss_identity = str(value)
		"boss_phase":
			arena.set_practice_boss_phase(int(value))
		"boss_mode":
			arena.boss_mode=str(value)
			for enemy in arena.enemies.get_children():
				if enemy is Mountainbreaker:
					enemy.ability_mode=str(value)
					enemy.reset_state()
		_:
			arena.boss_settings[key]=value
			for enemy in arena.enemies.get_children():
				if enemy is Mountainbreaker: enemy.set(key,value)

func health_bar_toggle() -> CheckButton:
	var toggle := CheckButton.new()
	GameLocale.bind(toggle, "SETTINGS_HEALTH")
	TextFit.attach(toggle, 18, TextFit.ACTION_MIN, 68)
	toggle.button_pressed = display_settings.show_enemy_health
	toggle.focus_mode = Control.FOCUS_ALL
	toggle.toggled.connect(func(enabled: bool) -> void:
		display_settings.show_enemy_health = enabled
		var error := display_settings.save_settings()
		if error != OK: push_warning("Could not persist display preference: " + error_string(error))
		if is_instance_valid(arena): arena.set_enemy_health_bars(enabled)
	)
	return toggle

func sound_toggle() -> CheckButton:
	var toggle := CheckButton.new()
	GameLocale.bind(toggle, "SETTINGS_SOUND")
	TextFit.attach(toggle, 18, TextFit.ACTION_MIN, 68)
	toggle.focus_mode = Control.FOCUS_ALL
	toggle.button_pressed = display_settings.sound_enabled
	toggle.toggled.connect(func(value: bool) -> void:
		display_settings.sound_enabled = value
		var error := display_settings.save_settings()
		if error != OK: push_warning("Could not save sound preference: " + error_string(error))
		if is_instance_valid(arena): arena.set_sound_enabled(value)
	)
	return toggle

func upgrade_card_text(key: String) -> String:
	if key == "refill": return GameLocale.text("UPGRADE_REFILL")
	if key == "heal": return GameLocale.text("UPGRADE_HEAL") % catalog._number(arena.definition.heal_fraction * 100.0)
	var item := catalog.definition(key)
	return GameLocale.text("UPGRADE_CARD") % [item.display_name, catalog.choice_rank(arena.ranks, key), catalog.max_rank(key), catalog.describe_choice(key, arena.ranks)]

func language_picker() -> VBoxContainer:
	var column := VBoxContainer.new()
	var row := HBoxContainer.new()
	column.add_child(row)
	var group := ButtonGroup.new()
	for entry in [["en", "English"], ["zh_CN", "简体中文"]]:
		var locale: String = entry[0]
		var choice := button(entry[1], func() -> void: set_language(locale))
		choice.custom_minimum_size.x = 0
		choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choice.toggle_mode = true
		choice.button_group = group
		choice.set_meta("language_choice", locale)
		choice.button_pressed = TranslationServer.get_locale() == locale
		row.add_child(choice)
	return column

func set_language(locale: String) -> void:
	if locale not in GameLocale.SUPPORTED: return
	display_settings.language = locale
	var error := display_settings.save_settings()
	if error != OK: push_warning("Could not save language preference: " + error_string(error))
	TranslationServer.set_locale(locale)
	refresh_language()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if is_instance_valid(window_settings): window_settings.cancel_preview()
		progression.end_run()
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_inside_tree():
		call_deferred("refresh_language")

func refresh_language() -> void:
	if not is_instance_valid(ui) or not ui.is_inside_tree(): return
	catalog.refresh_translations()
	GameLocale.refresh_tree(ui)
	for control in ui.find_children("*", "Control", true, false):
		if control.has_meta("language_choice"):
			control.set_pressed_no_signal(str(control.get_meta("language_choice")) == TranslationServer.get_locale())
		if control.has_meta("achievement_id"):
			var achievement := progression.achievement(str(control.get_meta("achievement_id")))
			if achievement != null:
				control.text = achievement_row_text(achievement)
				TextFit.refit(control)
		if control.has_meta("unlock_toast_id"):
			var achievement := progression.achievement(str(control.get_meta("unlock_toast_id")))
			if achievement != null:
				control.text = GameLocale.text("ACH_UNLOCKED_TOAST") % reward_names(achievement)
				TextFit.refit(control)
		if control.has_meta("upgrade_key"):
			control.text = upgrade_card_text(str(control.get_meta("upgrade_key")))
			TextFit.refit(control)
	if is_instance_valid(lab): lab.refresh_language()
	if is_instance_valid(arena):
		update_hud()
		for effect in arena.effects.get_children():
			if effect is FloatingText: effect.refresh_language()

func _exit_tree() -> void:
	if is_instance_valid(window_settings): window_settings.cancel_preview()
	progression.end_run()

func _process(delta: float) -> void:
	if current_mode == "details":
		var now := Time.get_ticks_usec()
		var elapsed := minf(float(now - details_scroll_tick) / 1000000.0, 0.1)
		details_scroll_tick = now
		scroll_run_details(Input.get_axis("ui_up", "ui_down") * 300.0 * elapsed)
		return
	# Notifications never interrupt combat or obscure a decision screen.
	if current_mode not in ["endless", "campaign"]: return
	if is_instance_valid(unlock_toast):
		unlock_remaining -= delta
		if unlock_remaining <= 0.0:
			retire_node(unlock_toast)
			unlock_toast = null
	elif not unlock_queue.is_empty():
		var item := progression.achievement(unlock_queue.pop_front())
		if item == null: return
		unlock_toast = title_label("", 18)
		unlock_toast.text = GameLocale.text("ACH_UNLOCKED_TOAST") % reward_names(item)
		unlock_toast.set_meta("unlock_toast_id", item.achievement_id)
		unlock_toast.position = Vector2(340, 746)
		unlock_toast.size = Vector2(600, 34)
		unlock_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		unlock_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
		unlock_toast.add_theme_color_override("font_color", Color("ffd57e"))
		ui.add_child(unlock_toast)
		unlock_remaining = progression.definition.notification_duration

func reward_names(item: AchievementDefinition) -> String:
	if not item.reward_label_key.is_empty(): return GameLocale.text(item.reward_label_key)
	var names := PackedStringArray()
	for key in item.rewards:
		var upgrade := catalog.definition(key)
		if upgrade != null: names.append(upgrade.display_name)
	return " / ".join(names)

func open_achievements() -> void:
	achievement_return = current_mode
	achievement_page = 0
	show_achievements()

func show_achievements() -> void:
	if is_instance_valid(overlay): retire_node(overlay)
	overlay = null
	current_mode = "achievements"
	if is_instance_valid(arena): get_tree().paused = true
	var box := backdrop()
	box.add_child(title_label("ACH_TITLE", 36))
	box.add_child(title_label("ACH_INTRO", 16))
	var per_page := maxi(1, progression.definition.rows_per_page)
	var page_count := maxi(1, ceili(float(progression.definition.achievements.size()) / per_page))
	achievement_page = clampi(achievement_page, 0, page_count - 1)
	for index in range(achievement_page * per_page, mini((achievement_page + 1) * per_page, progression.definition.achievements.size())):
		var item := progression.definition.achievements[index]
		var row := button(achievement_row_text(item), func() -> void: pass)
		row.set_meta("achievement_id", item.achievement_id)
		row.custom_minimum_size = Vector2(0, 94)
		TextFit.attach(row, 18, TextFit.ACTION_MIN, 100)
		box.add_child(row)
	var page_label := title_label("", 16)
	GameLocale.bind(page_label, "ACH_PAGE", [achievement_page + 1, page_count])
	box.add_child(page_label)
	if achievement_page > 0:
		box.add_child(button("ACH_PREVIOUS", func() -> void:
			achievement_page -= 1
			show_achievements()))
	if achievement_page < page_count - 1:
		box.add_child(button("ACH_NEXT", func() -> void:
			achievement_page += 1
			show_achievements()))
	box.add_child(button("ACH_BACK", close_achievements))
	focus_menu(box)

func close_achievements() -> void:
	if is_instance_valid(overlay): retire_node(overlay)
	overlay = null
	match achievement_return:
		"pause": show_pause()
		"dead": show_death()
		_: show_menu()
	if is_instance_valid(overlay): focus_menu(overlay.get_node("ModalScroll/ModalContent"), "ACH_TITLE")

func show_victory() -> void:
	progression.flush()
	if arena.finished: return
	if is_instance_valid(overlay): retire_node(overlay)
	overlay = null
	current_mode = "victory"
	get_tree().paused = true
	var box := backdrop()
	box.add_child(title_label("VICTORY_TITLE", 40))
	var body := title_label("", 20)
	GameLocale.bind(body, "VICTORY_BODY", [arena.definition.campaign_boss_count])
	box.add_child(body)
	var continue_button := button("VICTORY_ENDLESS", func() -> void:
		if arena.continue_endless():
			resume_run()
			refresh_language())
	continue_button.set_meta("action", "endless_mode")
	box.add_child(continue_button)
	box.add_child(button("MENU_MAIN", show_menu))
	focus_menu(box)

func achievement_row_text(item: AchievementDefinition) -> String:
	var done := progression.completed.has(item.achievement_id)
	var progress := mini(item.target, int(progression.metrics[item.metric]))
	return GameLocale.text("ACH_ROW") % [GameLocale.text("ACH_DONE" if done else "ACH_LOCKED"), GameLocale.text("ACH_NAME_" + item.achievement_id.to_upper()), GameLocale.text("ACH_METRIC_" + item.metric.to_upper()) % [progress, item.target], reward_names(item)]

func open_run_details() -> void:
	if not is_instance_valid(arena) or current_mode not in ["campaign", "endless", "practice", "practice_ui", "pause"]: return
	details_return = current_mode
	details_was_paused = get_tree().paused
	if is_instance_valid(lab):
		lab.exit_navigation()
		lab.hide()
	if is_instance_valid(overlay): retire_node(overlay)
	overlay = null
	current_mode = "details"
	details_scroll_fraction = 0.0
	details_scroll_tick = Time.get_ticks_usec()
	get_tree().paused = true
	var box := backdrop()
	box.add_child(title_label("RUN_DETAILS", 32))
	# Read-only detail navigation scrolls explicitly; initial wrapping must not
	# scroll to the temporary pre-layout height of the focused stats label.
	(overlay.get_node("ModalScroll") as ScrollContainer).follow_focus = false
	var stats_label := title_label("", 18)
	stats_label.name = "RunStats"
	stats_label.focus_mode = Control.FOCUS_ALL
	box.add_child(stats_label)
	for key: String in catalog.definitions:
		var rank := catalog.rank_for(arena.ranks, key)
		if rank <= 0: continue
		var row := title_label("", 18)
		row.set_meta("owned_upgrade", key)
		row.focus_mode = Control.FOCUS_ALL
		box.add_child(row)
	var close_button := button("×", close_run_details)
	close_button.set_meta("details_close", true)
	close_button.custom_minimum_size = Vector2(44, 44)
	close_button.focus_mode = Control.FOCUS_NONE
	TextFit.attach(close_button, 26, 20, 44)
	overlay.add_child(close_button)
	close_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	close_button.offset_left = -60
	close_button.offset_right = -16
	close_button.offset_top = 16
	close_button.offset_bottom = 60
	update_run_details()
	focus_menu(box)

func update_run_details() -> void:
	if current_mode != "details" or not is_instance_valid(overlay): return
	var s := arena.stats
	var stats_label := overlay.get_node("ModalScroll/ModalContent/RunStats") as Label
	stats_label.text = GameLocale.text("RUN_STATS", [
		UpgradeDefinition.number(s.base_damage), UpgradeDefinition.number(s.element_damage), GameLocale.element_name(s.active_element),
		UpgradeDefinition.number(s.attack_speed), UpgradeDefinition.number(s.effective_crit_chance() * 100), UpgradeDefinition.number(s.crit_multiplier),
		UpgradeDefinition.number(s.move_speed), UpgradeDefinition.number(s.arrow_range), UpgradeDefinition.number(s.knockback),
		UpgradeDefinition.number(s.regen), UpgradeDefinition.number(s.pickup_radius), arena.kills, arena.director.boss_count])
	stats_label.text += "\n" + s.effective_pierce_text()
	if s.gravity_mode():
		stats_label.text += "\n" + GameLocale.text("RUN_GRAVITY", [UpgradeDefinition.number(s.gravity_dps), UpgradeDefinition.number(s.gravity_outer_radius), UpgradeDefinition.number(s.gravity_inner_radius)])
	TextFit.refit(stats_label)
	for node in overlay.find_children("*", "Label", true, false):
		if not node.has_meta("owned_upgrade"): continue
		var key := str(node.get_meta("owned_upgrade"))
		var rank := catalog.rank_for(arena.ranks, key)
		node.text = GameLocale.text("UPGRADE_CARD", [catalog.definition(key).display_name, rank, catalog.max_rank(key), catalog.describe_build_rank(key, rank, arena.ranks)])
		TextFit.refit(node)

func close_run_details() -> void:
	if current_mode != "details": return
	if is_instance_valid(overlay): retire_node(overlay)
	overlay = null
	if details_return == "pause":
		show_pause()
		focus_menu(overlay.get_node("ModalScroll/ModalContent"), "RUN_DETAILS")
	else:
		current_mode = details_return
		get_tree().paused = details_was_paused
		# Release modal focus before restoring the live lab navigation.
		var focused := get_viewport().gui_get_focus_owner()
		if focused != null: focused.release_focus()
		if details_return == "practice_ui":
			lab.show()
			lab.enter_navigation()
