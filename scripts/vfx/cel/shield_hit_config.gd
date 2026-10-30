extends Resource
## Independent cel-track presentation settings. No damage, collision or demo data.
@export_group("Shape")
@export_range(0.25, 3.0, 0.05) var size := 1.0
## Incoming direction: 0° points right. Sparks mostly return against this vector.
@export_range(-180, 180, 1) var direction_degrees := 0.0
@export_range(0, 12, 1) var spark_count := 7
@export_range(0.25, 2.0, 0.05) var spark_length := 1.0
@export_range(0.25, 1.5, 0.05) var scatter := 1.0
@export var seed_value := 27
@export_group("Timing")
@export_range(0.4, 2.0, 0.05) var duration_scale := 1.0
@export_range(0.025, 0.12, 0.005) var flash_seconds := 0.055
@export_range(0.18, 0.8, 0.01) var spark_seconds := 0.38
@export_range(0.4, 2.0, 0.05) var travel := 1.0
@export var show_arc := true
@export_group("Flat cel palette")
@export var core_color := Color("fff8dc")
@export var body_color := Color("ffd36a")
@export var shade_color := Color("eda443")
@export var arc_color := Color("c5d2d3")

func sanitize() -> void:
	for spec in [["size",0.25,3.0,1.0],["direction_degrees",-180.0,180.0,0.0],["spark_length",0.25,2.0,1.0],["scatter",0.25,1.5,1.0],["duration_scale",0.4,2.0,1.0],["flash_seconds",0.025,0.12,0.055],["spark_seconds",0.18,0.8,0.38],["travel",0.4,2.0,1.0]]:
		var value: float = get(spec[0])
		set(spec[0],clampf(value,spec[1],spec[2]) if is_finite(value) else spec[3])
	spark_count = clampi(spark_count,0,12)
	for spec in [["core_color",Color("fff8dc")],["body_color",Color("ffd36a")],["shade_color",Color("eda443")],["arc_color",Color("c5d2d3")]]:
		var color: Color = get(spec[0])
		if not is_finite(color.r) or not is_finite(color.g) or not is_finite(color.b): color = spec[1]
		set(spec[0],Color(clampf(color.r,0,1),clampf(color.g,0,1),clampf(color.b,0,1),1.0))

func duration() -> float:
	return (maxf(spark_seconds, maxf(flash_seconds * 2.4, 0.22)) + 0.04) * duration_scale
