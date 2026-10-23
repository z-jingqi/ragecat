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
var apply_pending := false
var apply_error_key := ""
var _native_target: Dictionary = {}
var _native_deadline_msec := 0
var _native_retry_msec := 0
var _native_retried := false
var _window: Window

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_window = get_window()
	native_enabled = native_enabled and DisplayServer.get_name() != "headless"
	confirmed = read_preferences()
	active = confirmed.duplicate()
	apply_native(active)

static func has_parent_window(arguments: PackedStringArray) -> bool:
	for index in range(arguments.size()):
		var argument := arguments[index]
		if argument == "--wid" and index + 1 < arguments.size():
			return arguments[index + 1] != "0" and not arguments[index + 1].is_empty()
		if argument.begins_with("--wid="):
			return argument.trim_prefix("--wid=") not in ["", "0"]
	return false

func is_host_embedded() -> bool:
	# --wid is consumed by engine startup, so it is absent from get_cmdline_args().
	# Window.is_embedded() refers to in-game subwindows, not the editor's host.
	return Engine.is_embedded_in_editor() or has_parent_window(OS.get_cmdline_args()) or (is_instance_valid(_window) and _window.is_embedded())

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
	apply_pending = false
	if not is_instance_valid(_window): return
	_window.content_scale_size = Vector2i(1280, 800)
	_window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	_window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	if not native_enabled: return
	# The editor owns an embedded game's native size. Do not pretend a request
	# succeeded or write a preference that the editor has silently ignored.
	if is_host_embedded():
		apply_error_key = "DISPLAY_EMBEDDED"
		return
	_native_target = value.duplicate()
	_native_deadline_msec = Time.get_ticks_msec() + int(clampf(definition.apply_timeout_seconds, 0.5, 5.0) * 1000.0)
	_native_retry_msec = Time.get_ticks_msec() + int(clampf(definition.window_settle_seconds, 0.05, 0.5) * 1000.0)
	_native_retried = false
	apply_pending = true
	apply_native_request(value)
	trace_native("request", value)

func apply_native_request(value: Dictionary) -> void:
	# Guard the mutation boundary too, including a delayed retry.
	if not native_enabled or not is_instance_valid(_window) or is_host_embedded(): return
	# Capture the monitor before resizing. Release old fixed bounds before changing
	# mode, then retry once after native fullscreen/maximized restoration settles.
	var target_area := usable_rect()
	_window.min_size = Vector2i(64, 64)
	_window.max_size = Vector2i.ZERO
	_window.mode = value.mode
	if value.mode == WINDOWED:
		_window.borderless = false
		_window.size = value.size
		_window.min_size = value.size
		_window.max_size = value.size
		_window.position = target_area.position + (target_area.size - value.size) / 2
	_window.unresizable = true

func native_matches(value: Dictionary) -> bool:
	if not native_enabled: return true
	if not is_instance_valid(_window) or is_host_embedded(): return false
	var window_id := _window.get_window_id()
	if DisplayServer.window_get_mode(window_id) != value.mode: return false
	var expected: Vector2i = value.size if value.mode == WINDOWED else DisplayServer.screen_get_size(_window.current_screen)
	return DisplayServer.window_get_size(window_id) == expected

func verify_native_application(now_msec: int = Time.get_ticks_msec()) -> void:
	if not apply_pending: return
	if is_host_embedded():
		apply_pending = false
		previewing = false
		active = confirmed.duplicate()
		apply_error_key = "DISPLAY_EMBEDDED"
		changed.emit()
		return
	# Let queued OS resize notifications arrive before accepting the result.
	if now_msec < _native_retry_msec: return
	if native_matches(_native_target):
		apply_pending = false
		trace_native("accepted", _native_target)
		changed.emit()
		return
	if not _native_retried:
		_native_retried = true
		apply_native_request(_native_target)
		return
	if now_msec >= _native_deadline_msec:
		trace_native("failed", _native_target)
		apply_pending = false
		apply_error_key = "DISPLAY_APPLY_FAILED"
		if previewing: cancel_preview()
		changed.emit()

func trace_native(event: String, requested: Dictionary) -> void:
	# Debug output only: diagnose a player's native backend without UI clutter,
	# user paths, command-line arguments, or misleading headless success claims.
	if not OS.is_debug_build() or not native_enabled or DisplayServer.get_name() == "headless" or not is_instance_valid(_window): return
	var id := _window.get_window_id()
	print("DISPLAY ", event, " | ", OS.get_name(), " / ", DisplayServer.get_name(),
		" / Godot ", Engine.get_version_info().string,
		" | requested mode=", requested.mode, " size=", requested.size,
		" | actual mode=", DisplayServer.window_get_mode(id), " size=", DisplayServer.window_get_size(id),
		" | bounds=", _window.min_size, "..", _window.max_size,
		" | fixed=", _window.unresizable, " embedded=", is_host_embedded())

func begin_preview(mode: int, size: Vector2i) -> void:
	if previewing: cancel_preview()
	apply_error_key = ""
	if native_enabled and is_host_embedded():
		apply_error_key = "DISPLAY_EMBEDDED"
		changed.emit()
		return
	active = sanitize({"mode": mode, "size": size})
	if active == confirmed and native_matches(active): return
	previewing = true
	deadline_msec = Time.get_ticks_msec() + int(clampf(definition.confirmation_seconds, 5.0, 30.0) * 1000)
	apply_native(active)
	changed.emit()

func seconds_remaining(now_msec: int = Time.get_ticks_msec()) -> int:
	return maxi(0, ceili(float(deadline_msec - now_msec) / 1000.0)) if previewing else 0

func confirm_preview() -> void:
	if not previewing: return
	if apply_pending: return
	if not native_matches(active):
		apply_error_key = "DISPLAY_APPLY_FAILED"
		cancel_preview()
		return
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
	verify_native_application()
	if previewing and Time.get_ticks_msec() >= deadline_msec: cancel_preview()

func _exit_tree() -> void:
	cancel_preview()
	apply_pending = false
