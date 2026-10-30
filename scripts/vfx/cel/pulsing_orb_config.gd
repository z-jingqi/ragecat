extends Resource
## Hand-shaped opaque planes, independent of gathering lines or gameplay.
@export_group("Orb shape")
@export_range(0.25,2.5,0.05) var size := 1.0
@export_range(12,200,1) var radius := 104.0
@export_range(0,1.5,0.05) var accent_strength := 1.0
@export_group("Pulse and lifecycle")
@export_range(0,0.15,0.005) var pulse_amplitude := 0.045
@export_range(0.1,12,0.1) var pulse_rate := 3.8
@export_range(0.05,1,0.01) var dissipate_seconds := 0.22
@export_group("Flat cel palette")
@export var core_color := Color("fff6d6")
@export var body_color := Color("ffe28a")
@export var shade_color := Color("eab43e")
const SPECS := [["size",0.25,2.5,1.0],["radius",12.0,200.0,104.0],["accent_strength",0.0,1.5,1.0],["pulse_amplitude",0.0,0.15,0.045],["pulse_rate",0.1,12.0,3.8],["dissipate_seconds",0.05,1.0,0.22]]
func sanitize() -> void:
	for spec in SPECS:
		var value: float = get(spec[0])
		set(spec[0],clampf(value,spec[1],spec[2]) if is_finite(value) else spec[3])
	for spec in [["core_color",Color("fff6d6")],["body_color",Color("ffe28a")],["shade_color",Color("eab43e")]]:
		var color: Color = get(spec[0])
		if not is_finite(color.r) or not is_finite(color.g) or not is_finite(color.b): color = spec[1]
		set(spec[0],Color(clampf(color.r,0,1),clampf(color.g,0,1),clampf(color.b,0,1),1))
