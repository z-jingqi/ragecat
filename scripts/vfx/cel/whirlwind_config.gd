extends Resource
## Reusable wind funnel: spin-up, finite or held flow, source-bound release.
@export_group("Shape and flow")
@export_range(0.25,3,0.05) var size := 1.0
@export_range(-180,180,1) var direction_degrees := 0.0
@export_range(0.25,2,0.05) var intensity := 1.0
@export var seed_value := 173
@export_range(120,380,5) var height := 280.0
@export_range(50,170,1) var top_radius := 108.0
@export_range(2,7,1) var ribbon_count := 4
@export_range(4,28,1) var ribbon_width := 19.0
@export_range(0,2,0.01) var spin_speed := 0.72
@export_range(0,3,0.05) var rise_speed := 1.25
@export_range(0.25,2,0.05) var release_spread := 1.0
@export_group("Timing")
@export_range(0.4,2,0.05) var duration_scale := 1.0
@export_range(0.12,0.8,0.01) var spinup_seconds := 0.32
@export_range(0.2,4,0.05) var sustain_seconds := 1.15
@export_range(0.25,1.2,0.01) var release_seconds := 0.65
@export_group("Independent layers")
@export var show_ribbons := true
@export var show_highlights := true
@export var show_slivers := true
@export var show_ground := true
@export_group("Flat cel palette")
@export var front_color := Color("c1e8d5")
@export var back_color := Color("569b98")
@export var highlight_color := Color("eaffdf")
@export var sliver_color := Color("a8dccc")

func sanitize() -> void:
	for spec in [["size",0.25,3.0,1.0],["direction_degrees",-180.0,180.0,0.0],["intensity",0.25,2.0,1.0],["height",120.0,380.0,280.0],["top_radius",50.0,170.0,108.0],["ribbon_width",4.0,28.0,19.0],["spin_speed",0.0,2.0,0.72],["rise_speed",0.0,3.0,1.25],["release_spread",0.25,2.0,1.0],["duration_scale",0.4,2.0,1.0],["spinup_seconds",0.12,0.8,0.32],["sustain_seconds",0.2,4.0,1.15],["release_seconds",0.25,1.2,0.65]]:
		var value: float = get(spec[0])
		set(spec[0],clampf(value,spec[1],spec[2]) if is_finite(value) else spec[3])
	ribbon_count = clampi(ribbon_count,2,7)
	for spec in [["front_color",Color("c1e8d5")],["back_color",Color("569b98")],["highlight_color",Color("eaffdf")],["sliver_color",Color("a8dccc")]]:
		var color: Color = get(spec[0])
		if not is_finite(color.r) or not is_finite(color.g) or not is_finite(color.b): color = spec[1]
		set(spec[0],Color(clampf(color.r,0,1),clampf(color.g,0,1),clampf(color.b,0,1),1.0))

func duration() -> float:
	return (spinup_seconds+sustain_seconds+release_seconds+0.04)*duration_scale
