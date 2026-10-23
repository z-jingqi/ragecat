class_name CombatHud
extends Control
## Floating presentation only. The combat bounds never reserve space for the HUD.

signal details_requested
signal pause_requested
signal practice_requested
@export var health_bar_definition: HealthBarDefinition = preload("res://resources/settings/health_bars.tres")
var practice_button: Button

@export_range(0.0, 1.0, 0.05) var nearby_opacity: float = 0.25
@export_range(0.0, 100.0, 1.0) var occlusion_margin: float = 32.0
var health_bar: ProgressBar
var health_text: Label
var level_text: Label
var xp_bar: ProgressBar
var shield_text: Label
var timer_text: Label
var boss_bar: ProgressBar
var boss_text: Label
var status_group: Control
var boss_group: Control
var action_group: HBoxContainer

class ShieldGlyph extends Control:
	func _draw() -> void:
		var shape := PackedVector2Array([Vector2(2, 2), Vector2(18, 2), Vector2(18, 11), Vector2(10, 19), Vector2(2, 11)])
		draw_colored_polygon(shape, Color("9cd8ff"))

class PauseGlyph extends Button:
	func _draw() -> void:
		var center := size * 0.5
		for x in [-5.0, 3.0]: draw_rect(Rect2(center + Vector2(x, -7), Vector2(3, 14)), Color("e8edf5"))

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_group = Control.new()
	status_group.position = Vector2(16, 12)
	status_group.size = Vector2(232, 48)
	status_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(status_group)
	health_bar = _bar(health_bar_definition.fill_color)
	health_bar.position = Vector2.ZERO
	health_bar.size = Vector2(232, 23)
	status_group.add_child(health_bar)
	health_text = _label(16)
	health_text.size = health_bar.size
	health_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_group.add_child(health_text)
	var shield := ShieldGlyph.new()
	shield.position = Vector2(0, 29)
	shield.size = Vector2(20, 20)
	shield.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_group.add_child(shield)
	shield_text = _label(16)
	shield_text.position = Vector2(28, 27)
	shield_text.size = Vector2(90, 24)
	status_group.add_child(shield_text)
	timer_text = _label(22)
	timer_text.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	timer_text.position = Vector2(-90, 12)
	timer_text.size = Vector2(180, 30)
	timer_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(timer_text)
	boss_group = Control.new()
	boss_group.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	boss_group.position = Vector2(-170, 48)
	boss_group.size = Vector2(340, 35)
	boss_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(boss_group)
	boss_text = _label(16)
	boss_text.size = Vector2(340, 24)
	boss_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_group.add_child(boss_text)
	boss_bar = _bar(health_bar_definition.fill_color)
	boss_bar.position = Vector2(0, 26)
	boss_bar.size = Vector2(340, 6)
	boss_group.add_child(boss_bar)
	boss_group.hide()
	xp_bar = _bar(Color("74e6bd"))
	add_child(xp_bar)
	xp_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	xp_bar.offset_top = -6
	xp_bar.offset_bottom = 0
	level_text = _label(16)
	add_child(level_text)
	level_text.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	level_text.offset_left = 16
	level_text.offset_right = 200
	level_text.offset_top = -34
	level_text.offset_bottom = -10
	action_group = HBoxContainer.new()
	add_child(action_group)
	action_group.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	action_group.offset_left = -150
	action_group.offset_right = -16
	action_group.offset_top = 12
	action_group.offset_bottom = 48
	action_group.add_theme_constant_override("separation", 8)
	var details := Button.new()
	GameLocale.bind(details, "RUN_DETAILS")
	details.custom_minimum_size = Vector2(86, 36)
	details.add_theme_font_size_override("font_size", 16)
	details.focus_mode = Control.FOCUS_NONE
	details.pressed.connect(func() -> void: details_requested.emit())
	action_group.add_child(details)
	var pause_button := PauseGlyph.new()
	pause_button.custom_minimum_size = Vector2(36, 36)
	pause_button.focus_mode = Control.FOCUS_NONE
	pause_button.pressed.connect(func() -> void: pause_requested.emit())
	action_group.add_child(pause_button)
	for control in [details, pause_button]:
		var panel := StyleBoxFlat.new()
		panel.bg_color = Color(0.06, 0.09, 0.14, 0.42)
		panel.set_corner_radius_all(5)
		control.add_theme_stylebox_override("normal", panel)

func set_practice_available(enabled: bool) -> void:
	if not enabled: return
	action_group.offset_left = -290
	practice_button = Button.new()
	GameLocale.bind(practice_button, "PRACTICE_UI_OPEN")
	practice_button.custom_minimum_size = Vector2(128, 36)
	practice_button.add_theme_font_size_override("font_size", 16)
	practice_button.focus_mode = Control.FOCUS_NONE
	practice_button.pressed.connect(func() -> void: practice_requested.emit())
	action_group.add_child(practice_button)
	action_group.move_child(practice_button, 0)

func _label(font_size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("f0eee6"))
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.9))
	label.add_theme_constant_override("outline_size", 3)
	return label

func _bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(2)
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.03, 0.04, 0.06, 0.45)
	background.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", background)
	return bar

func update_state(arena: RageArena) -> void:
	var stats := arena.stats
	health_bar.max_value = stats.max_hp
	health_bar.value = stats.hp
	health_text.text = "%s / %s" % [UpgradeDefinition.number(stats.hp), UpgradeDefinition.number(stats.max_hp)]
	shield_text.text = "%d / %d" % [stats.shields, stats.shield_capacity]
	xp_bar.max_value = arena.xp_needed
	xp_bar.value = arena.xp
	level_text.text = GameLocale.text("RUN_LEVEL", [arena.level])
	timer_text.text = "%02d:%02d" % [int(arena.director.elapsed) / 60, int(arena.director.elapsed) % 60]
	var boss: BossActor = null
	for enemy in arena.enemies.get_children():
		if enemy is BossActor and not enemy.is_dead:
			boss = enemy
			break
	boss_group.visible = boss != null
	if boss != null:
		boss_text.text = GameLocale.text("NAME_" + boss.boss_identity.to_upper())
		boss_bar.max_value = boss.max_health
		boss_bar.value = boss.health
	# Fade only small overlays when the player enters their screen area. No opaque
	# HUD rail, map crop, collision exclusion or invisible safety zone is created.
	var player_screen := arena.get_global_transform_with_canvas() * arena.player.position
	for group: Control in [status_group, boss_group, action_group, timer_text, level_text]:
		group.modulate.a = nearby_opacity if group.get_global_rect().grow(occlusion_margin).has_point(player_screen) else 1.0
