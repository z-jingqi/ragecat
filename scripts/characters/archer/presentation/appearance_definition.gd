class_name ArcherAppearanceDefinition
extends Resource
## Character presentation data. No stat, hitbox, targeting or firing parameters.
@export_group("Rendered Frames")
@export var upper: ArcherPoseLibrary
@export var lower: ArcherPoseLibrary
@export var display_scale: float = 1.0
@export var direction_names: PackedStringArray = PackedStringArray(["east", "southeast", "south", "southwest", "west", "northwest", "north", "northeast"])
@export var gait_bobs: Dictionary = {}
@export var idle_bobs: Dictionary = {}
@export var directional_strides: PackedFloat32Array = PackedFloat32Array()
@export var movement_clips: PackedStringArray = PackedStringArray(["run_forward", "run_forward_right", "run_right", "run_back_right", "run_back", "run_back_left", "run_left", "run_forward_left"])
@export var stride_pixels: float = 80.0
@export var shadow_offset: Vector2 = Vector2(0, 24)
@export var shadow_size: Vector2 = Vector2(16, 5)
@export var shadow_color: Color = Color(0.01, 0.02, 0.04, 0.4)

@export_group("Dash Feedback")
@export var dash_feedback: ArcherDashFeedbackDefinition
@export var dash_motion: ArcherDashMotionDefinition

@export_group("Projectile Presentation")
@export var muzzle_positions: PackedVector2Array = PackedVector2Array()
@export_range(0.0, 8.0) var muzzle_handoff_limit: float = 8.0
@export_range(0.0, 24.0) var muzzle_handoff_distance: float = 24.0
@export_range(0.0, 0.05) var muzzle_handoff_max_duration: float = 0.05
@export var muzzle_near_hit_clearance: float = 16.0

@export_group("Shot Presentation")
@export var release_duration: float = 0.065
@export var recovery_duration: float = 0.12
@export var draw_duration: float = 0.25

@export_group("Bow Posture")
@export var target_confirmation: float = 0.05
@export var target_loss_grace: float = 0.16
@export var raise_duration: float = 0.14
@export var lower_duration: float = 0.22
@export var relax_duration: float = 0.10
@export var draw_follow_duration: float = 0.08
@export var short_enter_interval: float = 0.22
@export var short_exit_interval: float = 0.30
@export var maximum_full_draw_hold: float = 0.25

@export_group("Visual Cancellation")
@export var normal_undraw_duration: float = 0.10
@export var short_reverse_duration: float = 0.055
@export var short_undraw_duration: float = 0.10
@export var short_draw_follow_duration: float = 0.04
@export_range(0.0, 1.0) var unload_phase: float = 0.818181818


func create_pose_clock() -> ArcherPoseClock:
	var result := ArcherPoseClock.new()
	result.stride_distance = maxf(0.001, stride_pixels)
	result.directional_strides = directional_strides.duplicate()
	result.locomotion_directions = maxi(1, movement_clips.size())
	result.release_duration = maxf(0.001, release_duration)
	result.recovery_duration = maxf(0.001, recovery_duration)
	result.draw_duration = maxf(0.001, draw_duration)
	return result

func create_posture_clock() -> BowPostureClock:
	var result := BowPostureClock.new()
	result.target_confirmation = maxf(0.0, target_confirmation)
	result.target_loss_grace = maxf(0.0, target_loss_grace)
	result.raise_duration = maxf(0.001, raise_duration)
	result.lower_duration = maxf(0.001, lower_duration)
	result.relax_duration = maxf(0.001, relax_duration)
	result.draw_follow_duration = maxf(0.001, draw_follow_duration)
	result.short_enter_interval = maxf(0.001, short_enter_interval)
	result.short_exit_interval = maxf(result.short_enter_interval, short_exit_interval)
	result.maximum_full_draw_hold = maxf(0.0, maximum_full_draw_hold)
	return result

func create_selector() -> ArcherPoseClipSelector:
	var result := ArcherPoseClipSelector.new()
	result.normal_undraw_duration = maxf(0.001, normal_undraw_duration)
	result.short_reverse_duration = maxf(0.001, short_reverse_duration)
	result.short_undraw_duration = maxf(0.001, short_undraw_duration)
	result.lower_duration = maxf(0.001, lower_duration)
	result.raise_duration = maxf(0.001, raise_duration)
	result.normal_draw_follow_duration = maxf(0.001, draw_follow_duration)
	result.short_draw_follow_duration = maxf(0.001, short_draw_follow_duration)
	result.unload_phase = clampf(unload_phase, 0.0, 1.0)
	return result
