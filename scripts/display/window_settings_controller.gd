class_name WindowSettingsController
extends Node
## Confirmed preferences and a reversible, wall-clock timed display transaction.
signal changed
signal preview_finished(kept: bool)
const WINDOWED := 0
const FULLSCREEN := 3
const EXCLUSIVE := 4
@export var definition: WindowDefinition = preload("res://resources/settings/window.tres")
var settings_path := DisplaySettings.PATH
var confirmed: Dictionary = {}
var active: Dictionary = {}
var previewing := false
var deadline_msec := 0
var native_enabled := true
var last_save_error := OK
var _window: Window

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_window = get_window()
	native_enabled = native_enabled and DisplayServer.get_name() != "headless"
	confirmed = read_preferences()
	active = confirmed.duplicate()
	apply_native(active)

func supported_modes(backend: String = DisplayServer.get_name(), platform: String = OS.get_name()) -> Array[int]:
	var modes: Array[int] = [WINDOWED, FULLSCREEN]
	if platform in ["Windows", "macOS", "Linux", "FreeBSD", "NetBSD", "OpenBSD"] and backend.to_lower() != "wayland": modes.append(EXCLUSIVE)
	return modes

func usable_rect() -> Rect2i:
	if not native_enabled or not is_instance_valid(_window): return Rect2i(0, 0, 1920, 1080)
	var screen := clampi(_window.current_screen, 0, maxi(0, DisplayServer.get_screen_count() - 1))
	var rect := DisplayServer.screen_get_usable_rect(screen)
	if rect.size.x <= 0 or rect.size.y <= 0: rect = Rect2i(DisplayServer.screen_get_position(screen), DisplayServer.screen_get_size(screen))
	return rect

func available_sizes(area: Vector2i = usable_rect().size) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var limit := Vector2i(maxi(1, area.x - maxi(0, definition.decoration_margin.x)), maxi(1, area.y - maxi(0, definition.decoration_margin.y)))
	for value in definition.presets:
		if value.x > 0 and value.y > 0 and value.x <= limit.x and value.y <= limit.y and not result.has(value): result.append(value)
	if result.is_empty():
		var scale := minf(float(limit.x) / 1280.0, float(limit.y) / 800.0)
		result.append(Vector2i(maxi(1, floori(1280 * scale)), maxi(1, floori(800 * scale))))
	result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x * a.y < b.x * b.y)
	return result

func initial_size(area: Vector2i = usable_rect().size) -> Vector2i:
	var sizes := available_sizes(area)
	var result := sizes[0]
	var target := Vector2(area) * clampf(definition.initial_screen_fraction, 0.5, 1.0)
	for value in sizes:
		if value.x <= target.x and value.y <= target.y: result = value
	return result

func sanitize(value: Dictionary, area: Vector2i = usable_rect().size) -> Dictionary:
	var mode: Variant = value.get("mode", WINDOWED)
	if not mode is int or mode not in supported_modes(): mode = WINDOWED
	var size: Variant = value.get("size", initial_size(area))
	if not size is Vector2i or size not in available_sizes(area): size = initial_size(area)
	return {"mode": mode, "size": size}

func read_preferences() -> Dictionary:
	var config := ConfigFile.new()
	if config.load(settings_path) != OK: return sanitize({})
	return sanitize({"mode": config.get_value("window", "mode", WINDOWED), "size": config.get_value("window", "size", Vector2i.ZERO)})

func apply_native(value: Dictionary) -> void:
	if not is_instance_valid(_window): return
	# Resizing can change the monitor with largest overlap. Capture it first.
	var target_area := usable_rect()
	_window.unresizable = true
	_window.min_size = Vector2i(64, 64)
	_window.max_size = Vector2i.ZERO
	_window.content_scale_size = Vector2i(1280, 800)
	_window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	_window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	if not native_enabled: return
	_window.mode = value.mode
	if value.mode == WINDOWED:
		_window.borderless = false
		_window.size = value.size
		# Wayland does not implement RESIZE_DISABLED; equal bounds enforce presets.
		_window.min_size = value.size
		_window.max_size = value.size
		_window.position = target_area.position + (target_area.size - _window.size) / 2

func begin_preview(mode: int, size: Vector2i) -> void:
	if previewing: cancel_preview()
	active = sanitize({"mode": mode, "size": size})
	if active == confirmed: return
	previewing = true
	deadline_msec = Time.get_ticks_msec() + int(clampf(definition.confirmation_seconds, 5.0, 30.0) * 1000)
	apply_native(active)
	changed.emit()

func seconds_remaining(now_msec: int = Time.get_ticks_msec()) -> int:
	return maxi(0, ceili(float(deadline_msec - now_msec) / 1000.0)) if previewing else 0

func confirm_preview() -> void:
	if not previewing: return
	# Never commit a timed-out choice even if its input arrived between frames.
	if Time.get_ticks_msec() >= deadline_msec:
		cancel_preview()
		return
	var config := ConfigFile.new()
	config.load(settings_path)
	config.set_value("window", "mode", active.mode)
	config.set_value("window", "size", active.size)
	last_save_error = config.save(settings_path)
	if last_save_error != OK:
		push_warning("Could not save display preference: " + error_string(last_save_error))
		cancel_preview()
		return
	confirmed = active.duplicate()
	previewing = false
	preview_finished.emit(true)
	changed.emit()

func cancel_preview() -> void:
	if not previewing: return
	previewing = false
	confirmed = sanitize(confirmed)
	active = confirmed.duplicate()
	apply_native(active)
	preview_finished.emit(false)
	changed.emit()

func _process(_delta: float) -> void:
	if previewing and Time.get_ticks_msec() >= deadline_msec: cancel_preview()

func _exit_tree() -> void:
	cancel_preview()
