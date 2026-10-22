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

func _ready() -> void:
	display_settings.load_settings()
	process_mode = Node.PROCESS_MODE_ALWAYS
	for entry in [["move_left",KEY_A],["move_right",KEY_D],["move_up",KEY_W],["move_down",KEY_S],["dash",KEY_SPACE]]:
		InputMap.add_action(entry[0])
		var event := InputEventKey.new()
		event.physical_keycode = entry[1]
		InputMap.action_add_event(entry[0],event)
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

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and arena != null:
		if current_mode == "upgrade" or current_mode == "dead": return
		if current_mode == "pause": resume_run()
		else: show_pause()
	if event is InputEventKey and event.pressed and event.keycode == KEY_F12:
		DirAccess.make_dir_recursive_absolute("user://screenshots")
		get_viewport().get_texture().get_image().save_png("user://screenshots/capture_%d.png" % Time.get_ticks_msec())

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
	label.text=text
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",Color("ebf2ed"))
	return label

func button(text: String, action: Callable) -> Button:
	var item := Button.new()
	item.text=text
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
	var box := VBoxContainer.new()
	box.position=Vector2(360,160)
	box.size=Vector2(560,500)
	box.add_theme_constant_override("separation",16)
	overlay.add_child(box)
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
	box.add_child(title_label("SMALL CAT.  UNREASONABLE FIREPOWER.",18))
	box.add_child(title_label("Bow-only survival in a never-ending arena.\nMove. Dash. Let the arrows do the arguing.",18))
	box.add_child(button("START ENDLESS",func()->void: start_run(false)))
	box.add_child(button("PRACTICE LAB",func()->void: start_run(true)))
	box.add_child(health_bar_toggle())
	box.add_child(button("QUIT",func()->void: get_tree().quit()))
	box.add_child(title_label("WASD  move   /   SPACE  dash   /   ESC  pause",15))

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
	add_child(arena)
	catalog=arena.stats.catalog
	arena.level_ready.connect(show_upgrades)
	arena.run_ended.connect(show_death)
	arena.hud_changed.connect(update_hud)
	current_mode="practice" if practice else "endless"
	var title:=title_label("RAGE CAT  /  "+("PRACTICE LAB" if practice else "ENDLESS"),24)
	title.position=Vector2(40,20)
	ui.add_child(title)
	hud=title_label("",16)
	hud.position=Vector2(370,20)
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
	ui.add_child(xp_label)
	dash_label=title_label("",13)
	dash_label.position=Vector2(40,84)
	ui.add_child(dash_label)
	damage_label=title_label("",13)
	damage_label.position=Vector2(620,82)
	ui.add_child(damage_label)
	var help:=title_label("WASD move  •  SPACE dash  •  Auto aim / fire  •  ESC pause  •  F12 screenshot",15)
	help.position=Vector2(40,748)
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
	update_hud()

func update_hud() -> void:
	if not is_instance_valid(arena) or hud == null: return
	var s:=arena.stats
	health_bar.max_value=s.max_hp
	health_bar.value=s.hp
	xp_bar.max_value=arena.xp_needed
	xp_bar.value=arena.xp
	xp_label.text="XP %d / %d" % [arena.xp,arena.xp_needed]
	var dash_remaining := arena.player.dash_cooldown
	dash_label.text = "DASH READY  [SPACE]" if dash_remaining <= 0.0 else "DASH %.1fs" % dash_remaining
	dash_label.add_theme_color_override("font_color",Color("74e6bd") if dash_remaining <= 0.0 else Color("ffd57e"))
	hud.text="HP %d/%d  |  SHIELD %d/%d  |  LV %d\n%02d:%02d   •   %d kills   •   %d bosses" % [s.hp,s.max_hp,s.shields,s.shield_capacity,arena.level,int(arena.director.elapsed)/60,int(arena.director.elapsed)%60,arena.kills,arena.director.boss_count]
	damage_label.text = "BASE %s + %s %s" % [UpgradeDefinition.number(s.base_damage), UpgradeDefinition.number(s.element_damage), s.active_element.to_upper() if not s.active_element.is_empty() else "ELEMENT"]
	if lab != null:
		lab.set_metrics("BASE %s + %s %s\nHITS %d  CRITS %d  TOTAL %.2f\nELEMENT Lv%d / SKILL Lv%d" % [UpgradeDefinition.number(arena.stats.base_damage), UpgradeDefinition.number(arena.stats.element_damage), arena.stats.active_element.to_upper(), arena.hits, arena.crits, arena.total_damage, int(arena.ranks.get("enchant_rank", 0)), arena.stats.element_skill_rank])

func show_pause() -> void:
	current_mode="pause"
	get_tree().paused=true
	var box:=backdrop()
	box.add_child(title_label("TAKE A BREATHER",40))
	box.add_child(health_bar_toggle())
	box.add_child(button("RESUME",resume_run))
	box.add_child(button("RESTART",func()->void: start_run(arena.practice)))
	box.add_child(button("MAIN MENU",show_menu))

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
	box.position=Vector2(240,120)
	box.size.x=800
	box.add_child(title_label("LEVEL %d  /  PICK YOUR TROUBLE" % arena.level,32))
	var candidates:=catalog.eligible(arena.ranks,arena.stats)
	if arena.stats.shields < arena.stats.shield_capacity: candidates.append("refill")
	if arena.stats.hp < arena.stats.max_hp: candidates.append("heal")
	candidates.shuffle()
	var count:=mini(arena.definition.upgrade_choices,candidates.size())
	for i in range(count):
		var key:String=candidates[i]
		var text:String
		if key=="refill": text="SECOND WIND  /  Refill all shields"
		elif key=="heal": text="CAT NAP  /  Heal %s%% maximum HP" % catalog._number(arena.definition.heal_fraction*100.0)
		else:
			var definition:Dictionary=catalog.definitions[key]
			text="%s  [%d/%d]  [%s]\n%s" % [definition.name,catalog.choice_rank(arena.ranks,key),catalog.max_rank(key),definition.tag,catalog.describe_choice(key,arena.ranks)]
		var item:=button(text,func()->void: choose_upgrade(key))
		item.custom_minimum_size=Vector2(800,128)
		item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		item.add_theme_font_size_override("font_size",16)
		box.add_child(item)
	if count==0:
		box.add_child(title_label("Every upgrade mastered. Your build is complete.",20))
		box.add_child(button("KEEP FIGHTING",func()->void: choose_upgrade("continue")))

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
	box.add_child(title_label("NINE LIVES? NOT TODAY.",38))
	box.add_child(title_label("Survived %02d:%02d\n%d enemies defeated  /  %d bosses defeated" % [int(arena.director.elapsed)/60,int(arena.director.elapsed)%60,arena.kills,arena.director.boss_count],24))
	box.add_child(button("ONE MORE RUN",func()->void: start_run(arena.practice)))
	box.add_child(button("MAIN MENU",show_menu))

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
			get_tree().paused=lab_scale==0.0
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
	toggle.text = "Enemy health bars (Boss always visible)"
	toggle.button_pressed = display_settings.show_enemy_health
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.toggled.connect(func(enabled: bool) -> void:
		display_settings.show_enemy_health = enabled
		var error := display_settings.save_settings()
		if error != OK: push_warning("Could not persist display preference: " + error_string(error))
		if is_instance_valid(arena): arena.set_enemy_health_bars(enabled)
	)
	return toggle
