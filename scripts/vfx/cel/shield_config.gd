extends Resource
## Independent energy barrier, local impacts and source-related shell breakup.
@export_group("Shape")
@export_range(0.25,3,0.05) var size := 1.0
@export_range(-180,180,1) var direction_degrees := 0.0
@export_range(0.25,2,0.05) var intensity := 1.0
@export var seed_value := 211
@export_range(70,230,1) var radius := 145.0
@export_range(0.7,1.4,0.01) var aspect := 1.08
@export_range(8,54,1) var rim_width := 37.0
@export_range(0,3,0.05) var flow_speed := 1.0
@export_range(0,22,1) var dent_depth := 12.0
@export_range(0.5,2,0.05) var ripple_speed := 1.0
@export_range(0.25,2,0.05) var hit_size := 1.0
@export_range(0.25,2,0.05) var break_force := 1.0
@export_range(0,2,0.05) var spin := 1.0
@export_range(6,12,1) var piece_count := 8
@export_group("Timing")
@export_range(0.4,2,0.05) var duration_scale := 1.0
@export_range(0.16,0.8,0.01) var spawn_seconds := 0.40
@export_range(0.3,4,0.05) var hold_seconds := 1.40
@export_range(0.2,0.8,0.01) var hit_seconds := 0.45
@export_range(0.3,1.2,0.01) var break_seconds := 0.65
@export_group("Independent layers")
@export var show_shell := true
@export var show_highlights := true
@export var show_streaks := true
@export var show_hits := true
@export var show_ripples := true
@export var show_fragments := true
@export var show_chips := true
@export_group("Opaque cel palette")
@export var rim_color := Color("3da8db")
@export var body_color := Color("75e1ee")
@export var highlight_color := Color("fff8dc")
@export var hit_color := Color("fff9df")
@export var spark_color := Color("f8d58b")

func sanitize() -> void:
	for spec in [["size",0.25,3.0,1.0],["direction_degrees",-180.0,180.0,0.0],["intensity",0.25,2.0,1.0],["radius",70.0,230.0,145.0],["aspect",0.7,1.4,1.08],["rim_width",8.0,54.0,37.0],["flow_speed",0.0,3.0,1.0],["dent_depth",0.0,22.0,12.0],["ripple_speed",0.5,2.0,1.0],["hit_size",0.25,2.0,1.0],["break_force",0.25,2.0,1.0],["spin",0.0,2.0,1.0],["duration_scale",0.4,2.0,1.0],["spawn_seconds",0.16,0.8,0.40],["hold_seconds",0.3,4.0,1.40],["hit_seconds",0.2,0.8,0.45],["break_seconds",0.3,1.2,0.65]]:
		var value: float = get(spec[0])
		set(spec[0],clampf(value,spec[1],spec[2]) if is_finite(value) else spec[3])
	piece_count = clampi(piece_count,6,12)
	for spec in [["rim_color",Color("3da8db")],["body_color",Color("75e1ee")],["highlight_color",Color("fff8dc")],["hit_color",Color("fff9df")],["spark_color",Color("f8d58b")]]:
		var color: Color = get(spec[0])
		if not is_finite(color.r) or not is_finite(color.g) or not is_finite(color.b): color = spec[1]
		set(spec[0],Color(clampf(color.r,0,1),clampf(color.g,0,1),clampf(color.b,0,1),1.0))

func duration() -> float:
	return (spawn_seconds+hold_seconds+break_seconds+0.04)*duration_scale
