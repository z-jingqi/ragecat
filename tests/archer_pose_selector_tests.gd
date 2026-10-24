extends SceneTree
const Selector = preload("res://scripts/characters/archer/presentation/pose_clip_selector.gd")
const ShotClock = preload("res://scripts/characters/archer/presentation/archer_pose_clock.gd")
const PostureClock = preload("res://scripts/characters/archer/presentation/bow_posture_clock.gd")
const CLIPS := ["carry", "raise", "lower", "lower_loaded", "controlled_undraw", "normal_release", "normal_renock", "normal_draw", "short_release", "short_recover", "short_draw", "hold_relaxed", "hold_relaxed_loaded", "short_undraw"]
var checks := 0
var failures := 0
var samples: Array[Dictionary] = []

func _initialize() -> void: call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("CLIP SELECTOR: " + label)

func near(actual: float, expected: float, label: String) -> void:
	check(absf(actual - expected) < 0.000001, label)

func record(value: Dictionary) -> Dictionary:
	samples.append(value.duplicate())
	return value

func step(s: RefCounted, dt: float, shot_pose := "rest", shot_phase := 0.0,
		posture_state := "carry", height := 0.0, tension := 0.0, short := false, fired := false) -> Dictionary:
	return record(s.advance(dt, shot_pose, shot_phase, posture_state, height, tension, short, fired))

func draw(s: RefCounted, short: bool, phase: float) -> Dictionary:
	step(s, 0.0, "release", 0.0, "fast_release", 1.0, 1.0, short, true)
	step(s, 0.01, "recover", 1.0, "recover", 1.0, 0.0, short)
	step(s, 0.01, "draw", phase, "draw", 1.0, phase, short)
	return step(s, 0.10, "draw", phase, "draw", 1.0, phase, short)

func lower_loaded(s: RefCounted) -> Dictionary:
	draw(s, false, 0.6)
	step(s, 0.01, "rest", 0.0, "relax", 1.0, 0.4)
	step(s, 0.2, "rest", 0.0, "lower", 0.5)
	return step(s, 0.01, "rest", 0.0, "lower", 0.4)

