class_name PracticePanel
extends PanelContainer
## UI-only practice lab. Every gameplay change goes through a signal.

signal ranks_changed(ranks: Dictionary)
signal command(action: String)
signal option_changed(key: String, value: Variant)
signal navigation_requested
signal navigation_closed

const INK: Color = Color("e8e5fa")
const MUTED: Color = Color("aaa3c6")
const GREEN: Color = Color("a8f5a2")

# Explicit, focusable details. No native hover-help dependency.
class UpgradeLabel extends Label:
	signal details_requested
	signal rank_step_requested(direction: int)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT:
			queue_redraw()

	func _draw() -> void:
		if has_focus():
			draw_rect(Rect2(Vector2.ZERO, size), PracticePanel.GREEN, false, 1.0)

	func _gui_input(event: InputEvent) -> void:
		var clicked: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
		if clicked or event.is_action_pressed("ui_accept"):
			details_requested.emit()
			accept_event()
		elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
			rank_step_requested.emit(-1 if event.is_action_pressed("ui_left") else 1)
			accept_event()

class UpgradeRank extends SpinBox:
	pass

@export var arena_definition: ArenaDefinition = preload("res://resources/settings/arena.tres")
var _catalog: UpgradeCatalog
var _ranks: Dictionary = {}
var _rank_controls: Dictionary = {}
var _upgrades: VBoxContainer
var _metrics: Label
var _built: bool = false
var _syncing: bool = false
var _pending_metrics: String = ""
var _details_popup: Control
var _details_layer: CanvasLayer
var _details_scroll: ScrollContainer
var _details_focus: WeakRef
var navigation_active: bool = false
var _navigation_controls: Array[Control] = []
var _details_scroll_tick: int = 0
var _details_scroll_fraction: float = 0.0
var _practice_scroll: ScrollContainer
var _details_body: Label
var _details_title: Label
var _details_key: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	if _catalog != null:
		_populate_upgrades()


func setup(catalog: UpgradeCatalog) -> void:
	_catalog = catalog
	_build()
	_populate_upgrades()


func set_ranks(ranks: Dictionary) -> void:
	_ranks = _catalog.normalize_ranks(ranks)
	_syncing = true
	for key: Variant in _rank_controls:
		var control: SpinBox = _rank_controls[key] as SpinBox
		control.set_value_no_signal(float(_catalog.rank_for(_ranks, str(key))))
		var label := control.get_parent().get_child(0) as Label
		_update_rank_description(str(key), label, control)
	_syncing = false


func set_metrics(text: String) -> void:
	_pending_metrics = text
	if is_instance_valid(_metrics):
		_metrics.text = text
		TextFit.refit(_metrics)


func _style(background: Color, border: Color, corners: int = 8) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(corners)
	box.content_margin_left = 10.0
	box.content_margin_right = 10.0
	box.content_margin_top = 7.0
	box.content_margin_bottom = 7.0
	return box


