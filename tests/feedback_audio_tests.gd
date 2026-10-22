extends SceneTree
## Structural/dummy-driver tests, not a subjective listening evaluation.
var checks: int = 0
var failures: int = 0


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + message)


func _initialize() -> void:
	call_deferred("run")


func make_audio(config: FeedbackAudioDefinition = null) -> FeedbackAudio:
	var audio := FeedbackAudio.new()
	audio.definition = config
	root.add_child(audio)
	audio.set_process(false)
	return audio


func run() -> void:
	var config := FeedbackAudioDefinition.new()
	var settings: Dictionary = config.validated_settings()
	check(settings["issues"].is_empty(), "Default configuration passes validation")
	check(settings["event_streams"].size() == 10, "All ten event streams exist")
	for kind: String in FeedbackAudioDefinition.EVENT_KINDS:
		var stream: AudioStreamWAV = config.event_streams[kind]
		check(stream.format == AudioStreamWAV.FORMAT_16_BITS and not stream.stereo, kind + " remains mono PCM16 after Godot import")
		check(stream.loop_mode == AudioStreamWAV.LOOP_DISABLED, kind + " is non-looping")
		check(stream.get_length() >= 0.025 and stream.get_length() <= 0.55, kind + " is a bounded one-shot")
		var data: PackedByteArray = stream.data
		var peak: int = 0
		for offset: int in range(0, data.size(), 2):
			peak = maxi(peak, absi(data.decode_s16(offset)))
		check(peak > 0 and peak < 19661, kind + " PCM is nonempty and below 0.6 peak")
		check(data.decode_s16(0) == 0 and data.decode_s16(data.size() - 2) == 0, kind + " has silent endpoints")
	check(is_equal_approx((config.event_streams["dark"] as AudioStreamWAV).get_length(), 0.5), "Dark is exactly one 0.5 second envelope")

	var audio := make_audio()
	check(audio.get_diagnostics()["pool_size"] == 6, "Default fixed pool has six voices")
	check(audio.is_enabled() and audio.play_event("hit"), "Default audio is enabled and playable")
	check(not audio.play_event("hit"), "Repeated event obeys its own cooldown")
	check(audio.play_event("critical"), "A different event is not blocked by hit cooldown")
	check(audio.active_voice_count() == 2, "Each accepted event creates exactly one active voice")
	audio._process(0.02)
	check(not audio.play_event("hit"), "Cooldown does not expire before enough game time")
	audio._process(0.03)
	check(audio.play_event("hit"), "Cooldown expires after game-time advancement")
	check(not audio.play_event("not_an_event"), "Unknown event is safely rejected")
	audio._process(1.0)
	check(audio.active_voice_count() == 0, "Expired one-shots release their leases")
	check(not audio.get_child(0).playing, "Expired voice is actually stopped")

	var capped := FeedbackAudioDefinition.new()
	capped.max_voices = 3
	for kind: String in FeedbackAudioDefinition.EVENT_KINDS:
		capped.event_cooldowns[kind] = 0.0
	audio.configure(capped)
	for index: int in range(3):
		check(audio.play_event("dark"), "Pool accepts voice %d" % index)
	check(not audio.play_event("hit"), "Full pool drops an event instead of allocating or queueing")
	check(audio.active_voice_count() == 3 and audio.get_child_count() == 3, "Active and allocated voices obey configured cap")
	var full_count: int = int(audio.get_diagnostics()["played_total"])
	for index: int in range(2000):
		audio.play_event("hit")
	check(audio.active_voice_count() == 3 and audio.get_child_count() == 3, "Burst of 2000 events never expands fixed pool")
	check(int(audio.get_diagnostics()["played_total"]) == full_count, "Saturation produces no queued playback")
	audio._process(1.0)
	check(audio.active_voice_count() == 0, "Saturated burst fully expires")
	check(int(audio.get_diagnostics()["played_total"]) == full_count, "Expiration never replays dropped events")

	for voices: int in range(1, FeedbackAudioDefinition.HARD_VOICE_CAP + 1):
		var headroom := FeedbackAudioDefinition.new()
		headroom.max_voices = voices
		headroom.master_volume_db = 100.0
		headroom.event_gains_db["hit"] = 100.0
		headroom.event_cooldowns["hit"] = 0.0
		audio.configure(headroom)
		var summed_full_scale: float = 0.0
		for index: int in range(voices):
			check(audio.play_event("hit"), "Headroom case accepts its configured number of voices")
			var player := audio.get_child(index) as AudioStreamPlayer
			summed_full_scale += db_to_linear(player.volume_db)
			check(player.max_polyphony == 1, "Each pooled player is monophonic")
		check(summed_full_scale <= 0.708, "Full-scale coherent aggregate retains >=3dB headroom at pool size %d" % voices)

	var invalid := FeedbackAudioDefinition.new()
	invalid.max_voices = 999
	invalid.master_volume_db = INF
	invalid.pitch_variance = NAN
	invalid.event_gains_db["hit"] = "invalid"
	invalid.event_cooldowns["hit"] = -50.0
	invalid.event_streams["dark"] = null
	var looping: AudioStreamWAV = (invalid.event_streams["fire"] as AudioStreamWAV).duplicate()
	looping.loop_mode = AudioStreamWAV.LOOP_FORWARD
	invalid.event_streams["fire"] = looping
	audio.configure(invalid)
	check(audio.get_child_count() == 8, "Configuration clamps allocation to absolute hard cap")
	check(not audio.configuration_issues.is_empty(), "Invalid configuration exposes actionable diagnostics")
	check(not audio.play_event("dark") and not audio.play_event("fire"), "Missing and looping sounds are rejected")
	check(audio.play_event("hit"), "Invalid numeric values safely fall back without disabling valid events")
	check(is_finite(float(audio.get_diagnostics()["last_pitch"])), "Nonfinite pitch input cannot reach playback")
	check(float(audio.get_diagnostics()["last_pitch"]) >= 0.93 and float(audio.get_diagnostics()["last_pitch"]) <= 1.07, "Pitch variance is tightly bounded")
	check(is_finite(float(audio.get_diagnostics()["last_voice_volume_db"])), "Nonfinite gain input cannot reach playback")
	check(invalid.max_voices == 999 and is_inf(invalid.master_volume_db), "Validation does not mutate source configuration")

	audio.configure(config)
	check(audio.play_event("dark"), "Lifecycle test starts one dark voice")
	audio.set_enabled(false)
	check(audio.active_voice_count() == 0 and not audio.play_event("hit"), "Mute stops all voices and rejects new events")
	audio.set_enabled(true)
	check(audio.play_event("dark"), "Unmute accepts a fresh event without stale cooldown")
	paused = true
	check(audio.active_voice_count() == 0, "Pause synchronously clears every voice")
	check(not audio.play_event("hit"), "Paused tree rejects event playback")
	await process_frame
	paused = false
	await process_frame
	check(audio.active_voice_count() == 0, "Resume never replays old or paused sounds")
	check(audio.play_event("dark"), "Resume accepts a new dark event with clean cooldown")
	audio.stop_all()
	check(audio.active_voice_count() == 0 and audio.get_diagnostics()["cooldowns"].is_empty(), "stop_all clears voices and cooldowns")
	for child: Node in audio.get_children():
		check(not (child as AudioStreamPlayer).playing and (child as AudioStreamPlayer).stream == null, "stop_all releases playback and stream reference")
	check(audio.play_event("hit"), "Voice can play before removal")
	root.remove_child(audio)
	check(audio.active_voice_count() == 0, "Tree exit stops every voice immediately")
	check(not audio.play_event("hit"), "Detached audio does not play")
	root.add_child(audio)
	check(audio.active_voice_count() == 0 and audio.play_event("hit"), "Reattachment is silent until a new event")
	audio.process_mode = Node.PROCESS_MODE_DISABLED
	check(audio.active_voice_count() == 0 and not audio.play_event("hit"), "Disabled node cannot leave stale playback")
	audio.process_mode = Node.PROCESS_MODE_PAUSABLE
	audio.stop_all()

	# An explicit PAUSABLE child must still honor a disabled gameplay ancestor.
	var holder := Node.new()
	root.add_child(holder)
	var intermediate := Node.new()
	intermediate.process_mode = Node.PROCESS_MODE_ALWAYS
	holder.add_child(intermediate)
	var nested := FeedbackAudio.new()
	intermediate.add_child(nested)
	check(nested.play_event("dark"), "Enabled nested scene starts one-shot playback")
	paused = true
	check(nested.active_voice_count() == 0 and not nested.play_event("hit"), "ALWAYS-processing UI ancestor cannot defeat audio pause safety")
	await process_frame
	paused = false
	check(nested.active_voice_count() == 0, "ALWAYS-parent resume does not replay old sound")
	check(nested.play_event("dark"), "ALWAYS-parent resume accepts only fresh sound")
	holder.process_mode = Node.PROCESS_MODE_DISABLED
	await process_frame
	await process_frame
	check(nested.active_voice_count() == 0, "Disabling an ancestor stops live audio on the next frame")
	check(nested.get_diagnostics()["cooldowns"].is_empty(), "Disabled ancestor clears stale cooldowns")
	check(not nested.play_event("hit"), "Disabled ancestor rejects fresh playback despite explicit child pause mode")
	for child: Node in nested.get_children():
		check(not (child as AudioStreamPlayer).playing, "Disabled ancestor stops physical pooled voices")
	holder.process_mode = Node.PROCESS_MODE_INHERIT
	await process_frame
	check(nested.active_voice_count() == 0, "Re-enabled ancestor does not replay dropped or previous sounds")
	check(nested.play_event("dark"), "Re-enabled ancestor accepts fresh playback with no stale cooldown")
	holder.process_mode = Node.PROCESS_MODE_DISABLED
	check(not nested.play_event("hit") and nested.active_voice_count() == 0, "New event immediately clears playback under newly disabled ancestor")
	holder.queue_free()
	await process_frame

	# Audio must not change simulation RNG, including construction/configuration.
	seed(928734)
	var expected: Array[int] = []
	for index: int in range(20):
		expected.append(randi())
	seed(928734)
	var independent := make_audio()
	var initial_time_scale: float = Engine.time_scale
	for index: int in range(20):
		independent.stop_all()
		independent.play_event(FeedbackAudioDefinition.EVENT_KINDS[index % 10])
		check(randi() == expected[index], "Audio preserves global RNG value %d" % index)
	check(Engine.time_scale == initial_time_scale, "Audio never changes simulation time scale")
	var snapshot: Dictionary = independent.get_diagnostics()
	snapshot["played_total"] = -999
	check(int(independent.get_diagnostics()["played_total"]) >= 0, "Diagnostics accessor returns an independent snapshot")

	var off := FeedbackAudioDefinition.new()
	off.enabled = false
	independent.configure(off)
	check(not independent.is_enabled() and not independent.play_event("hit"), "Disabled resource starts silent")
	independent.queue_free()
	audio.queue_free()
	await process_frame
	# AudioServer releases stopped playback references on its next mix callback.
	# Let the dummy driver drain before process exit, rather than reporting those
	# asynchronous audio-thread references as leaked resources.
	await create_timer(0.12, true, false, true).timeout
	print("FEEDBACK AUDIO TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
