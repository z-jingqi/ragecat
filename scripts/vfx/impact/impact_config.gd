extends Resource
## Presentation parameters only. Defaults retain the approved armor-hit look.
@export_group("Hit")
@export_range(0.25, 2.0, 0.05) var strength := 1.0
@export_range(0.5, 1.5, 0.05) var effect_scale := 1.0
@export_range(-180, 180, 1) var direction_degrees := 0.0
@export var hit_position := Vector2(215, 79)
@export_group("Sparks")
@export_range(0, 40, 1) var spark_count := 19
@export_range(10, 160, 1) var spark_spread_degrees := rad_to_deg(2.3)
@export_range(0.25, 1.5, 0.05) var spark_speed := 1.0
@export_range(0.5, 1.5, 0.05) var spark_lifetime := 1.0
@export_group("Flash and smoke")
@export_range(0.025, 0.2, 0.005) var flash_seconds := 0.075
@export_range(0, 1.5, 0.05) var smoke_amount := 1.0
@export_range(0.3, 1.2, 0.05) var smoke_seconds := 0.95
@export_group("Target response — demonstration only")
@export_range(0, 8, 0.5) var recoil_pixels := 4.0
@export_range(0.1, 0.5, 0.01) var recoil_seconds := 0.24

func sanitize() -> void:
	for spec in [["strength",0.25,2.0,1.0],["effect_scale",0.5,1.5,1.0],["direction_degrees",-180.0,180.0,0.0],["spark_spread_degrees",10.0,160.0,rad_to_deg(2.3)],["spark_speed",0.25,1.5,1.0],["spark_lifetime",0.5,1.5,1.0],["flash_seconds",0.025,0.2,0.075],["smoke_amount",0.0,1.5,1.0],["smoke_seconds",0.3,1.2,0.95],["recoil_pixels",0.0,8.0,4.0],["recoil_seconds",0.1,0.5,0.24]]:
		var value: float = get(spec[0])
		set(spec[0],clampf(value,spec[1],spec[2]) if is_finite(value) else spec[3])
	spark_count = clampi(spark_count,0,40)
	if not hit_position.is_finite(): hit_position = Vector2(215,79)
	# Finite renderer-local coordinates are deliberately not clamped to this lab's viewport.