func _build() -> void:
	if _built:
		return
	_built = true
	custom_minimum_size = Vector2(300, 300)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_stylebox_override("panel", _style(Color("171323"), Color("453653"), 14))
	add_theme_font_size_override("font_size", 14)
	var lab_theme: Theme = Theme.new()
	lab_theme.default_font_size = 14
	lab_theme.set_color("font_color", "Label", INK)
	lab_theme.set_color("font_color", "Button", INK)
	lab_theme.set_color("font_hover_color", "Button", GREEN)
	lab_theme.set_stylebox("normal", "Button", _style(Color("282037"), Color("473b58"), 6))
	lab_theme.set_stylebox("hover", "Button", _style(Color("393047"), Color("95c792"), 6))
	lab_theme.set_stylebox("pressed", "Button", _style(Color("3c4b39"), GREEN, 6))
	theme = lab_theme
	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	add_child(root)
	var close := Button.new()
	close.name = "CollapsePractice"
	close.text = "×"
	close.add_theme_font_size_override("font_size", 20)
	close.custom_minimum_size = Vector2(36, 30)
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func() -> void: navigation_closed.emit())
	root.add_child(close)
	_metrics = Label.new()
	_metrics.text = _pending_metrics
	TextFit.attach(_metrics, 14, TextFit.BODY_MIN)
	_metrics.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_metrics.custom_minimum_size.y = 64
	_metrics.add_theme_font_size_override("font_size", 14)
	_metrics.add_theme_color_override("font_color", MUTED)
	root.add_child(_metrics)
	var scroll: ScrollContainer = ScrollContainer.new()
	_practice_scroll = scroll
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var content: VBoxContainer = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	scroll.add_child(content)
	_section(content, "LAB_TARGETS")
	_buttons(content, [["LAB_DUMMY", "spawn_dummy"], ["NAME_HORNLING", "spawn_mob"]], 2)
	_buttons(content, [["NAME_SPITTER", "spawn_ranged"], ["NAME_SWIFTFANG", "spawn_swiftfang"]], 2)
	_buttons(content, [["NAME_ELITE_HORNLING", "spawn_elite_hornling"]], 1)
	_choice(content, "LAB_BOSS_IDENTITY", "boss_identity", ["NAME_MOUNTAINBREAKER", "NAME_BEASTCALLER", "NAME_WILDFIRE"], ["mountainbreaker", "beastcaller", "wildfire"], 0, true)
	_choice(content, "LAB_BOSS_PHASE", "boss_phase", ["LAB_PHASE_ONE", "LAB_PHASE_TWO"], [1, 2], 0)
	_buttons(content, [["LAB_SPAWN_BOSS", "spawn_boss"]], 1)
	_buttons(content, [["LAB_LINE", "spawn_line"], ["LAB_GROUP", "spawn_group"]], 2)
	_buttons(content, [["LAB_CLEAR", "clear"], ["LAB_RESET", "reset"]], 2)
	_buttons(content, [["LAB_HEAL", "heal"], ["LAB_REFILL", "refill"]], 2)
	_section(content, "LAB_BUILDS")
	_buttons(content, [["LAB_FIRE", "preset_fire"], ["LAB_LIGHTNING", "preset_lightning"]], 2)
	_buttons(content, [["LAB_ICE", "preset_ice"], ["LAB_DARK", "preset_dark"]], 2)
	_buttons(content, [["LAB_SHIELD_CRIT", "preset_shieldcrit"]], 1)
	_buttons(content, [["LAB_SPLIT", "preset_split"], ["LAB_VOLLEY", "preset_burst"]], 2)
	_buttons(content, [["LAB_FAN", "preset_fan"], ["LAB_LONG_DRAW", "preset_long"]], 2)
	_section(content, "LAB_SIMULATION")
	_toggle(content, "LAB_INVULNERABLE", "invulnerability", true)
	_toggle(content, "LAB_AI", "enemy_ai", false)
	_choice(content, "LAB_TIME", "time_scale", ["LAB_TIME_PAUSE", "LAB_TIME_SLOW", "LAB_TIME_NORMAL"], [0.0, 0.25, 1.0], 2)
	_choice(content, "LAB_BOSS_PATTERN", "boss_mode", ["LAB_ALTERNATE", "LAB_CHARGE", "LAB_ROCKS"], ["alternate", "charge", "rocks"], 0)
	_slider(content, "LAB_WARNING", "warning_duration", 0.3, 2.0, 0.1, arena_definition.boss_warning_duration)
	_slider(content, "LAB_CHARGE_WIDTH", "charge_width", 40.0, 140.0, 5.0, arena_definition.boss_charge_width)
	_slider(content, "LAB_ROCK_RADIUS", "rock_radius", 20.0, 65.0, 5.0, arena_definition.boss_rock_radius)
	_section(content, "LAB_RANKS")
	var hint: Label = Label.new()
	GameLocale.bind(hint, "LAB_HINT")
	TextFit.attach(hint, 14, TextFit.BODY_MIN)
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", MUTED)
	content.add_child(hint)
	_upgrades = VBoxContainer.new()
	_upgrades.add_theme_constant_override("separation", 5)
	content.add_child(_upgrades)


func _section(parent: VBoxContainer, text: String) -> void:
	var label: Label = Label.new()
	GameLocale.bind(label, text)
	TextFit.attach(label, 16, TextFit.ACTION_MIN, 48)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", GREEN)
	parent.add_child(label)


func _buttons(parent: VBoxContainer, specs: Array, columns: int) -> void:
	var grid: GridContainer = GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 5)
	parent.add_child(grid)
	for spec: Array in specs:
		var button: Button = Button.new()
		button.focus_mode = Control.FOCUS_NONE
		GameLocale.bind(button, str(spec[0]))
		TextFit.attach(button, 18, TextFit.ACTION_MIN, 80)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 16)
		var action: String = str(spec[1])
		button.set_meta("practice_action", action)
		button.pressed.connect(func() -> void: command.emit(action))
		grid.add_child(button)