func run() -> void:
	var s = Selector.new()
	check(s.current_sample() == {"clip": &"east/carry", "phase": 0.0, "loaded": false}, "Reset defaults to empty carry")
	var out := step(s, 0.01, "release", 0.0, "carry")
	check(out.clip == &"east/carry" and not out.loaded, "A pose string without actual fired cannot synthesize release")
	out = step(s, 0.0, "rest", 0.9, "carry", 0.0, 0.0, false, true)
	check(out.clip == &"east/normal_release" and out.phase == 0.0 and not out.loaded, "Real cold shot wins immediately even with zero delta/stale clocks")
	out = step(s, 0.01, "release", 0.6, "release", 1.0, 0.4)
	check(out.clip == &"east/normal_release" and not out.loaded, "Release remains empty")
	near(out.phase, 0.6, "Release follows shot-clock phase")
	out = step(s, 0.01, "recover", 0.5, "recover", 1.0)
	check(out.clip == &"east/normal_renock" and not out.loaded, "Mid recovery has no held arrow")
	out = step(s, 0.01, "recover", 1.0, "recover", 1.0)
	check(out.loaded, "Terminal renock establishes held arrow")
	out = step(s, 0.01, "ready", 0.0, "hold_relaxed", 1.0)
	check(out.clip == &"east/hold_relaxed_loaded" and out.loaded, "Normal recovery reaches loaded relaxed hold, not another raise")
	out = step(s, 0.01, "draw", 0.9, "draw", 1.0, 0.35)
	check(out.clip == &"east/normal_draw" and out.phase == 0.0 and out.loaded, "New draw begins at brace endpoint")
	out = step(s, 0.10, "draw", 0.9, "draw", 1.0, 0.35)
	near(out.phase, 0.35, "Rendered phase follows filtered presentation, not raw shot phase")
	out = step(s, 0.01, "rest", 0.0, "relax", 1.0, 0.15)
	check(out.clip == &"east/controlled_undraw" and out.loaded, "Normal cancellation uses loaded controlled undraw")
	near(out.phase, 0.65, "Cancel begins at inverse ACTUAL displayed phase without full-draw jump")
	var frozen := out.duplicate()
	out = step(s, 0.0, "draw", 1.0, "draw", 1.0, 1.0)
	check(out == frozen, "Zero delta freezes cancellation despite changed posture inputs")
	out = step(s, 0.02, "rest", 0.0, "relax", 1.0)
	near(out.phase, 0.85, "Normal cancellation advances along reverse geometry")
	out = step(s, 0.02, "rest", 0.0, "lower", 0.5)
	near(out.phase, 1.0, "Normal cancellation completes at brace")
	out = step(s, 0.01, "rest", 0.0, "lower", 0.4)
	check(out.clip == &"east/lower_loaded" and out.phase == 0.0 and out.loaded, "Lower starts at actual brace and latches loaded despite posture being ahead")
	out = step(s, s.lower_duration * 0.5, "rest", 0.0, "lower", 0.1)
	near(out.phase, 0.5, "Lower uses configured duration")
	check(out.loaded, "Arrow retained before unload point")
	out = step(s, s.raise_duration * 0.2, "ready", 0.0, "raise", 0.7)
	check(out.clip == &"east/lower_loaded" and out.loaded, "Pre-unload reacquisition reverses the SAME loaded clip")
	near(out.phase, 0.3, "Reversed loaded lower preserves its actual phase")
	out = step(s, s.raise_duration, "ready", 0.0, "raise", 1.0)
	check(out.phase == 0.0 and out.loaded, "Pre-unload reverse arrives at loaded brace")
	out = step(s, 0.01, "ready", 0.0, "raise", 0.45)
	check(out.clip == &"east/hold_relaxed_loaded" and out.loaded, "Lagging posture height cannot replay empty raise after loaded reversal reached brace")
	out = step(s, 0.01, "ready", 0.0, "hold_relaxed", 1.0)
	check(out.clip == &"east/hold_relaxed_loaded", "Loaded reverse holds loaded rather than replaying renock")

	s.reset()
	out = lower_loaded(s)
	check(out.clip == &"east/lower_loaded", "Loaded lowering helper reaches proper transition")
	out = step(s, s.lower_duration * s.unload_phase, "rest", 0.0, "lower", 0.1)
	check(not out.loaded and out.clip == &"east/lower_loaded", "Unloading at exact threshold keeps latched forward clip, without firing")
	near(out.phase, s.unload_phase, "Unload threshold is normalized clip phase")
	out = step(s, s.raise_duration * 0.2, "ready", 0.0, "raise", 0.3)
	check(out.clip == &"east/lower" and not out.loaded, "Post-unload reversal must use empty geometry/arrow variant")
	out = step(s, s.lower_duration * 0.05, "rest", 0.0, "lower", 0.2)
	check(out.clip == &"east/lower" and not out.loaded, "A SECOND target loss below unload threshold cannot resurrect baked arrow")
	out = step(s, s.raise_duration, "draw", 0.8, "draw", 1.0, 0.8)
	check(out.clip == &"east/lower" and out.phase == 0.0 and not out.loaded, "Returning to brace itself stays empty after unload")
	out = step(s, 0.01, "ready", 0.0, "raise", 0.5)
	check(out.clip == &"east/hold_relaxed" and not out.loaded, "Lagging empty raise cannot move already returned brace backward")
	out = step(s, 0.01, "draw", 0.8, "draw", 1.0, 0.8)
	check(out.clip == &"east/normal_draw" and out.phase == 0.0 and out.loaded, "Only a subsequent genuine draw entry nocks a new cosmetic arrow")

	s.reset()
	out = draw(s, true, 0.6)
	check(out.clip == &"east/short_draw" and out.loaded, "Short recover enters short draw at matching Gfull anchor")
	out = step(s, 0.01, "rest", 0.0, "relax", 1.0, 0.2, true)
	check(out.clip == &"east/short_draw" and out.loaded, "Short cancel first reverses its own clip")
	near(out.phase, 0.6, "Short cancel captures actual current phase")
	out = step(s, s.short_reverse_duration * 0.3, "rest", 0.0, "relax", 1.0, 0.0, true)
	near(out.phase, 0.3, "Short cancel travels backward instead of normal full draw")
	out = step(s, s.short_reverse_duration * 0.3 + 0.000001, "rest", 0.0, "lower", 0.6, 0.0, true)
	check(out.clip == &"east/short_undraw" and out.phase == 0.0 and out.loaded, "Short reversal reaches auxiliary bridge at exact matching start")
	out = step(s, s.short_undraw_duration * 0.5, "rest", 0.0, "lower", 0.3, 0.0, true)
	check(out.clip == &"east/short_undraw" and out.loaded, "Auxiliary short undraw preserves held arrow")
	near(out.phase, 0.5, "Auxiliary bridge uses configured timing")
	out = step(s, s.short_undraw_duration * 0.5, "rest", 0.0, "lower", 0.0, 0.0, true)
	near(out.phase, 1.0, "Auxiliary short bridge reaches Gclose")
	out = step(s, 0.01, "rest", 0.0, "carry", 0.0, 0.0, true)
	check(out.clip == &"east/lower_loaded" and out.phase == 0.0, "Completed short bridge lowers from Gclose without jumping")
	out = step(s, 0.0, "release", 0.8, "fast_release", 1.0, 1.0, true, true)
	check(out.clip == &"east/short_release" and out.phase == 0.0 and not out.loaded, "Actual shot immediately interrupts loaded lower")
	out = step(s, 0.0, "release", 0.0, "release", 1.0, 1.0, false, true)
	check(out.clip == &"east/normal_release" and out.phase == 0.0 and not out.loaded, "Another real signal resets immediately and adopts real cycle mode")

	s.reset()
	step(s, 0.0, "release", 0.0, "release", 1.0, 1.0, true, true)
	step(s, 0.01, "recover", 1.0, "recover", 1.0, 0.0, true)
	out = step(s, 0.01, "rest", 0.0, "hold_relaxed", 1.0, 0.0, true)
	check(out.clip == &"east/short_undraw" and out.phase == 0.0 and out.loaded, "No-target short recovery cannot jump from Gfull directly into Gclose hold")
	out = step(s, 0.0, "release", 0.0, "release", 1.0, 1.0, false, true)
	check(out.clip == &"east/normal_release" and not out.loaded, "Real release also interrupts auxiliary undraw")
	s.reset()
	step(s, 0.01, "ready", 0.0, "raise", 0.4)
	out = step(s, 0.01, "rest", 0.0, "lower", 0.3)
	check(out.clip == &"east/lower" and not out.loaded, "Cancelled empty raise lowers without creating an arrow")
	near(out.phase, 0.6, "Empty raise cancellation reverses its exact pose")
	out = step(s, 0.3, "rest", 0.0, "carry")
	check(out.clip == &"east/carry" and not out.loaded, "Empty lowering completes in carry")
	s.reset()
	s.unload_phase = 0.5
	lower_loaded(s)
	out = step(s, s.lower_duration * 0.5, "rest", 0.0, "lower")
	check(not out.loaded, "Unload threshold is configurable")
	s.reset()
	check(s.current_sample() == {"clip": &"east/carry", "phase": 0.0, "loaded": false}, "Reset clears auxiliary, lower latch, and loaded state")

	# Exercise real visual-clock objects and prove selector does not mutate them.
	var clock = ShotClock.new()
	var posture = PostureClock.new()
	clock.reset(Vector2.ZERO)
	clock.notify_release()
	clock.tick(0.0, Vector2.ZERO, Vector2.RIGHT, false, 1.0, 0.12, 0.12, true, true)
	posture.tick(0.0, true, true, true, 0.12, clock.pose, clock.pose_phase)
	var before: Array = [clock.pose, clock.pose_phase, clock.gait_phase, clock.release_age, posture.state, posture.height, posture.tension, posture.short_cycle]
	out = record(s.tick(0.0, clock, posture, true))
	var after: Array = [clock.pose, clock.pose_phase, clock.gait_phase, clock.release_age, posture.state, posture.height, posture.tension, posture.short_cycle]
	check(before == after, "Selector only reads existing clocks")
	check(out.clip == &"east/short_release" and not out.loaded, "Clock-object API consumes explicit actual fired flag")
	var frozen_sample := s.current_sample()
	s.tick(0.0, clock, posture, false)
	check(s.current_sample() == frozen_sample, "Paused clock-object call leaves selector unchanged")

	# Four real visual-clock pulses at 0.12 s, then target loss. This is a pure
	# clock pipeline, not a combat run or an assertion of rendered smoothness.
	s.reset()
	clock.reset(Vector2.ZERO)
	posture.reset()
	var all_immediate := true
	var no_synthetic_release := true
	var all_read_only := true
	var previous_clip: StringName = &"east/carry"
	var real_pulses := 0
	for i in range(151):
		var fired := i in [0, 12, 24, 36]
		var target := i <= 36
		var next_shot := 0.12 - float(i % 12) * 0.01
		if fired:
			clock.notify_release()
			real_pulses += 1
		clock.tick(0.01, Vector2(float(i), 0), Vector2.RIGHT, false, 2.0, next_shot, 0.12, target, true)
		posture.tick(0.01, target, true, fired, 0.12, clock.pose, clock.pose_phase)
		before = [clock.pose, clock.pose_phase, clock.gait_phase, clock.release_age, posture.state, posture.height, posture.tension, posture.short_cycle]
		out = s.tick(0.01, clock, posture, fired)
		after = [clock.pose, clock.pose_phase, clock.gait_phase, clock.release_age, posture.state, posture.height, posture.tension, posture.short_cycle]
		all_read_only = all_read_only and before == after
		if fired: all_immediate = all_immediate and out.clip == &"east/short_release" and out.phase == 0.0 and not out.loaded
		if str(out.clip).ends_with("_release") and out.clip != previous_clip:
			no_synthetic_release = no_synthetic_release and fired
		previous_clip = out.clip
	check(real_pulses == 4 and all_immediate, "Real 0.12-second clock pipeline presents all four actual release pulses immediately")
	check(no_synthetic_release, "Target loss and cancellation never synthesize release in actual clock pipeline")
	check(all_read_only, "Selector never changes shot/posture/gait values across full pipeline")
	check(out.clip == &"east/carry" and not out.loaded, "Four-shot burst followed by target loss completes cancel, unload and carry")

	for value in samples:
		check(CLIPS.has(str(value.clip).trim_prefix("east/")), "Output clip exists in approved runtime contract: " + str(value.clip))
		check(is_finite(value.phase) and value.phase >= 0.0 and value.phase <= 1.0, "Output phase stays within atlas bounds")
	print("POSE CLIP SELECTOR: %d checks, %d failures; %d sampled transitions" % [checks, failures, samples.size()])
	quit(1 if failures else 0)
