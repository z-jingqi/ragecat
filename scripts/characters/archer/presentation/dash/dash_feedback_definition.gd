class_name ArcherDashFeedbackDefinition
extends Resource
## Cosmetic only: no movement, immunity, cooldown or shot settings.
@export var enabled := true
@export var afterimage_times := PackedFloat32Array([0.025, 0.09])
@export_range(0.01, 0.3) var afterimage_lifetime := 0.12
@export_range(0.0, 0.3) var afterimage_opacity := 0.12
@export_range(0, 12) var dust_count := 5
@export var dust_lifetime := 0.2
@export var dust_speed := 32.0
@export var dust_size := 2.0
@export var dust_color := Color(0.67, 0.61, 0.5, 0.2)
@export var foot_offset := Vector2(0, 24)

@export_group("Foot-level readiness marker")
@export var marker_enabled := true
@export var marker_offset := Vector2(11, 28)
@export_range(3.0, 16.0) var marker_size := 7.0
@export_range(0.5, 3.0) var marker_stroke_width := 1.0
@export var marker_background := Color(0.2, 0.23, 0.25, 0.55)
@export var marker_ready := Color(0.82, 0.86, 0.82, 0.75)
