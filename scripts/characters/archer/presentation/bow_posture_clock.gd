class_name BowPostureClock
extends RefCounted
## Visual posture only. Actual launch always wins over a natural raise transition.
var target_confirmation := 0.05
var target_loss_grace := 0.16
var raise_duration := 0.14
var lower_duration := 0.22
var relax_duration := 0.10
var draw_follow_duration := 0.08
var short_enter_interval := 0.22
var short_exit_interval := 0.30
var maximum_full_draw_hold := 0.25
var height := 0.0
var tension := 0.0
var state := "carry"
var short_cycle := false
var fast_entry := false
var _target_time := 0.0
var _missing_time := 0.0
var _full_hold_time := 0.0
var _draw_blocked := false

func reset() -> void:
	height = 0.0
	tension = 0.0
	state = "carry"
	short_cycle = false
	fast_entry = false
	_target_time = 0.0
	_missing_time = 0.0
	_full_hold_time = 0.0
	_draw_blocked = false

func tick(delta: float, has_target: bool, enabled: bool, fired: bool,
		interval: float, shot_pose: String, shot_phase: float) -> void:
	if delta <= 0.0 and not fired: return
	var step := maxf(delta, 0.0)
	var usable := has_target and enabled
	if usable:
		_target_time += step
		_missing_time = 0.0
	else:
		_target_time = 0.0
		_missing_time += step
	if fired:
		# Cold acquisition cannot have a full pre-shot raise without delaying combat.
		# Select a purpose-authored fast-release entry, never a late draw animation.
		fast_entry = height < 0.8
		height = 1.0
		_missing_time = 0.0
		_target_time = target_confirmation
		_full_hold_time = 0.0
		_draw_blocked = false
		if interval <= short_enter_interval: short_cycle = true
		elif interval >= short_exit_interval: short_cycle = false
	elif shot_pose != "release":
		fast_entry = false
	var finishing := shot_pose in ["release", "recover"]
	var raised := finishing or (usable and _target_time >= target_confirmation) or (height > 0.0 and _missing_time < target_loss_grace)
	var previous_height := height
	if raised: height = move_toward(height, 1.0, step / maxf(raise_duration, 0.001))
	else: height = move_toward(height, 0.0, step / maxf(lower_duration, 0.001))
	if usable and shot_pose == "draw" and shot_phase >= 0.999 and not fired:
		_full_hold_time += step
		if _full_hold_time >= maximum_full_draw_hold: _draw_blocked = true
	elif shot_pose not in ["draw", "rest"]:
		_full_hold_time = 0.0
		_draw_blocked = false
	if shot_pose == "release":
		tension = 1.0 - clampf(shot_phase, 0.0, 1.0)
	elif not usable or _draw_blocked:
		tension = move_toward(tension, 0.0, step / maxf(relax_duration, 0.001))
	elif shot_pose == "draw":
		var follow_window := maxf(0.001, minf(draw_follow_duration, interval * 0.4))
		tension = move_toward(tension, clampf(shot_phase, 0.0, 1.0), step / follow_window)
	else:
		tension = 0.0
	if finishing: state = "fast_release" if fast_entry else shot_pose
	elif (not usable or _draw_blocked) and tension > 0.0: state = "relax"
	elif height <= 0.0: state = "carry"
	elif height < previous_height: state = "lower"
	elif height < 1.0: state = "raise"
	elif shot_pose == "draw" and usable and not _draw_blocked: state = "draw"
	else: state = "hold_relaxed"
