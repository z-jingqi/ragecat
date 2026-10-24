class_name ArcherPoseClipSelector
extends RefCounted
## Pure visual clip selection for the archer animation set.
## No actor, weapon, projectile, signal, RNG, or combat state is accessed here.
## Call after both clocks. `fired` is the adapter's actual launch flag, not a
## guessed edge of shot.pose. Reset this selector alongside both clocks.
## Cancellation completes before an ordinary retarget redraw; a real shot always
## interrupts immediately. A loaded lower can reverse until it unloads, after
## which only its empty counterpart may reverse through the unloading boundary.

var direction_prefix: StringName = &"east"
var normal_undraw_duration := 0.10
var short_reverse_duration := 0.055
var short_undraw_duration := 0.10
var lower_duration := 0.22
var raise_duration := 0.14
var normal_draw_follow_duration := 0.08
var short_draw_follow_duration := 0.04
var unload_phase := 0.818181818

var loaded := false
var _clip: StringName = &"carry"
var _phase := 0.0
var _transition: StringName = &""
var _shot_active := false
var _cycle_short := false
var _short_anchor := false
var _lower_phase := 0.0
var _lower_entry_loaded := false
var _lower_unloaded := false
var _lower_empty_route := false

func reset() -> void:
	loaded = false
	_clip = &"carry"
	_phase = 0.0
	_transition = &""
	_shot_active = false
	_cycle_short = false
	_short_anchor = false
	_lower_phase = 0.0
	_lower_entry_loaded = false
	_lower_unloaded = false
	_lower_empty_route = false

func current_sample() -> Dictionary:
	return {"clip": StringName("%s/%s" % [direction_prefix, _clip]), "phase": _phase, "loaded": loaded}

func tick(delta: float, shot: RefCounted, posture: RefCounted, fired: bool = false) -> Dictionary:
	# These are deliberately the clocks' visual outputs, not combat queries.
	return advance(delta, str(shot.pose), float(shot.pose_phase), str(posture.state),
		float(posture.height), float(posture.tension), bool(posture.short_cycle), fired)

func advance(delta: float, shot_pose: String, shot_phase: float, posture_state: String,
		posture_height: float, draw_phase: float, short_cycle: bool, fired: bool = false) -> Dictionary:
	var step := delta if is_finite(delta) and delta > 0.0 else 0.0
	if fired:
		loaded = false
		_transition = &""
		_shot_active = true
		_cycle_short = short_cycle
		_short_anchor = false
		_lower_entry_loaded = false
		_lower_unloaded = false
		_lower_empty_route = false
		return _select(&"short_release" if _cycle_short else &"normal_release", 0.0)
	if step == 0.0:
		return current_sample()

	if _shot_active:
		if shot_pose == "release":
			loaded = false
			return _select(&"short_release" if _cycle_short else &"normal_release", shot_phase)
		if shot_pose == "recover":
			loaded = _unit(shot_phase) >= 1.0
			return _select(&"short_recover" if _cycle_short else &"normal_renock", shot_phase)
		# The clock completed recovery, including when a render skipped its final
		# sample. The hand is now at its terminal nock pose, not a fresh raise.
		loaded = true
		_shot_active = false
		_short_anchor = _cycle_short

	if not _transition.is_empty():
		return _advance_transition(step, posture_state)

	var wants_draw := posture_state == "draw" and shot_pose == "draw"
	if not wants_draw:
		# Capture the actual displayed atlas phase, never the raw shot-clock phase
		# or a newer filtered tension value after target loss.
		if _clip == &"normal_draw" and _phase > 0.0:
			_transition = &"normal_cancel"
			return _select(&"controlled_undraw", 1.0 - _phase)
		if _clip == &"short_draw":
			if _phase > 0.0:
				_transition = &"short_reverse"
				return current_sample()
			_transition = &"short_cancel"
			return _select(&"short_undraw", 0.0)
		if _short_anchor:
			_transition = &"short_cancel"
			return _select(&"short_undraw", 0.0)

	if wants_draw:
		var draw_clip: StringName = &"short_draw" if _short_anchor else &"normal_draw"
		if _clip != draw_clip:
			# Reaching the brace via raise/renock/returned lower allows a new nock.
			# This is the only non-recovery transition that can create a held arrow.
			loaded = true
			return _select(draw_clip, 0.0)
		var duration := short_draw_follow_duration if _short_anchor else normal_draw_follow_duration
		return _select(draw_clip, move_toward(_phase, _unit(draw_phase), step / _duration(duration)))

	if posture_state in ["lower", "carry"]:
		if _clip == &"carry":
			loaded = false
			return current_sample()
		var start := 1.0 - _phase if _clip == &"raise" else 0.0
		return _begin_lower(start)
	if posture_state == "raise":
		# The posture clock may still be catching up after our longer cancel /
		# lower reversal. Never leave an already reached brace to replay an
		# earlier EMPTY raise (especially while retaining a nocked arrow).
		if _at_brace(): return _hold()
		# Ordinary raise is an EMPTY reverse lower. Loaded reversal is handled
		# inside its latched lower transition, never by an empty raise clip.
		return _select(&"raise", posture_height)
	if _clip == &"carry" and _unit(posture_height) <= 0.0:
		loaded = false
		return current_sample()
	return _hold()

