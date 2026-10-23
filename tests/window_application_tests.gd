extends SceneTree
## Covers denied/late OS resize application without requiring a Windows host.
class NativeProbe extends WindowSettingsController:
	var accepts := false
	var requests := 0
	var native_value: Dictionary = {}
	var embedded := false
	func is_host_embedded() -> bool: return embedded
	func usable_rect() -> Rect2i: return Rect2i(0, 0, 1920, 1080)
	func apply_native_request(value: Dictionary) -> void:
		requests += 1
		if accepts: native_value = value.duplicate()
	func native_matches(value: Dictionary) -> bool:
		return not native_enabled or native_value == value
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	check(WindowSettingsController.has_parent_window(["--wid", "123"]), "editor embedded native parent detected")
	check(WindowSettingsController.has_parent_window(["--wid=123"]), "equals parent syntax detected")
	check(not WindowSettingsController.has_parent_window(["--wid", "0"]), "zero native parent is not embedded")
	check(not WindowSettingsController.has_parent_window(["--path", "game"]), "standalone not falsely blocked")
	var probe := NativeProbe.new()
	probe.native_enabled = false
	probe.settings_path = "user://native-application-probe.cfg"
	DirAccess.remove_absolute(probe.settings_path)
	root.add_child(probe)
	probe.native_enabled = true
	var previous := probe.confirmed.duplicate()
	probe.native_value = previous.duplicate()
	probe.begin_preview(WindowSettingsController.WINDOWED, Vector2i(960,600))
	check(probe.previewing and probe.apply_pending, "request waits for native acknowledgement")
	probe.confirm_preview()
	check(probe.confirmed == previous, "Keep cannot persist unacknowledged window change")
	check(not FileAccess.file_exists(probe.settings_path), "failed native request never writes settings")
	probe.accepts = true
	probe.verify_native_application(probe._native_retry_msec)
	check(probe.requests == 2, "one deferred retry after window restoration")
	probe.verify_native_application(probe._native_retry_msec + 1)
	check(not probe.apply_pending, "actual pixels acknowledged")
	probe.confirm_preview()
	check(probe.confirmed.size == Vector2i(960,600), "confirmed actual size saved")
	var accepted := probe.confirmed.duplicate()
	probe.accepts = false
	probe.begin_preview(WindowSettingsController.WINDOWED, Vector2i(1280,800))
	probe.verify_native_application(probe._native_retry_msec)
	probe.verify_native_application(probe._native_deadline_msec + 1)
	check(not probe.previewing and probe.confirmed == accepted and probe.active == accepted, "unapplied change rolls back")
	check(probe.apply_error_key == "DISPLAY_APPLY_FAILED", "failure visible instead of silent success")
	var config := ConfigFile.new()
	config.load(probe.settings_path)
	check(config.get_value("window", "size") == accepted.size, "failed change never overwrites persisted size")
	probe.apply_pending = false
	probe.embedded = true
	var requests := probe.requests
	probe.begin_preview(WindowSettingsController.EXCLUSIVE, Vector2i(1280,800))
	check(not probe.previewing and probe.requests == requests, "embedded request never changes native window")
	check(probe.apply_error_key == "DISPLAY_EMBEDDED", "embedded guidance is explicit")
	check(probe.confirmed == accepted, "embedded editor never corrupts standalone preference")
	probe.embedded = false
	probe.native_value = {"mode": WindowSettingsController.WINDOWED, "size": Vector2i(500,300)}
	probe.accepts = true
	probe.begin_preview(accepted.mode, accepted.size)
	check(probe.previewing and probe.apply_pending, "same saved selection can repair different actual window")
	probe.verify_native_application(probe._native_retry_msec)
	probe.confirm_preview()
	check(probe.native_value == accepted, "repair restores requested native pixels")
	probe.begin_preview(WindowSettingsController.WINDOWED, Vector2i(1280,800))
	probe.verify_native_application(probe._native_retry_msec)
	probe.native_value = {"mode": 0, "size": Vector2i(700,400)}
	probe.confirm_preview()
	check(not probe.previewing and probe.confirmed == accepted, "native drift after preview cannot be persisted")
	check(probe.apply_error_key == "DISPLAY_APPLY_FAILED", "late native rejection remains visible")
	probe.queue_free()
	await process_frame
	DirAccess.remove_absolute("user://native-application-probe.cfg")
	print("WINDOW APPLICATION: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
