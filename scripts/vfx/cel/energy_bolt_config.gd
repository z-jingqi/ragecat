extends Resource
## Independent cel flight effect. Size is in world/canvas pixels; speed is px/sec.
@export_group("Shape")
@export_range(0.25, 2.5, 0.05) var size := 1.0
@export_range(24, 200, 1) var head_height := 96.0
@export_range(-180, 180, 1) var direction_degrees := 0.0
@export var detached_streaks := true
@export_group("Measured motion response")
@export_range(80, 1600, 10) var reference_speed := 640.0
@export_range(0.2, 1.0, 0.01) var tail_min := 0.38
@export_range(1.0, 2.5, 0.01) var tail_max := 1.65
@export_range(0.025, 0.5, 0.005) var response_seconds := 0.12
@export_range(1, 12, 0.5) var sample_distance := 3.0
@export_range(64, 512, 1) var history_limit := 256
@export_range(200, 4000, 10) var teleport_distance := 1200.0
@export_group("Intrinsic energy motion")
@export_range(0, 4, 0.05) var flow_speed := 1.4
@export_range(0, 2, 0.05) var flow_strength := 1.0
@export_range(0, 0.12, 0.005) var core_pulse_amplitude := 0.045
@export_range(0.2, 8, 0.1) var core_pulse_rate := 4.6
@export_range(0, 24, 0.5) var edge_shed_rate := 11.0
@export_range(0.06, 0.6, 0.01) var edge_lifetime := 0.24
@export_range(4, 70, 1) var edge_length := 26.0
@export_range(50, 600, 10) var edge_speed := 220.0
@export_group("Solid cel colors")
@export var core_color := Color("fdfadc")
@export var body_color := Color("ffea78")
@export var shade_color := Color("efab11")
@export var flow_color := Color("ffe49a")
@export var spark_color := Color("fff9d4")

func sanitize() -> void:
	for spec in [["size",0.25,2.5,1.0],["head_height",24.0,200.0,96.0],["direction_degrees",-180.0,180.0,0.0],["reference_speed",80.0,1600.0,640.0],["tail_min",0.2,1.0,0.38],["tail_max",1.0,2.5,1.65],["response_seconds",0.025,0.5,0.12],["sample_distance",1.0,12.0,3.0],["teleport_distance",200.0,4000.0,1200.0],["flow_speed",0.0,4.0,1.4],["flow_strength",0.0,2.0,1.0],["core_pulse_amplitude",0.0,0.12,0.045],["core_pulse_rate",0.2,8.0,4.6],["edge_shed_rate",0.0,24.0,11.0],["edge_lifetime",0.06,0.6,0.24],["edge_length",4.0,70.0,26.0],["edge_speed",50.0,600.0,220.0]]:
		var value: float = get(spec[0])
		set(spec[0],clampf(value,spec[1],spec[2]) if is_finite(value) else spec[3])
	history_limit = clampi(history_limit,64,512)
	for spec in [["core_color",Color("fdfadc")],["body_color",Color("ffea78")],["shade_color",Color("efab11")],["flow_color",Color("ffe49a")],["spark_color",Color("fff9d4")]]:
		var color: Color = get(spec[0])
		if not is_finite(color.r) or not is_finite(color.g) or not is_finite(color.b): color = spec[1]
		set(spec[0],Color(clampf(color.r,0,1),clampf(color.g,0,1),clampf(color.b,0,1),1))