func _toggle(parent: VBoxContainer, label: String, key: String, initial: bool) -> void:
	var check: CheckButton = CheckButton.new()
	check.focus_mode = Control.FOCUS_NONE
	GameLocale.bind(check, label)
	TextFit.attach(check, 16, TextFit.ACTION_MIN, 64)
	check.button_pressed = initial
	check.toggled.connect(func(value: bool) -> void: option_changed.emit(key, value))
	parent.add_child(check)


func _choice(parent: VBoxContainer, label: String, key: String, labels: Array, values: Array, initial: int, vertical: bool = false) -> void:
	# Keep lab selections inside the panel. Native Popup windows can reconnect
	# root focus signals incorrectly when repeatedly opened during slow/pause.
	var heading := Label.new()
	GameLocale.bind(heading, label)
	TextFit.attach(heading, 16, TextFit.ACTION_MIN, 48)
	heading.add_theme_font_size_override("font_size", 14)
	parent.add_child(heading)
	var row: BoxContainer = VBoxContainer.new() if vertical else HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)
	var group := ButtonGroup.new()
	for i in range(labels.size()):
		var choice := Button.new()
		GameLocale.bind(choice, str(labels[i]))
		TextFit.attach(choice, 16, TextFit.ACTION_MIN, 64)
		choice.focus_mode = Control.FOCUS_NONE
		choice.toggle_mode = true
		choice.button_group = group
		choice.button_pressed = i == initial
		choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choice.add_theme_font_size_override("font_size", 16)
		var value: Variant = values[i]
		choice.set_meta("practice_option", key)
		choice.set_meta("practice_value", value)
		choice.pressed.connect(func() -> void: option_changed.emit(key, value))
		row.add_child(choice)


func _slider(parent: VBoxContainer, label: String, key: String, minimum: float, maximum: float, increment: float, initial: float) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	parent.add_child(row)
	var name_label: Label = Label.new()
	GameLocale.bind(name_label, label)
	TextFit.attach(name_label, 14, TextFit.BODY_MIN, 48)
	name_label.custom_minimum_size.x = 96.0
	name_label.add_theme_font_size_override("font_size", 14)
	row.add_child(name_label)
	var slider: HSlider = HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = increment
	slider.value = initial
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	var value_label: Label = Label.new()
	value_label.custom_minimum_size.x = 34.0
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.text = str(initial)
	value_label.add_theme_font_size_override("font_size", 14)
	row.add_child(value_label)
	slider.value_changed.connect(func(value: float) -> void:
		value_label.text = str(snappedf(value, increment))
		option_changed.emit(key, value)
	)


func _populate_upgrades() -> void:
	if _catalog == null or _upgrades == null:
		return
	for child: Node in _upgrades.get_children():
		_upgrades.remove_child(child)
		child.queue_free()
	_rank_controls.clear()
	for raw_key: Variant in _catalog.definitions:
		var key: String = str(raw_key)
		var definition: Dictionary = _catalog.definitions[raw_key]
		var row: HBoxContainer = HBoxContainer.new()
		_upgrades.add_child(row)
		var label := UpgradeLabel.new()
		GameLocale.bind(label, _catalog.definition(key).name_key)
		TextFit.attach(label, 16, TextFit.BODY_MIN, 48)
		label.set_meta("details_text", "")
		label.mouse_filter = Control.MOUSE_FILTER_STOP
		label.focus_mode = Control.FOCUS_NONE
		label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		label.details_requested.connect(func() -> void: show_upgrade_details(key))
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		label.add_theme_font_size_override("font_size", 14)
		row.add_child(label)
		var rank: SpinBox = UpgradeRank.new()
		rank.focus_mode = Control.FOCUS_NONE
		rank.get_line_edit().focus_mode = Control.FOCUS_NONE
		rank.min_value = 0.0
		var values: Array = definition.get("values", [0, 1, 2, 3])
		rank.max_value = float(definition.get("max_rank", values.size() - 1))
		rank.step = 1.0
		rank.custom_minimum_size.x = 64.0
		rank.value = float(_catalog.rank_for(_ranks, str(key)))
		label.rank_step_requested.connect(func(direction: int) -> void:
			rank.value += direction * rank.step
		)
		_update_rank_description(key, label, rank)
		rank.value_changed.connect(func(value: float) -> void:
			if not _syncing:
				_ranks = _catalog.practice_change(_ranks, key, int(value))
				set_ranks(_ranks)
				ranks_changed.emit(_ranks.duplicate(true))
				if navigation_active: label.grab_focus()
		)
		row.add_child(rank)
		_rank_controls[key] = rank
	_refresh_navigation_controls()