func _advance_transition(step: float, posture_state: String) -> Dictionary:
	match _transition:
		&"normal_cancel":
			var phase := move_toward(_phase, 1.0, step / _duration(normal_undraw_duration))
			if phase >= 1.0:
				_transition = &""
				_short_anchor = false
			return _select(&"controlled_undraw", phase)
		&"short_reverse":
			var phase := move_toward(_phase, 0.0, step / _duration(short_reverse_duration))
			if phase <= 0.0:
				_transition = &"short_cancel"
				return _select(&"short_undraw", 0.0)
			return _select(&"short_draw", phase)
		&"short_cancel":
			var phase := move_toward(_phase, 1.0, step / _duration(short_undraw_duration))
			if phase >= 1.0:
				_transition = &""
				_short_anchor = false
			return _select(&"short_undraw", phase)
		&"lower":
			var reversing := posture_state in ["raise", "draw", "hold_relaxed"]
			var duration := raise_duration if reversing else lower_duration
			_lower_phase = move_toward(_lower_phase, 0.0 if reversing else 1.0, step / _duration(duration))
			if _lower_entry_loaded and _lower_phase >= _unit(unload_phase):
				_lower_unloaded = true
				loaded = false
			if _lower_phase >= 1.0 and not reversing:
				_transition = &""
				loaded = false
				return _select(&"carry", 0.0)
			# The entry latch stays fixed. After unloading, reversing the loaded
			# atlas below its unload frame would resurrect its baked arrow.
			if reversing and _lower_unloaded: _lower_empty_route = true
			var clip: StringName = &"lower_loaded" if _lower_entry_loaded and not _lower_empty_route else &"lower"
			if reversing and _lower_phase <= 0.0:
				_transition = &""
				_short_anchor = false
				# Publish the empty/loaded brace endpoint for this sample. A later
				# genuine draw entry may nock a NEW arrow; reversal itself cannot.
			return _select(clip, _lower_phase)
	return current_sample()

func _begin_lower(phase: float) -> Dictionary:
	_transition = &"lower"
	_lower_phase = _unit(phase)
	_lower_entry_loaded = loaded
	_lower_unloaded = _lower_entry_loaded and _lower_phase >= _unit(unload_phase)
	_lower_empty_route = false
	if _lower_unloaded: loaded = false
	return _select(&"lower_loaded" if _lower_entry_loaded else &"lower", _lower_phase)

func _hold() -> Dictionary:
	return _select(&"hold_relaxed_loaded" if loaded else &"hold_relaxed", 0.0)

func _at_brace() -> bool:
	if _clip in [&"hold_relaxed", &"hold_relaxed_loaded"]: return true
	if _clip in [&"controlled_undraw", &"short_undraw", &"normal_renock"]: return _phase >= 1.0
	if _clip in [&"lower", &"lower_loaded", &"normal_draw"]: return _phase <= 0.0
	return false

func _select(clip: StringName, phase: float) -> Dictionary:
	_clip = clip
	_phase = _unit(phase)
	return current_sample()

func _unit(value: float) -> float:
	return clampf(value, 0.0, 1.0) if is_finite(value) else 0.0

func _duration(value: float) -> float:
	return maxf(value, 0.001) if is_finite(value) else 0.001
