extends Resource
## Grid-free cel dissolve. The host supplies filled simple polygon contours.
@export_group("Shape and motion")
@export_range(0.25,3.0,0.05) var size := 1.0
@export_range(-180,180,1) var direction_degrees := 0.0
@export_range(0.25,2.0,0.05) var intensity := 1.0
@export var seed_value := 41
## The front starts at the far end of this axis and retreats across the source.
@export_range(-180,180,1) var erode_degrees := -35.0
@export_range(-180,180,1) var shard_direction_degrees := -38.0
@export_range(2,24,0.5) var edge_width := 8.0
@export_range(0,2,0.05) var edge_roughness := 1.0
@export_range(0,56,1) var shard_count := 31
@export_range(0.2,2,0.05) var shard_spread := 1.0
@export_range(0.3,2,0.05) var shard_size := 1.0
@export_range(80,520,10) var shard_speed := 235.0
@export_group("Timing")
@export_range(0.4,2.0,0.05) var duration_scale := 1.0
@export_range(0.025,0.12,0.005) var flash_seconds := 0.055
@export_range(0.25,1.1,0.01) var erosion_seconds := 0.60
@export_range(0.2,1.0,0.01) var shard_seconds := 0.64
@export_group("Independent layers")
@export var show_source := true
@export var show_flash := true
@export var show_edge := true
@export var show_shards := true
@export var show_wisps := true
@export_group("Flat cel palette")
## Only used when set_source_polygons() has no explicit per-contour colors.
@export var source_color := Color("687a90")
@export var core_color := Color("fff5d4")
@export var edge_color := Color("edc780")
@export var shard_color := Color("f7dfa9")
@export var ash_color := Color("84949e")

func sanitize() -> void:
	for spec in [["size",0.25,3.0,1.0],["direction_degrees",-180.0,180.0,0.0],["intensity",0.25,2.0,1.0],["erode_degrees",-180.0,180.0,-35.0],["shard_direction_degrees",-180.0,180.0,-38.0],["edge_width",2.0,24.0,8.0],["edge_roughness",0.0,2.0,1.0],["shard_spread",0.2,2.0,1.0],["shard_size",0.3,2.0,1.0],["shard_speed",80.0,520.0,235.0],["duration_scale",0.4,2.0,1.0],["flash_seconds",0.025,0.12,0.055],["erosion_seconds",0.25,1.1,0.60],["shard_seconds",0.2,1.0,0.64]]:
		var value: float = get(spec[0])
		set(spec[0],clampf(value,spec[1],spec[2]) if is_finite(value) else spec[3])
	shard_count = clampi(shard_count,0,56)
	for spec in [["source_color",Color("687a90")],["core_color",Color("fff5d4")],["edge_color",Color("edc780")],["shard_color",Color("f7dfa9")],["ash_color",Color("84949e")]]:
		var color: Color = get(spec[0])
		if not is_finite(color.r) or not is_finite(color.g) or not is_finite(color.b): color = spec[1]
		set(spec[0],Color(clampf(color.r,0,1),clampf(color.g,0,1),clampf(color.b,0,1),1.0))

func duration() -> float:
	return (flash_seconds+erosion_seconds+shard_seconds+0.05)*duration_scale
