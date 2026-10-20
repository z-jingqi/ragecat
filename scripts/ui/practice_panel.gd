class_name PracticePanel
extends PanelContainer
## UI-only practice lab. Every gameplay change goes through a signal.

signal ranks_changed(ranks: Dictionary)
signal command(action: String)
signal option_changed(key: String, value: Variant)

const INK: Color = Color("e8e5fa")
const MUTED: Color = Color("aaa3c6")
const GREEN: Color = Color("a8f5a2")

var _catalog: UpgradeCatalog
var _ranks: Dictionary = {}
var _rank_controls: Dictionary = {}
var _upgrades: VBoxContainer
var _metrics: Label
var _built: bool = false
var _syncing: bool = false
var _pending_metrics: String = "Ready. Build a combo and test it."


func _ready() -> void:
	_build()
	if _catalog != null:
		_populate_upgrades()


func setup(catalog: UpgradeCatalog) -> void:
	_catalog = catalog
	_build()
	_populate_upgrades()


func set_ranks(ranks: Dictionary) -> void:
	_ranks = ranks.duplicate(true)
	_syncing = true
	for key: Variant in _rank_controls:
		var control: SpinBox = _rank_controls[key] as SpinBox
		control.set_value_no_signal(float(_ranks.get(key, 0)))
	_syncing = false


func set_metrics(text: String) -> void:
	_pending_metrics = text
	if is_instance_valid(_metrics):
		_metrics.text = text


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
	var title: Label = Label.new()
	title.text = "LAB / PRACTICE"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", GREEN)
	root.add_child(title)
	_metrics = Label.new()
	_metrics.text = _pending_metrics
	_metrics.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_metrics.custom_minimum_size.y = 64
	_metrics.add_theme_font_size_override("font_size", 12)
	_metrics.add_theme_color_override("font_color", MUTED)
	root.add_child(_metrics)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var content: VBoxContainer = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	scroll.add_child(content)
	_section(content, "SPAWN TARGETS")
	_buttons(content, [["Dummy", "spawn_dummy"], ["Mob", "spawn_mob"], ["Boss", "spawn_boss"]], 3)
	_buttons(content, [["Enemy line", "spawn_line"], ["Enemy group", "spawn_group"]], 2)
	_buttons(content, [["Clear enemies", "clear"], ["Reset lab", "reset"]], 2)
	_buttons(content, [["Heal", "heal"], ["Refill shield", "refill"]], 2)
	_section(content, "QUICK BUILDS")
	_buttons(content, [["Poison + pierce", "preset_poison_pierce"], ["Bleed", "preset_bleed"]], 2)
	_buttons(content, [["Shield + critical", "preset_shieldcrit"]], 1)
	_section(content, "SIMULATION")
	_toggle(content, "Invulnerability", "invulnerability", true)
	_toggle(content, "Enemy AI", "enemy_ai", false)
	_choice(content, "Time", "time_scale", ["Paused", "0.25× slow", "1× normal"], [0.0, 0.25, 1.0], 2)
	_choice(content, "Boss pattern", "boss_mode", ["Alternate", "Charge", "Rocks"], ["alternate", "charge", "rocks"], 0)
	_slider(content, "Warning", "warning_duration", 0.3, 2.0, 0.1, 1.0)
	_slider(content, "Charge width", "charge_width", 40.0, 140.0, 5.0, 80.0)
	_slider(content, "Rock radius", "rock_radius", 20.0, 65.0, 5.0, 35.0)
	_section(content, "UPGRADE RANKS")
	var hint: Label = Label.new()
	hint.text = "Hover an upgrade to inspect its effect."
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", MUTED)
	content.add_child(hint)
	_upgrades = VBoxContainer.new()
	_upgrades.add_theme_constant_override("separation", 5)
	content.add_child(_upgrades)


func _section(parent: VBoxContainer, text: String) -> void:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 11)
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
		button.text = str(spec[0])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 12)
		var action: String = str(spec[1])
		button.pressed.connect(func() -> void: command.emit(action))
		grid.add_child(button)


func _toggle(parent: VBoxContainer, label: String, key: String, initial: bool) -> void:
	var check: CheckButton = CheckButton.new()
	check.focus_mode = Control.FOCUS_NONE
	check.text = label
	check.button_pressed = initial
	check.toggled.connect(func(value: bool) -> void: option_changed.emit(key, value))
	parent.add_child(check)


func _choice(parent: VBoxContainer, label: String, key: String, labels: Array, values: Array, initial: int) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	parent.add_child(row)
	var name_label: Label = Label.new()
	name_label.text = label
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var choice: OptionButton = OptionButton.new()
	for item: Variant in labels:
		choice.add_item(str(item))
	choice.selected = initial
	choice.item_selected.connect(func(index: int) -> void: option_changed.emit(key, values[index]))
	row.add_child(choice)


func _slider(parent: VBoxContainer, label: String, key: String, minimum: float, maximum: float, increment: float, initial: float) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	parent.add_child(row)
	var name_label: Label = Label.new()
	name_label.text = label
	name_label.custom_minimum_size.x = 96.0
	name_label.add_theme_font_size_override("font_size", 12)
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
	value_label.add_theme_font_size_override("font_size", 12)
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
		var label: Label = Label.new()
		label.text = str(definition.get("name", key.capitalize()))
		label.tooltip_text = str(definition.get("description", ""))
		label.mouse_filter = Control.MOUSE_FILTER_PASS
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.add_theme_font_size_override("font_size", 12)
		row.add_child(label)
		var rank: SpinBox = SpinBox.new()
		rank.min_value = 0.0
		var values: Array = definition.get("values", [0, 1, 2, 3])
		rank.max_value = float(definition.get("max_rank", values.size() - 1))
		rank.step = 1.0
		rank.custom_minimum_size.x = 64.0
		rank.value = float(_ranks.get(key, 0))
		rank.tooltip_text = label.tooltip_text
		rank.value_changed.connect(func(value: float) -> void:
			if not _syncing:
				_ranks[key] = int(value)
				ranks_changed.emit(_ranks.duplicate(true))
		)
		row.add_child(rank)
		_rank_controls[key] = rank
