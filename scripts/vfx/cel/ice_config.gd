extends Resource
## Independent crystallization, held ice, fracture and source-bound fragments.
@export_group("Shape")
@export_range(0.25,3,0.05) var size := 1.0
@export_range(-180,180,1) var direction_degrees := 0.0
@export_range(0.25,2,0.05) var intensity := 1.0
@export var seed_value := 107
@export_range(100,360,5) var height := 240.0
@export_range(24,100,2) var width := 54.0
@export_range(0.3,1.6,0.05) var spread := 1.0
@export_range(1,7,1) var crystal_count := 5
@export_range(0.25,2,0.05) var shatter_force := 1.0
@export_range(0,2,0.05) var spin := 1.0
@export_range(0,3,0.05) var glint_speed := 1.0
@export_group("Timing")
@export_range(0.4,2,0.05) var duration_scale := 1.0
@export_range(0.16,0.8,0.01) var growth_seconds := 0.38
@export_range(0.2,2,0.05) var hold_seconds := 0.55
@export_range(0.06,0.35,0.01) var crack_seconds := 0.13
@export_range(0.35,1.2,0.01) var shatter_seconds := 0.72
@export_group("Independent layers")
@export var show_crystals := true
@export var show_frost := true
@export var show_glints := true
@export var show_cracks := true
@export var show_chunks := true
@export var show_shards := true
@export_group("Flat cel palette")
@export var shadow_color := Color("398bc7")
@export var body_color := Color("79c9eb")
@export var light_color := Color("96e2e8")
@export var ridge_color := Color("e7fcfa")
@export var crack_color := Color("f7ffff")

func sanitize() -> void:
	for spec in [["size",0.25,3.0,1.0],["direction_degrees",-180.0,180.0,0.0],["intensity",0.25,2.0,1.0],["height",100.0,360.0,240.0],["width",24.0,100.0,54.0],["spread",0.3,1.6,1.0],["shatter_force",0.25,2.0,1.0],["spin",0.0,2.0,1.0],["glint_speed",0.0,3.0,1.0],["duration_scale",0.4,2.0,1.0],["growth_seconds",0.16,0.8,0.38],["hold_seconds",0.2,2.0,0.55],["crack_seconds",0.06,0.35,0.13],["shatter_seconds",0.35,1.2,0.72]]:
		var value: float = get(spec[0])
		set(spec[0],clampf(value,spec[1],spec[2]) if is_finite(value) else spec[3])
	crystal_count = clampi(crystal_count,1,7)
	for spec in [["shadow_color",Color("398bc7")],["body_color",Color("79c9eb")],["light_color",Color("96e2e8")],["ridge_color",Color("e7fcfa")],["crack_color",Color("f7ffff")]]:
		var color: Color = get(spec[0])
		if not is_finite(color.r) or not is_finite(color.g) or not is_finite(color.b): color = spec[1]
		set(spec[0],Color(clampf(color.r,0,1),clampf(color.g,0,1),clampf(color.b,0,1),1.0))

func duration() -> float:
	return (growth_seconds+hold_seconds+crack_seconds+shatter_seconds+0.04)*duration_scale
