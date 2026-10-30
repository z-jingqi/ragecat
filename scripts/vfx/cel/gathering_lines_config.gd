extends Resource
## Standalone straight inward cel streaks. Lengths/radii use local canvas units.
@export_group("Distribution")
@export_range(0.25,2.5,0.05) var size := 1.0
@export_range(1,96,1) var line_count := 36
@export_range(0.1,2,0.05) var density := 1.0
@export var seed := 23
@export_range(20,500,1) var spawn_radius_min := 170.0
@export_range(20,600,1) var spawn_radius_max := 300.0
@export_range(0,200,1) var end_radius := 14.0
@export_group("Streak shape")
@export_range(4,80,1) var length_min := 22.0
@export_range(4,150,1) var length_max := 65.0
@export_range(0.5,12,0.1) var width_min := 2.0
@export_range(0.5,20,0.1) var width_max := 5.0
@export_group("Timing")
@export_range(0.08,1.5,0.01) var lifetime_min := 0.24
@export_range(0.08,1.5,0.01) var lifetime_max := 0.46
@export_range(0.25,3,0.05) var speed := 1.0
@export_range(0.05,1,0.01) var dissipate_seconds := 0.2
@export_group("Flat cel palette")
@export var core_color := Color("fff6d6")
@export var body_color := Color("ffe28a")
@export var shade_color := Color("eab43e")
const SPECS := [
	["size",0.25,2.5,1.0],["density",0.1,2.0,1.0],
	["spawn_radius_min",20.0,500.0,170.0],["spawn_radius_max",20.0,600.0,300.0],
	["end_radius",0.0,200.0,14.0],["length_min",4.0,80.0,22.0],["length_max",4.0,150.0,65.0],
	["width_min",0.5,12.0,2.0],["width_max",0.5,20.0,5.0],
	["lifetime_min",0.08,1.5,0.24],["lifetime_max",0.08,1.5,0.46],
	["speed",0.25,3.0,1.0],["dissipate_seconds",0.05,1.0,0.2],
]
func sanitize() -> void:
	for spec in SPECS:
		var value: float = get(spec[0])
		set(spec[0],clampf(value,spec[1],spec[2]) if is_finite(value) else spec[3])
	line_count = clampi(line_count,1,96)
	seed = posmod(seed,1000000)
	spawn_radius_max = maxf(spawn_radius_max,spawn_radius_min)
	end_radius = minf(end_radius,spawn_radius_min-4.0)
	length_max = maxf(length_max,length_min)
	width_max = maxf(width_max,width_min)
	lifetime_max = maxf(lifetime_max,lifetime_min)
	for spec in [["core_color",Color("fff6d6")],["body_color",Color("ffe28a")],["shade_color",Color("eab43e")]]:
		var color: Color = get(spec[0])
		if not is_finite(color.r) or not is_finite(color.g) or not is_finite(color.b): color = spec[1]
		set(spec[0],Color(clampf(color.r,0,1),clampf(color.g,0,1),clampf(color.b,0,1),1))
