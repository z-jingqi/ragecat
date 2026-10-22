extends Node

@export var arena_definition: ArenaDefinition = preload("res://resources/settings/arena.tres")
@export var ranged_definition: RangedDefinition = preload("res://resources/settings/ranged.tres")
@export var character_definition: CharacterDefinition = preload("res://resources/cat.tres")

const CATALOG = preload("res://scripts/upgrades/upgrade_catalog.gd")
var catalog := UpgradeCatalog.new()
var display_settings := DisplaySettings.new()
var arena: RageArena
var ui := CanvasLayer.new()
var hud: Label
var health_bar: ProgressBar
var xp_bar: ProgressBar
var xp_label: Label
var dash_label: Label
var damage_label: Label
var overlay: Control
var lab: PracticePanel
var current_mode := "menu"
var lab_scale := 1.0
var snapshot_requested := false
var practice_return_to_pause := false

func _ready() -> void:
	display_settings.load_settings()
	TranslationServer.set_locale(display_settings.resolved_language())
	get_window().min_size = Vector2i(1280, 800)
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

func _unhandled_input(event: InputEvent) -> void:
	if (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")) and arena != null:
		get_viewport().set_input_as_handled()
		if current_mode == "upgrade" or current_mode == "dead": return
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
		if control.has_meta("practice_controls") and preferred_key == "practice": initial = control
	if initial != null: call_deferred("grab_live_focus", initial)

func grab_live_focus(control: Control) -> void:
	if is_instance_valid(control) and control.is_inside_tree(): control.grab_focus()

func enter_practice_navigation() -> void:
	if not is_instance_valid(lab): return
	practice_return_to_pause = current_mode == "pause"
	if overlay != null: retire_node(overlay)
	overlay = null
	current_mode = "practice_ui"
	get_tree().paused = true
	lab.enter_navigation()

func return_from_practice_navigation() -> void:
	if current_mode != "practice_ui": return
	lab.exit_navigation()
	if not practice_return_to_pause:
		resume_run()
		return
	show_pause()
	focus_menu(overlay.get_node("ModalScroll/ModalContent"), "practice")

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
	get_tree().paused=false
	Engine.time_scale=1.0
	if is_instance_valid(arena): retire_node(arena)
	arena=null
	clear_ui()
	current_mode="menu"
	var box:=backdrop()
	var brand:=title_label("RAGE CAT",68)
	brand.add_theme_color_override("font_color",Color("ffd57e"))
	box.add_child(brand)
	box.add_child(title_label("MENU_TAGLINE",18))
	box.add_child(title_label("MENU_INTRO",18))
	box.add_child(button("MENU_START",func()->void: start_run(false)))
	box.add_child(button("MENU_PRACTICE",func()->void: start_run(true)))
	box.add_child(health_bar_toggle())
	box.add_child(sound_toggle())
	box.add_child(language_picker())
	box.add_child(button("MENU_QUIT",func()->void: get_tree().quit()))
	box.add_child(title_label("MENU_CONTROLS",15))
	focus_menu(box)

func start_run(practice: bool) -> void:
	get_tree().paused=false
	Engine.time_scale=1.0
	lab_scale=1.0
	if is_instance_valid(arena): retire_node(arena)
	clear_ui()
	arena=RageArena.new()
	arena.definition=arena_definition
	arena.ranged_definition=ranged_definition
	arena.character_definition=character_definition
	arena.practice=practice
	arena.process_mode=Node.PROCESS_MODE_PAUSABLE
	arena.show_enemy_health = display_settings.show_enemy_health
	arena.sound_enabled = display_settings.sound_enabled
	add_child(arena)
	catalog=arena.stats.catalog
	arena.level_ready.connect(show_upgrades)
	arena.run_ended.connect(show_death)
	arena.hud_changed.connect(update_hud)
	current_mode="practice" if practice else "endless"
	var title:=title_label("MENU_PRACTICE" if practice else "MODE_ENDLESS",24)
	title.set_meta("run_title", true)
	title.size.x = 310
	title.position=Vector2(40,20)
	ui.add_child(title)
	hud=title_label("",16)
	hud.position=Vector2(370,20)
	hud.size.x=550
	ui.add_child(hud)
	health_bar=ProgressBar.new()
	health_bar.position=Vector2(40,64)
	health_bar.size=Vector2(280,18)
	health_bar.show_percentage=false
	var hp_style := StyleBoxFlat.new()
	hp_style.bg_color=Color("ed8d87")
	health_bar.add_theme_stylebox_override("fill",hp_style)
	ui.add_child(health_bar)
	xp_bar=ProgressBar.new()
	xp_bar.position=Vector2(340,64)
	xp_bar.size=Vector2(560 if not practice else 240,18)
	xp_bar.show_percentage=false
	var xp_style := StyleBoxFlat.new()
	xp_style.bg_color=Color("74e6bd")
	xp_bar.add_theme_stylebox_override("fill",xp_style)
	ui.add_child(xp_bar)
	xp_label=title_label("",13)
	xp_label.position=Vector2(350,82)
	xp_label.size.x=240
	ui.add_child(xp_label)
	dash_label=title_label("",13)
	dash_label.position=Vector2(40,84)
	dash_label.size.x=280
	ui.add_child(dash_label)
	damage_label=title_label("",13)
	damage_label.position=Vector2(620,82)
	damage_label.size.x=300 if practice else 610
	ui.add_child(damage_label)
	var help:=title_label("HUD_HELP",15)
	help.position=Vector2(40,748)
	help.size.x=1200
	ui.add_child(help)
	if practice:
		lab=PracticePanel.new()
		lab.arena_definition=arena.definition
		lab.position=Vector2(936,104)
		lab.size=Vector2(310,620)
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
	update_hud()

func update_hud() -> void:
	if not is_instance_valid(arena) or hud == null: return
	var s:=arena.stats
	health_bar.max_value=s.max_hp
	health_bar.value=s.hp
	xp_bar.max_value=arena.xp_needed
	xp_bar.value=arena.xp
	xp_label.text=GameLocale.text("HUD_XP") % [arena.xp,arena.xp_needed]
	var dash_remaining := arena.player.dash_cooldown
	dash_label.text = GameLocale.text("HUD_DASH_READY") if dash_remaining <= 0.0 else GameLocale.text("HUD_DASH_TIME") % dash_remaining
	dash_label.add_theme_color_override("font_color",Color("74e6bd") if dash_remaining <= 0.0 else Color("ffd57e"))
	hud.text=GameLocale.text("HUD_STATS") % [s.hp,s.max_hp,s.shields,s.shield_capacity,arena.level,int(arena.director.elapsed)/60,int(arena.director.elapsed)%60,arena.kills,arena.director.boss_count]
	damage_label.text = GameLocale.text("HUD_DAMAGE") % [UpgradeDefinition.number(s.base_damage), UpgradeDefinition.number(s.element_damage), GameLocale.element_name(s.active_element)]
	if s.gravity_mode():
		damage_label.text += GameLocale.text("HUD_GRAVITY") % [UpgradeDefinition.number(s.gravity_dps), arena.bow.gravity_gap_remaining]
	damage_label.text += "\n" + s.effective_pierce_text()
	for label in [hud, xp_label, dash_label, damage_label]: TextFit.refit(label)
	if lab != null:
		lab.set_metrics(GameLocale.text("LAB_METRICS") % [UpgradeDefinition.number(arena.stats.base_damage), UpgradeDefinition.number(arena.stats.element_damage), GameLocale.element_name(arena.stats.active_element), arena.hits, arena.crits, arena.total_damage, int(arena.ranks.get("enchant_rank", 0)), arena.stats.element_skill_rank] + "\n" + s.effective_pierce_text())
		if s.gravity_mode():
			lab.set_metrics(GameLocale.text("LAB_GRAVITY_METRICS") % [UpgradeDefinition.number(s.gravity_dps), UpgradeDefinition.number(s.arrow_speed), UpgradeDefinition.number(s.gravity_outer_radius), UpgradeDefinition.number(s.gravity_inner_radius), arena.bow.gravity_gap_remaining] + "\n" + s.effective_pierce_text())

func show_pause() -> void:
	current_mode="pause"
	get_tree().paused=true
	var box:=backdrop()
	box.add_child(title_label("PAUSE_TITLE",40))
	box.add_child(health_bar_toggle())
	box.add_child(sound_toggle())
	box.add_child(language_picker())
	if arena.practice:
		var practice_button := button("PRACTICE_UI_OPEN", enter_practice_navigation)
		practice_button.set_meta("practice_controls", true)
		box.add_child(practice_button)
	box.add_child(button("PAUSE_RESUME",resume_run))
	box.add_child(button("PAUSE_RESTART",func()->void: start_run(arena.practice)))
	box.add_child(button("MENU_MAIN",show_menu))
	focus_menu(box)

func resume_run() -> void:
	if overlay != null: retire_node(overlay)
	overlay=null
	current_mode="practice" if arena.practice else "endless"
	get_tree().paused=arena.practice and lab_scale==0.0

func show_upgrades() -> void:
	catalog=arena.stats.catalog
	if arena.practice or current_mode=="upgrade": return
	current_mode="upgrade"
	get_tree().paused=true
	var box:=backdrop()
	var heading := title_label("UPGRADE_TITLE", 32)
	GameLocale.bind(heading, "UPGRADE_TITLE", [arena.level])
	box.add_child(heading)
	var candidates:=catalog.eligible(arena.ranks,arena.stats)
	if arena.stats.shields < arena.stats.shield_capacity: candidates.append("refill")
	if arena.stats.hp < arena.stats.max_hp: candidates.append("heal")
	candidates.shuffle()
	var count:=mini(arena.definition.upgrade_choices,candidates.size())
	for i in range(count):
		var key:String=candidates[i]
		var item:=button(upgrade_card_text(key),func()->void: choose_upgrade(key))
		item.set_meta("upgrade_key", key)
		item.custom_minimum_size=Vector2(0,128)
		TextFit.attach(item, 18, TextFit.ACTION_MIN, 160)
		box.add_child(item)
	if count==0:
		box.add_child(title_label("UPGRADE_COMPLETE",20))
		box.add_child(button("UPGRADE_CONTINUE",func()->void: choose_upgrade("continue")))

	focus_menu(box)

func choose_upgrade(key: String) -> void:
	if key=="refill": arena.stats.shields=arena.stats.shield_capacity
	elif key=="heal": arena.player.heal(arena.stats.max_hp*arena.definition.heal_fraction)
	elif key!="continue":
		arena.select_upgrade(key)
		if key=="shield": arena.stats.shields=arena.stats.shield_capacity
	resume_run()

func show_death() -> void:
	current_mode="dead"
	get_tree().paused=true
	var box:=backdrop()
	box.add_child(title_label("DEATH_TITLE",38))
	var summary := title_label("DEATH_STATS", 24)
	GameLocale.bind(summary, "DEATH_STATS", [int(arena.director.elapsed)/60,int(arena.director.elapsed)%60,arena.kills,arena.director.boss_count])
	box.add_child(summary)
	box.add_child(button("DEATH_RETRY",func()->void: start_run(arena.practice)))
	box.add_child(button("MENU_MAIN",show_menu))
	focus_menu(box)

func practice_command(action: String) -> void:
	match action:
		"spawn_dummy", "spawn_mob", "spawn_boss", "spawn_ranged": arena.spawn_enemy(action.trim_prefix("spawn_"),arena.player.position+arena.definition.practice_spawn_offset)
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
			get_tree().paused=current_mode == "practice_ui" or lab_scale==0.0
			Engine.time_scale=maxf(.01,lab_scale)
		"boss_mode":
			arena.boss_mode=str(value)
			for enemy in arena.enemies.get_children():
				if enemy is BossActor:
					enemy.ability_mode=str(value)
					enemy.reset_state()
		_:
			arena.boss_settings[key]=value
			for enemy in arena.enemies.get_children():
				if enemy is BossActor: enemy.set(key,value)

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
	return GameLocale.text("UPGRADE_CARD") % [item.display_name, catalog.choice_rank(arena.ranks, key), catalog.max_rank(key), item.tag, catalog.describe_choice(key, arena.ranks)]

func language_picker() -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_child(title_label("SETTINGS_LANGUAGE", 18))
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
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_inside_tree():
		call_deferred("refresh_language")

func refresh_language() -> void:
	if not is_instance_valid(ui) or not ui.is_inside_tree(): return
	catalog.refresh_translations()
	GameLocale.refresh_tree(ui)
	for control in ui.find_children("*", "Control", true, false):
		if control.has_meta("language_choice"):
			control.set_pressed_no_signal(str(control.get_meta("language_choice")) == TranslationServer.get_locale())
		if control.has_meta("upgrade_key"):
			control.text = upgrade_card_text(str(control.get_meta("upgrade_key")))
			TextFit.refit(control)
	if is_instance_valid(lab): lab.refresh_language()
	if is_instance_valid(arena):
		update_hud()
		for effect in arena.effects.get_children():
			if effect is FloatingText: effect.refresh_language()
