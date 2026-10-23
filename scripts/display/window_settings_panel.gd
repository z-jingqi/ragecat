class_name WindowSettingsPanel
extends VBoxContainer
signal closed
var controller: WindowSettingsController
var mode_choice: OptionButton
var size_choice: OptionButton
var apply_button: Button
var back_button: Button
var confirmation: VBoxContainer
var countdown: Label
var revert_button: Button
var modes: Array[int] = []
var sizes: Array[Vector2i] = []
var _showing_desktop := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_theme_constant_override("separation", 16)
	add_child(make_label("DISPLAY_TITLE", 32))
	mode_choice = OptionButton.new()
	mode_choice.custom_minimum_size.y = 48
	mode_choice.add_theme_font_size_override("font_size", 20)
	modes = controller.supported_modes()
	for mode in modes: mode_choice.add_item(GameLocale.text(mode_key(mode)), mode)
	add_child(mode_choice)
	size_choice = OptionButton.new()
	size_choice.custom_minimum_size.y = 48
	size_choice.add_theme_font_size_override("font_size", 20)
	add_child(size_choice)
	apply_button = make_button("DISPLAY_APPLY", apply_choice)
	add_child(apply_button)
	back_button = make_button("DISPLAY_BACK", close_panel)
	add_child(back_button)
	confirmation = VBoxContainer.new()
	confirmation.add_theme_constant_override("separation", 16)
	add_child(confirmation)
	countdown = make_label("", 24)
	confirmation.add_child(countdown)
	revert_button = make_button("DISPLAY_REVERT", controller.cancel_preview)
	confirmation.add_child(revert_button)
	confirmation.add_child(make_button("DISPLAY_KEEP", controller.confirm_preview))
	mode_choice.item_selected.connect(func(_index: int) -> void: refresh_mode())
	controller.changed.connect(refresh)
	refresh()
	call_deferred("focus_live", mode_choice)

static func mode_key(mode: int) -> String:
	return "DISPLAY_EXCLUSIVE" if mode == WindowSettingsController.EXCLUSIVE else ("DISPLAY_FULLSCREEN" if mode == WindowSettingsController.FULLSCREEN else "DISPLAY_WINDOWED")

func make_label(key: String, font_size: int) -> Label:
	var label := Label.new()
	GameLocale.bind(label, key)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	TextFit.attach(label, font_size, 16, 100)
	return label

func make_button(key: String, callback: Callable) -> Button:
	var control := Button.new()
	GameLocale.bind(control, key)
	control.custom_minimum_size = Vector2(260, 48)
	TextFit.attach(control, 20, 16, 68)
	control.pressed.connect(callback)
	return control

func refresh() -> void:
	mode_choice.select(maxi(0, modes.find(int(controller.active.mode))))
	sizes = controller.available_sizes()
	size_choice.clear()
	for value in sizes: size_choice.add_item("%d × %d" % [value.x, value.y])
	_showing_desktop = false
	size_choice.select(maxi(0, sizes.find(controller.active.size)))
	var pending := controller.previewing
	confirmation.visible = pending
	mode_choice.disabled = pending
	apply_button.disabled = pending
	back_button.disabled = pending
	refresh_mode()
	if pending: call_deferred("focus_live", revert_button)
	elif is_inside_tree(): call_deferred("focus_live", apply_button)

func refresh_mode() -> void:
	var fullscreen := mode_choice.get_selected_id() != WindowSettingsController.WINDOWED
	size_choice.disabled = fullscreen or controller.previewing
	# On fullscreen modes the selector explicitly shows desktop size, not a fake resolution.
	if fullscreen:
		_showing_desktop = true
		size_choice.clear()
		var desktop := DisplayServer.screen_get_size() if controller.native_enabled else Vector2i(1920, 1080)
		size_choice.add_item(GameLocale.text("DISPLAY_DESKTOP") % [desktop.x, desktop.y])
	elif _showing_desktop:
		_showing_desktop = false
		size_choice.clear()
		for value in sizes: size_choice.add_item("%d × %d" % [value.x, value.y])
		size_choice.select(maxi(0, sizes.find(controller.active.size)))

func apply_choice() -> void:
	var size: Vector2i = controller.active.size
	if mode_choice.get_selected_id() == WindowSettingsController.WINDOWED and size_choice.selected >= 0: size = sizes[size_choice.selected]
	controller.begin_preview(mode_choice.get_selected_id(), size)

func close_panel() -> void:
	controller.cancel_preview()
	closed.emit()

func _process(_delta: float) -> void:
	if controller.previewing: GameLocale.bind(countdown, "DISPLAY_CONFIRM", [controller.seconds_remaining()])

func _exit_tree() -> void:
	if is_instance_valid(controller): controller.cancel_preview()

func focus_live(control: Control) -> void:
	if is_inside_tree() and is_instance_valid(control) and control.is_inside_tree() and control.is_visible_in_tree(): control.grab_focus()
