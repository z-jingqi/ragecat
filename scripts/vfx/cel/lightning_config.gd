extends Resource
## Presentation only. Local origin is contact; the leader descends from local -Y.
@export_group("Shape")
@export_range(0.25,3,0.05) var size := 1.0
@export_range(-180,180,1) var direction_degrees := 0.0
@export_range(0.25,2,0.05) var intensity := 1.0
@export var seed_value := 83
@export_range(160,520,5) var length := 340.0
@export_range(6,42,0.5) var bolt_width := 22.0
@export_range(0,72,1) var zigzag := 36.0
@export_range(0,7,1) var branch_count := 4
@export_range(30,190,5) var branch_reach := 110.0
@export_range(0.25,2,0.05) var contact_size := 1.0
@export_group("Timing")
@export_range(0.4,2,0.05) var duration_scale := 1.0
@export_range(1,5,1) var stroke_count := 3
@export_range(0.06,0.35,0.01) var leader_seconds := 0.13
@export_range(0.04,0.18,0.005) var stroke_seconds := 0.075
@export_range(0.02,0.14,0.005) var stroke_gap_seconds := 0.045
@export_range(0.15,0.65,0.01) var residual_seconds := 0.32
@export_group("Independent layers")
@export var show_leader := true
@export var show_main := true
@export var show_branches := true
@export var show_contact := true
@export var show_residual := true
@export var show_sparks := true
@export_group("Flat cel palette")
@export var rim_color := Color("638dff")
@export var core_color := Color("fffbee")
@export var residual_color := Color("9cbaff")

func sanitize() -> void:
	for spec in [["size",0.25,3.0,1.0],["direction_degrees",-180.0,180.0,0.0],["intensity",0.25,2.0,1.0],["length",160.0,520.0,340.0],["bolt_width",6.0,42.0,22.0],["zigzag",0.0,72.0,36.0],["branch_reach",30.0,190.0,110.0],["contact_size",0.25,2.0,1.0],["duration_scale",0.4,2.0,1.0],["leader_seconds",0.06,0.35,0.13],["stroke_seconds",0.04,0.18,0.075],["stroke_gap_seconds",0.02,0.14,0.045],["residual_seconds",0.15,0.65,0.32]]:
		var value: float = get(spec[0])
		set(spec[0],clampf(value,spec[1],spec[2]) if is_finite(value) else spec[3])
	branch_count = clampi(branch_count,0,7)
	stroke_count = clampi(stroke_count,1,5)
	for spec in [["rim_color",Color("638dff")],["core_color",Color("fffbee")],["residual_color",Color("9cbaff")]]:
		var color: Color = get(spec[0])
		if not is_finite(color.r) or not is_finite(color.g) or not is_finite(color.b): color = spec[1]
		set(spec[0],Color(clampf(color.r,0,1),clampf(color.g,0,1),clampf(color.b,0,1),1.0))

func strike_end() -> float:
	return leader_seconds+stroke_count*stroke_seconds+(stroke_count-1)*stroke_gap_seconds

func duration() -> float:
	return (strike_end()+residual_seconds+0.04)*duration_scale
