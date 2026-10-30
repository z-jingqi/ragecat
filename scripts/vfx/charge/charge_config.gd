extends Resource
## Sustained charge presentation controls; no attack or damage parameters.
@export_range(0.4,2.5,0.05) var charge_seconds := 1.2
@export_range(24,64,1) var radius := 48.0
@export_range(0.5,2,0.05) var strength := 1.0
@export_range(0.25,1,0.05) var intensity := 1.0
@export_range(0.2,1,0.05) var dissipate_seconds := 0.45
@export_range(0.25,3,0.05) var wind_speed := 1.0
@export_range(16,60,1) var rise_height := 42.0
@export_range(0.25,3,0.05) var inward_speed := 1.0
@export_range(0,40,1) var particle_count := 24

func sanitize() -> void:
	for spec in [["charge_seconds",0.4,2.5,1.2],["radius",24.0,64.0,48.0],["strength",0.5,2.0,1.0],["intensity",0.25,1.0,1.0],["dissipate_seconds",0.2,1.0,0.45],["wind_speed",0.25,3.0,1.0],["rise_height",16.0,60.0,42.0],["inward_speed",0.25,3.0,1.0]]:
		var value: float = get(spec[0])
		set(spec[0],clampf(value,spec[1],spec[2]) if is_finite(value) else spec[3])
	particle_count = clampi(particle_count,0,40)