func _update_rank_description(key: String, label: Label, rank: SpinBox) -> void:
	label.text = _catalog.definition(key).display_name
	if key == "pierce":
		var inactive := int(_ranks.get("element_skill_rank", 0)) > 0 and str(_ranks.get("element_type", "")) in ["dark", "fire"]
		label.text = GameLocale.text("RANK_INACTIVE", [_catalog.definition(key).display_name]) if inactive else _catalog.definition(key).display_name
	var description := GameLocale.text("RANK_TOOLTIP") % [_catalog.definition(key).tag, _catalog.rank_for(_ranks, key), _catalog.max_rank(key), _catalog.describe_build_rank(key, _catalog.rank_for(_ranks, key), _ranks)]
	label.set_meta("details_text", description)
	rank.set_meta("details_text", description)
	TextFit.refit(label)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_inside_tree() and _built:
		call_deferred("refresh_language")

func refresh_language() -> void:
	if not _built or _catalog == null: return
	_catalog.refresh_translations()
	GameLocale.refresh_tree(self)
	set_ranks(_ranks)
	_refresh_upgrade_details()


func enter_navigation() -> void:
	navigation_active = true
	_refresh_navigation_controls()
	if not _navigation_controls.is_empty():
		_navigation_controls[0].grab_focus()


func exit_navigation() -> void:
	_close_upgrade_details()
	navigation_active = false
	_refresh_navigation_controls()


func _refresh_navigation_controls() -> void:
	_navigation_controls.clear()
	_collect_navigation_controls(self)
	for i in _navigation_controls.size():
		var control := _navigation_controls[i]
		control.focus_mode = Control.FOCUS_ALL if navigation_active else Control.FOCUS_NONE
		control.focus_neighbor_top = control.get_path_to(_navigation_controls[posmod(i - 1, _navigation_controls.size())])
		control.focus_neighbor_bottom = control.get_path_to(_navigation_controls[(i + 1) % _navigation_controls.size()])
		if control is UpgradeLabel:
			control.focus_neighbor_left = control.get_path_to(control)
			control.focus_neighbor_right = control.get_path_to(control)
		control.focus_previous = control.focus_neighbor_top
		control.focus_next = control.focus_neighbor_bottom


func _collect_navigation_controls(node: Node) -> void:
	for child: Node in node.get_children():
		if child is CanvasLayer: continue
		if child is BaseButton or child is UpgradeLabel or child is HSlider:
			_navigation_controls.append(child as Control)
		elif child is LineEdit:
			(child as Control).focus_mode = Control.FOCUS_NONE
		_collect_navigation_controls(child)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var elapsed := minf(float(now - _details_scroll_tick) / 1000000.0, 0.1)
	_details_scroll_tick = now
	if is_instance_valid(_details_scroll):
		var direction := Input.get_axis("ui_up", "ui_down")
		for device in Input.get_connected_joypads():
			if absf(Input.get_joy_axis(device, JOY_AXIS_LEFT_Y)) > 0.2:
				direction = float(Input.is_physical_key_pressed(KEY_DOWN) or Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_DOWN)) - float(Input.is_physical_key_pressed(KEY_UP) or Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_UP))
		if is_zero_approx(direction):
			_details_scroll_fraction = 0.0
		else:
			_scroll_details_by(direction * 300.0 * elapsed)


func _scroll_details_by(distance: float) -> void:
	# Preserve subpixel movement at high refresh rates and small stick deflections.
	# Relative integer deltas stay synchronized with mouse-wheel/key scrolling.
	_details_scroll_fraction += distance
	var pixels := int(_details_scroll_fraction)
	_details_scroll_fraction -= pixels
	if is_instance_valid(_details_scroll):
		_details_scroll.scroll_vertical += pixels


