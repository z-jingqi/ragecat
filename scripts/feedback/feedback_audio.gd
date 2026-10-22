class_name FeedbackAudio
extends Node
## Bounded, non-positional arcade feedback. One call emits at most one one-shot.
## Cooldowns and voice leases advance in scaled game time, never wall-clock time.
## Pause/exit/disable explicitly stop voices, so nothing resumes or queues later.

const DEFAULT_DEFINITION := preload("res://resources/audio/feedback_audio_default.tres")

@export var definition: FeedbackAudioDefinition
var configuration_issues: PackedStringArray = []
var diagnostics: Dictionary = {
	"played_total": 0, "rejected_disabled": 0, "rejected_unknown": 0,
	"rejected_cooldown": 0, "rejected_capacity": 0, "rejected_invalid": 0,
	"rejected_paused": 0, "peak_active": 0, "voices_created": 0,
	"stop_calls": 0, "last_kind": "", "last_pitch": 1.0,
	"last_voice_volume_db": -80.0,
}
var _settings: Dictionary = {}
var _enabled: bool = true
var _players: Array[AudioStreamPlayer] = []
var _remaining: Array[float] = []
var _cooldowns: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	# Own the pause mode rather than inheriting an always-processing UI parent.
	process_mode = Node.PROCESS_MODE_PAUSABLE
	configure(definition)


func configure(value: FeedbackAudioDefinition = null) -> void:
	stop_all()
	definition = value if value != null else DEFAULT_DEFINITION
	_settings = definition.validated_settings()
	configuration_issues = _settings["issues"].duplicate()
	_enabled = bool(_settings["enabled"])
	_rng.seed = int(_settings["random_seed"])
	for player: AudioStreamPlayer in _players:
		player.free()
	_players.clear()
	_remaining.clear()
	for index: int in range(int(_settings["max_voices"])):
		var player := AudioStreamPlayer.new()
		player.name = "FeedbackVoice%d" % index
		player.max_polyphony = 1
		player.bus = &"Master"
		player.process_mode = Node.PROCESS_MODE_PAUSABLE
		player.finished.connect(_on_voice_finished.bind(index))
		add_child(player)
		_players.append(player)
		_remaining.append(0.0)
	diagnostics["voices_created"] = _players.size()


func play_event(kind: String) -> bool:
	if not _enabled:
		return _reject("rejected_disabled")
	if not is_inside_tree() or get_tree().paused or not can_process():
		return _reject("rejected_paused")
	if _has_disabled_ancestor():
		_clear_if_active()
		return _reject("rejected_disabled")
	if kind not in FeedbackAudioDefinition.EVENT_KINDS:
		return _reject("rejected_unknown")
	if _settings.is_empty() or not _settings["event_streams"].has(kind):
		return _reject("rejected_invalid")
	if float(_cooldowns.get(kind, 0.0)) > 0.0:
		return _reject("rejected_cooldown")
	var slot: int = -1
	for index: int in range(_remaining.size()):
		if _remaining[index] <= 0.0:
			slot = index
			break
	if slot < 0:
		return _reject("rejected_capacity")
	var stream := _settings["event_streams"][kind] as AudioStreamWAV
	# Do not allow externally edited shared resources to acquire looping playback.
	if not FeedbackAudioDefinition._valid_stream(stream):
		return _reject("rejected_invalid")
	var player: AudioStreamPlayer = _players[slot]
	var variance: float = float(_settings["pitch_variance"])
	var pitch: float = _rng.randf_range(1.0 - variance, 1.0 + variance)
	# Even aligned full-scale streams sum below -3 dB at the source, before
	# independently configured bus/device gain. Event gains never amplify.
	var volume: float = float(_settings["master_volume_db"]) - linear_to_db(float(_players.size())) + float(_settings["event_gains_db"][kind])
	player.stream = stream
	player.volume_db = volume
	player.pitch_scale = pitch
	_remaining[slot] = stream.get_length() / pitch
	_cooldowns[kind] = float(_settings["event_cooldowns"][kind])
	player.play()
	diagnostics["played_total"] = int(diagnostics["played_total"]) + 1
	diagnostics["peak_active"] = maxi(int(diagnostics["peak_active"]), active_voice_count())
	diagnostics["last_kind"] = kind
	diagnostics["last_pitch"] = pitch
	diagnostics["last_voice_volume_db"] = volume
	return true


func _process(delta: float) -> void:
	# Explicit PAUSABLE protects against ALWAYS-processing UI parents, but
	# must not override a disabled gameplay scene farther up the hierarchy.
	if _has_disabled_ancestor():
		_clear_if_active()
		return
	if not is_finite(delta) or delta <= 0.0:
		return
	for kind: String in _cooldowns.keys():
		_cooldowns[kind] = maxf(0.0, float(_cooldowns[kind]) - delta)
	for index: int in range(_remaining.size()):
		if _remaining[index] <= 0.0:
			continue
		_remaining[index] = maxf(0.0, _remaining[index] - delta)
		if _remaining[index] == 0.0:
			_players[index].stop()
			_players[index].stream = null


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_DISABLED or what == NOTIFICATION_EXIT_TREE:
		stop_all()


func set_enabled(value: bool) -> void:
	_enabled = value
	if not value:
		stop_all()


func is_enabled() -> bool:
	return _enabled


func stop_all() -> void:
	for player: AudioStreamPlayer in _players:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	for index: int in range(_remaining.size()):
		_remaining[index] = 0.0
	_cooldowns.clear()
	diagnostics["stop_calls"] = int(diagnostics["stop_calls"]) + 1


func active_voice_count() -> int:
	var count: int = 0
	for seconds: float in _remaining:
		if seconds > 0.0:
			count += 1
	return count


func get_diagnostics() -> Dictionary:
	var result := diagnostics.duplicate(true)
	result["active_voices"] = active_voice_count()
	result["pool_size"] = _players.size()
	result["enabled"] = _enabled
	result["cooldowns"] = _cooldowns.duplicate()
	return result


func _on_voice_finished(index: int) -> void:
	if index >= 0 and index < _remaining.size():
		_remaining[index] = 0.0
		_players[index].stream = null


func _has_disabled_ancestor() -> bool:
	var ancestor: Node = get_parent()
	while ancestor != null:
		if ancestor.process_mode == Node.PROCESS_MODE_DISABLED:
			return true
		ancestor = ancestor.get_parent()
	return false


func _clear_if_active() -> void:
	if active_voice_count() > 0 or not _cooldowns.is_empty():
		stop_all()


func _reject(counter: String) -> bool:
	diagnostics[counter] = int(diagnostics[counter]) + 1
	return false
