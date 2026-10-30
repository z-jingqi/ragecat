extends Resource
## Inspector-editable settings. sanitize() also protects programmatic callers.
@export_range(-180,180,1) var direction_degrees := 0.0
@export_range(30,290,1) var arc_degrees := rad_to_deg(3.7)
@export_range(24,75,1) var radius := 75.0
@export_range(0.3,1,0.01) var aspect := 0.67
@export_range(0.25,2,0.05) var width := 1.0
@export_range(0.08,0.5,0.01) var sweep_seconds := 0.17
@export_range(0,6,1) var ghost_count := 3
@export_range(0.015,0.08,0.005) var ghost_spacing := 0.035
@export_range(0.02,0.3,0.005) var ghost_lifetime := 0.105

func sanitize() -> void:
	for spec in [["direction_degrees",-180.0,180.0,0.0],["arc_degrees",30.0,290.0,rad_to_deg(3.7)],["radius",24.0,75.0,75.0],["aspect",0.3,1.0,0.67],["width",0.25,2.0,1.0],["sweep_seconds",0.08,0.5,0.17],["ghost_spacing",0.015,0.08,0.035],["ghost_lifetime",0.02,0.3,0.105]]:
		var value: float = get(spec[0])
		set(spec[0],clampf(value,spec[1],spec[2]) if is_finite(value) else spec[3])
	ghost_count = clampi(ghost_count,0,6)
