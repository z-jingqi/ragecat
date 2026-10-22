extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	var audio := FeedbackAudio.new()
	root.add_child(audio)
	check(audio.play_event("launch"), "fixture starts genuine playback")
	var handles: Array[WeakRef] = []
	preload("res://tests/audio_teardown.gd")._capture(root, handles)
	check(not handles.is_empty(), "fixture observes actual playback handles")
	# Reproduce the stale initial-frame delta which defeated SceneTreeTimer.
	OS.delay_msec(550)
	paused = true
	var start := Time.get_ticks_usec()
	await preload("res://tests/audio_teardown.gd").drain(self)
	var elapsed := Time.get_ticks_usec() - start
	check(elapsed >= 500000, "drain guarantees at least 500ms monotonic wall time after a blocked frame")
	check(not paused, "paused fixture is resumed only for teardown")
	check(preload("res://tests/audio_teardown.gd")._remaining(handles).is_empty(), "stopped mixer playback references are actually released")
	check(not audio.is_enabled() and audio.active_voice_count() == 0, "teardown cannot emit new audio")
	audio.free()
	print("AUDIO TEARDOWN: %d checks, %d failures; wall %.3fms" % [checks, failures, elapsed / 1000.0])
	quit(0 if failures == 0 else 1)