func _input(event: InputEvent) -> void:
	if navigation_active and event is InputEventJoypadMotion and event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		# This live panel uses D-pad navigation; left stick belongs to the player.
		get_viewport().set_input_as_handled()
		return
	if is_instance_valid(_details_popup):
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept") or (InputMap.has_action("pause") and event.is_action_pressed("pause")):
			get_viewport().set_input_as_handled()
			_close_upgrade_details()
		elif event.is_action_pressed("ui_down") or event.is_action_pressed("ui_up") or event.is_action_pressed("ui_page_down") or event.is_action_pressed("ui_page_up"):
			var direction := -1 if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_page_up") else 1
			var amount := 360 if event.is_action_pressed("ui_page_up") or event.is_action_pressed("ui_page_down") else 64
			if not event is InputEventJoypadMotion and not event.is_echo():
				_details_scroll_fraction = 0.0
				_details_scroll.scroll_vertical += direction * amount
			get_viewport().set_input_as_handled()
		elif event.is_action("ui_left") or event.is_action("ui_right") or event.is_action("ui_focus_next") or event.is_action("ui_focus_prev"):
			get_viewport().set_input_as_handled()
	elif navigation_active and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		navigation_closed.emit()


func show_upgrade_details(key: String) -> void:
	if not _rank_controls.has(key): return
	if not navigation_active:
		navigation_requested.emit()
		# Standalone panel fixtures can still use the explicit details UI.
		if not navigation_active: enter_navigation()
	_close_upgrade_details()
	_details_focus = weakref((_rank_controls[key] as Control).get_parent().get_child(0))
	_details_key = key
	_details_layer = CanvasLayer.new()
	_details_layer.layer = 100
	_details_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_details_layer)
	_details_popup = Control.new()
	_details_popup.name = "UpgradeDetails"
	_details_popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_details_popup.theme = theme.duplicate() as Theme
	_details_popup.theme.default_font = preload("res://resources/fonts/ragecat-ui-subset.otf")
	_details_layer.add_child(_details_popup)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.7)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_details_popup.add_child(shade)
	var panel := Panel.new()
	panel.name = "DetailsPanel"
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -320
	panel.offset_right = 320
	panel.offset_top = -290
	panel.offset_bottom = 290
	panel.add_theme_stylebox_override("panel", _style(Color("171323"), Color("746487"), 8))
	_details_popup.add_child(panel)
	var content := VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 16
	content.offset_right = -16
	content.offset_top = 16
	content.offset_bottom = -16
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)
	_details_title = Label.new()
	_details_title.add_theme_color_override("font_color", GREEN)
	TextFit.attach(_details_title, 20, TextFit.ACTION_MIN, 80)
	content.add_child(_details_title)
	_details_scroll = ScrollContainer.new()
	_details_scroll.name = "DescriptionScroll"
	_details_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_details_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(_details_scroll)
	_details_body = Label.new()
	_details_body.name = "FullDescription"
	_details_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_details_body.add_theme_color_override("font_color", INK)
	TextFit.attach(_details_body, 16, TextFit.BODY_MIN)
	_details_scroll.add_child(_details_body)
	var hint := Label.new()
	GameLocale.bind(hint, "DETAILS_HINT")
	TextFit.attach(hint, 14, TextFit.BODY_MIN)
	content.add_child(hint)
	var close := Button.new()
	close.name = "CloseDetails"
	GameLocale.bind(close, "DETAILS_CLOSE")
	TextFit.attach(close, 18, TextFit.ACTION_MIN, 48)
	close.pressed.connect(_close_upgrade_details)
	content.add_child(close)
	_refresh_upgrade_details()
	close.grab_focus()


func _refresh_upgrade_details() -> void:
	if not is_instance_valid(_details_popup) or not _rank_controls.has(_details_key): return
	var rank: SpinBox = _rank_controls[_details_key]
	var label := rank.get_parent().get_child(0) as Label
	_details_title.text = label.text
	_details_body.text = str(label.get_meta("details_text", ""))
	TextFit.refit(_details_title)
	TextFit.refit(_details_body)


func _close_upgrade_details() -> void:
	var layer := _details_layer
	_details_popup = null
	_details_layer = null
	_details_scroll = null
	_details_scroll_fraction = 0.0
	_details_body = null
	_details_title = null
	_details_key = ""
	if is_instance_valid(layer):
		remove_child(layer)
		layer.queue_free()
	if navigation_active and _details_focus != null:
		var previous := _details_focus.get_ref() as Control
		if is_instance_valid(previous): previous.grab_focus()
	_details_focus = null
