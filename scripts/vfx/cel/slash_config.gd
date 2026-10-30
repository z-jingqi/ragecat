extends Resource
## Independent, outline-free cel slash. Pixels are local canvas units.
@export_group("Crescent shape")
@export_range(0.25, 2.5, 0.05) var size := 1.0
@export_range(160, 1100, 10) var length := 760.0
@export_range(6, 220, 1) var thickness := 128.0
## Vertical / horizontal radius. Lower values flatten the arc.
@export_range(0.3, 1.0, 0.01) var curvature := 0.56
@export_range(60, 250, 1) var arc_degrees := 210.0
@export_range(-180, 180, 1) var direction_degrees := 0.0
## Mirrors the whole gesture before applying direction_degrees.
@export var reverse := false
@export_group("Timing")
@export_range(0.025, 0.25, 0.005) var sweep_seconds := 0.08
@export_range(0.0, 0.15, 0.005) var peak_seconds := 0.045
@export_range(0.05, 0.4, 0.005) var disappear_seconds := 0.17
@export_range(0.4, 2.0, 0.05) var duration_scale := 1.0
## Additional radial extension during the peak, not a second wave.
@export_range(0, 0.2, 0.01) var extension := 0.055
@export_group("Flat cel palette")
@export var core_color := Color("fff5d9")
@export var body_color := Color("ffd269")
@export var shade_color := Color("d68c32")

func sanitize() -> void:
	for spec in [["size",0.25,2.5,1.0],["length",160.0,1100.0,760.0],["thickness",6.0,220.0,128.0],["curvature",0.3,1.0,0.56],["arc_degrees",60.0,250.0,210.0],["direction_degrees",-180.0,180.0,0.0],["sweep_seconds",0.025,0.25,0.08],["peak_seconds",0.0,0.15,0.045],["disappear_seconds",0.05,0.4,0.17],["duration_scale",0.4,2.0,1.0],["extension",0.0,0.2,0.055]]:
		var value: float = get(spec[0])
		set(spec[0],clampf(value,spec[1],spec[2]) if is_finite(value) else spec[3])
	# The inner contour must stay inside a positive radius at every allowed shape.
	thickness = minf(thickness,length*0.35)
	for spec in [["core_color",Color("fff5d9")],["body_color",Color("ffd269")],["shade_color",Color("d68c32")]]:
		var color: Color = get(spec[0])
		if not is_finite(color.r) or not is_finite(color.g) or not is_finite(color.b): color = spec[1]
		set(spec[0],Color(clampf(color.r,0,1),clampf(color.g,0,1),clampf(color.b,0,1),1.0))

func duration() -> float:
	return (sweep_seconds+peak_seconds+disappear_seconds)*duration_scale
