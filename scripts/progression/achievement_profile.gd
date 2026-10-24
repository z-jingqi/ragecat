class_name AchievementProfile
extends RefCounted
## Only normal-run event deltas enter this profile. No imported historical guesses.
signal unlocked(achievement_id: String)
signal save_failed(error: Error)
const VERSION := 1
var definition: ProgressionDefinition = preload("res://resources/progression/default.tres").validated_copy():
	set(value):
		definition = (value if value != null else preload("res://resources/progression/default.tres")).validated_copy()
var persistence_enabled := true
var save_path := "user://achievements.json"
var metrics: Dictionary = {"kills": 0, "survival": 0, "bosses": 0}
var completed: Array[String] = []
var dirty := false
var _active := false
var _save_elapsed := 0.0
var _read_only := false

func is_unlocked(upgrade: String) -> bool:
	if definition.starter_upgrades.has(upgrade): return true
	for item in definition.achievements:
		if completed.has(item.achievement_id) and item.rewards.has(upgrade): return true
	return false

func begin_run(practice: bool) -> void:
	flush()
	_active = not practice

func observe_time(seconds: float, delta: float) -> void:
	if not _active or not is_finite(seconds) or not is_finite(delta): return
	_set_metric("survival", maxi(int(metrics.survival), int(seconds)))
	_evaluate()
	_save_elapsed += maxf(0.0, delta)
	if _save_elapsed >= definition.save_interval: flush()

func record_kill(boss: bool) -> void:
	if not _active: return
	_set_metric("kills", int(metrics.kills) + 1)
	if boss: _set_metric("bosses", int(metrics.bosses) + 1)
	_evaluate()

func end_run() -> void:
	_active = false
	flush()

func _set_metric(metric: String, value: int) -> void:
	var bounded := clampi(value, 0, definition.metric_cap(metric))
	if bounded != int(metrics[metric]):
		metrics[metric] = bounded
		dirty = true

func _evaluate() -> void:
	var newly_completed: Array[String] = []
	for item in definition.achievements:
		if not completed.has(item.achievement_id) and int(metrics.get(item.metric, 0)) >= item.target:
			completed.append(item.achievement_id)
			newly_completed.append(item.achievement_id)
			dirty = true
	if not newly_completed.is_empty():
		flush()
		for key in newly_completed: unlocked.emit(key)

func achievement(key: String) -> AchievementDefinition:
	for item in definition.achievements:
		if item.achievement_id == key: return item
	return null

func load_profile() -> void:
	metrics = {"kills": 0, "survival": 0, "bosses": 0}
	completed.clear()
	dirty = false
	_active = false
	_read_only = false
	var primary := _read(save_path)
	# Never overwrite a newer-format profile with an older game's interpretation.
	if primary.get("future", false):
		_read_only = true
		return
	var data: Dictionary = primary
	if data.is_empty(): data = _read(save_path + ".bak")
	if data.is_empty() or data.get("future", false): return
	for metric: String in metrics: _set_metric(metric, int(data.metrics[metric]))
	# Retired achievements are ignored; valid counters and unrelated unlocks survive.
	for item in definition.achievements:
		if data.completed.has(item.achievement_id) and int(data.metrics[item.metric]) >= item.target: completed.append(item.achievement_id)
	# Reconcile counters after recovery without displaying old unlock notifications.
	for item in definition.achievements:
		if int(metrics[item.metric]) >= item.target and not completed.has(item.achievement_id): completed.append(item.achievement_id)
	dirty = false

func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK: return {}
	var data: Variant = parser.data
	if not data is Dictionary or not data.get("version") is float: return {}
	if float(data.version) != floorf(float(data.version)): return {}
	if int(data.version) > VERSION: return {"future": true}
	if int(data.version) != VERSION or not data.get("metrics") is Dictionary or not data.get("completed") is Array: return {}
	for metric: String in metrics:
		var value: Variant = data.metrics.get(metric)
		if not (value is float or value is int) or not is_finite(float(value)) or float(value) < 0.0: return {}
	for value in data.completed:
		if not value is String: return {}
	return data

func flush() -> Error:
	_save_elapsed = 0.0
	if not dirty or _read_only or not persistence_enabled: return OK
	var temporary := save_path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null: return _failed(FileAccess.get_open_error())
	file.store_string(JSON.stringify({"version": VERSION, "metrics": metrics, "completed": completed}))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK: return _failed(error)
	# Keep the prior valid generation; a corrupt primary must not replace its backup.
	var previous := _read(save_path)
	if not previous.is_empty() and not previous.get("future", false):
		error = DirAccess.copy_absolute(save_path, save_path + ".bak")
		if error != OK: return _failed(error)
	error = DirAccess.rename_absolute(temporary, save_path)
	if error != OK: return _failed(error)
	dirty = false
	return OK

func _failed(error: Error) -> Error:
	save_failed.emit(error)
	return error
