class_name ArcherPoseClock
extends RefCounted
## Pure presentation clock. This class cannot create projectiles or mutate combat.
var stride_distance := 72.0
var locomotion_directions := 8
var directional_strides := PackedFloat32Array()
var release_duration := 0.065
var recovery_duration := 0.12
var draw_duration := 0.25
var gait_phase := 0.0
var release_age := INF
var direction_index := 0
var locomotion_index := 0
var pose := "rest"
var pose_phase := 0.0
var moving := false
var _position := Vector2.ZERO
var _initialized := false
var _release_pending := false
var _release_window := 0.065
var _recovery_window := 0.12
var _draw_window := 0.25

func reset(at: Vector2) -> void:
	_position = at
	_initialized = true
	_release_pending = false
	gait_phase = 0.0
	release_age = INF
	pose = "rest"
	pose_phase = 0.0
	moving = false
	_release_window = release_duration
	_recovery_window = recovery_duration
	_draw_window = draw_duration

func displacement_to(at: Vector2) -> Vector2:
	return at - _position if _initialized else Vector2.ZERO

func notify_release() -> void:
	# Several launches in one simulation tick still have one visible release.
	_release_pending = true

func tick(delta: float, at: Vector2, aim: Vector2, dashing: bool,
		maximum_displacement: float, next_shot_in: float, shot_interval: float,
		has_target: bool, weapon_enabled: bool) -> void:
	if not _initialized:
		var first_release := _release_pending
		reset(at)
		_release_pending = first_release
	var step := maxf(delta, 0.0)
	var displacement := at - _position
	_position = at
	# Practice resets/teleports must not become a giant stride.
	if displacement.length() > maximum_displacement:
		var current_release := _release_pending
		reset(at)
		_release_pending = current_release
		displacement = Vector2.ZERO
	moving = displacement.length_squared() > 0.0001
	if not aim.is_zero_approx():
		direction_index = posmod(int(round(aim.angle() / (TAU / 8.0))), 8)
	if moving:
		locomotion_index = posmod(int(round(Vector2.from_angle(direction_index * TAU / 8.0).angle_to(displacement) / (TAU / locomotion_directions))), locomotion_directions)
	if moving and not dashing:
		var stride := stride_distance
		var stride_index := direction_index * locomotion_directions + locomotion_index
		if stride_index < directional_strides.size() and directional_strides[stride_index] > 0.0:
			stride = directional_strides[stride_index]
		gait_phase = fposmod(gait_phase + displacement.length() / maxf(stride, 0.001), 1.0)
	if _release_pending:
		release_age = 0.0
		_release_pending = false
		_release_window = minf(release_duration, maxf(shot_interval, 0.001) * 0.3)
		_recovery_window = minf(recovery_duration, maxf(shot_interval, 0.001) * 0.3)
		_draw_window = maxf(0.001, minf(draw_duration, maxf(shot_interval, 0.001) - _release_window - _recovery_window))
	else:
		release_age += step
	if release_age < _release_window:
		pose = "release"
		pose_phase = release_age / _release_window
	elif release_age < _release_window + _recovery_window:
		pose = "recover"
		pose_phase = (release_age - _release_window) / _recovery_window
	elif not weapon_enabled or not has_target:
		pose = "rest"
		pose_phase = 0.0
	elif next_shot_in <= _draw_window:
		pose = "draw"
		pose_phase = clampf(1.0 - next_shot_in / _draw_window, 0.0, 1.0)
	else:
		pose = "ready"
		pose_phase = 0.0
