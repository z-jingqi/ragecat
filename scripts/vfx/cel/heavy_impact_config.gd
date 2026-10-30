extends Resource
## Presentation only. Local +X is the ground; local -Y is the impact crown.
@export_group("Shape")
@export_range(0.25,3.0,0.05) var size := 1.0
@export_range(-180,180,1) var direction_degrees := 0.0
@export_range(0.25,2.0,0.05) var intensity := 1.0
@export var seed_value := 73
@export var show_flash := true
@export var show_shockwave := true
@export var show_dust := true
@export var show_chips := true
@export_group("Timing")
@export_range(0.4,2.0,0.05) var duration_scale := 1.0
@export_range(0.035,0.12,0.005) var flash_seconds := 0.055
@export_range(0.2,0.75,0.01) var shockwave_seconds := 0.4
@export_range(0.6,2.0,0.05) var dust_seconds := 1.25
@export_group("Shockwave and debris")
@export_range(100,480,5) var shockwave_radius := 300.0
@export_range(0,16,1) var dust_count := 12
@export_range(0.4,1.8,0.05) var dust_spread := 1.0
@export_range(0,20,1) var chip_count := 11
@export_range(120,1000,20) var chip_gravity := 520.0
@export_group("Flat cel palette")
@export var core_color := Color("fff4d2")
@export var wave_color := Color("f3cf7d")
@export var dust_color := Color("c6b091")
@export var dust_shade_color := Color("8e806b")
@export var chip_color := Color("b29a72")

func sanitize() -> void:
	for spec in [["size",0.25,3.0,1.0],["direction_degrees",-180.0,180.0,0.0],["intensity",0.25,2.0,1.0],["duration_scale",0.4,2.0,1.0],["flash_seconds",0.035,0.12,0.055],["shockwave_seconds",0.2,0.75,0.4],["dust_seconds",0.6,2.0,1.25],["shockwave_radius",100.0,480.0,300.0],["dust_spread",0.4,1.8,1.0],["chip_gravity",120.0,1000.0,520.0]]:
		var value: float = get(spec[0])
		set(spec[0],clampf(value,spec[1],spec[2]) if is_finite(value) else spec[3])
	dust_count = clampi(dust_count,0,16)
	chip_count = clampi(chip_count,0,20)
	for spec in [["core_color",Color("fff4d2")],["wave_color",Color("f3cf7d")],["dust_color",Color("c6b091")],["dust_shade_color",Color("8e806b")],["chip_color",Color("b29a72")]]:
		var color: Color = get(spec[0])
		if not is_finite(color.r) or not is_finite(color.g) or not is_finite(color.b): color = spec[1]
		set(spec[0],Color(clampf(color.r,0,1),clampf(color.g,0,1),clampf(color.b,0,1),1.0))

func duration() -> float:
	# Includes the latest staggered cloud and the slowest ballistic chip.
	return (maxf(maxf(dust_seconds+0.13,shockwave_seconds+0.02),maxf(flash_seconds*3.5,1.08))+0.04)*duration_scale
