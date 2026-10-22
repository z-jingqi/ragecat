class_name FeedbackAudioDefinition
extends Resource
## Editable one-shot feedback configuration. Runtime snapshots never mutate this resource.
## Gains are attenuation only. Pool-size compensation preserves aggregate headroom.

const EVENT_KINDS := ["launch", "hit", "critical", "kill", "fire", "lightning", "freeze", "shatter", "shock", "dark"]
const HARD_VOICE_CAP := 8
const HARD_MASTER_CAP_DB := -3.0
const MIN_MASTER_DB := -48.0
const MAX_PITCH_VARIANCE := 0.07
const MAX_STREAM_SECONDS := 0.75
const DEFAULT_COOLDOWNS := {
	"launch": 0.045, "hit": 0.045, "critical": 0.055, "kill": 0.075,
	"fire": 0.09, "lightning": 0.10, "freeze": 0.10, "shatter": 0.11,
	"shock": 0.12, "dark": 0.45,
}
const DEFAULT_GAINS_DB := {
	"launch": -3.0, "hit": 0.0, "critical": 0.0, "kill": -1.0,
	"fire": -4.0, "lightning": -3.0, "freeze": -2.0, "shatter": -1.0,
	"shock": -2.0, "dark": -6.0,
}

@export var enabled: bool = true
@export_range(1, 8, 1) var max_voices: int = 6
@export_range(-48.0, -3.0, 0.5) var master_volume_db: float = -3.0
@export_range(0.0, 0.07, 0.005) var pitch_variance: float = 0.025
@export var random_seed: int = 1380009797
@export var event_streams: Dictionary = {
	"launch": preload("res://resources/audio/launch.wav"),
	"hit": preload("res://resources/audio/hit.wav"),
	"critical": preload("res://resources/audio/critical.wav"),
	"kill": preload("res://resources/audio/kill.wav"),
	"fire": preload("res://resources/audio/fire.wav"),
	"lightning": preload("res://resources/audio/lightning.wav"),
	"freeze": preload("res://resources/audio/freeze.wav"),
	"shatter": preload("res://resources/audio/shatter.wav"),
	"shock": preload("res://resources/audio/shock.wav"),
	"dark": preload("res://resources/audio/dark.wav"),
}
@export var event_gains_db: Dictionary = DEFAULT_GAINS_DB.duplicate()
@export var event_cooldowns: Dictionary = DEFAULT_COOLDOWNS.duplicate()


func validated_settings() -> Dictionary:
	var streams: Dictionary = {}
	var gains: Dictionary = {}
	var cooldowns: Dictionary = {}
	var issues: PackedStringArray = []
	for kind: String in EVENT_KINDS:
		var candidate: Variant = event_streams.get(kind)
		if _valid_stream(candidate):
			streams[kind] = candidate
		else:
			issues.append("Missing or invalid short mono PCM16 non-looping stream: " + kind)
		gains[kind] = clampf(_finite_number(event_gains_db.get(kind), DEFAULT_GAINS_DB[kind]), -48.0, 0.0)
		cooldowns[kind] = clampf(_finite_number(event_cooldowns.get(kind), DEFAULT_COOLDOWNS[kind]), 0.0, 2.0)
	var voices: int = clampi(max_voices, 1, HARD_VOICE_CAP)
	var master: float = clampf(_finite_number(master_volume_db, -3.0), MIN_MASTER_DB, HARD_MASTER_CAP_DB)
	var variance: float = clampf(_finite_number(pitch_variance, 0.025), 0.0, MAX_PITCH_VARIANCE)
	if voices != max_voices or master != master_volume_db or variance != pitch_variance:
		issues.append("Out-of-range pool, master volume, or pitch variance was safely clamped.")
	return {
		"enabled": enabled, "max_voices": voices, "master_volume_db": master,
		"pitch_variance": variance, "random_seed": random_seed,
		"event_streams": streams, "event_gains_db": gains,
		"event_cooldowns": cooldowns, "issues": issues,
	}


static func _finite_number(value: Variant, fallback: float) -> float:
	if (value is float or value is int) and is_finite(float(value)):
		return float(value)
	return fallback


static func _valid_stream(value: Variant) -> bool:
	if not value is AudioStreamWAV:
		return false
	var stream := value as AudioStreamWAV
	return (
		stream.loop_mode == AudioStreamWAV.LOOP_DISABLED
		and stream.format == AudioStreamWAV.FORMAT_16_BITS
		and not stream.stereo
		and stream.mix_rate >= 8000 and stream.mix_rate <= 96000
		and is_finite(stream.get_length())
		and stream.get_length() >= 0.025 and stream.get_length() <= MAX_STREAM_SECONDS
	)
