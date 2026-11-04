extends Resource
## Visual-only configuration. This resource does not define combat radius, damage or cooldown.
@export_group("Footprint")
@export_range(16, 128, 1) var radius := 54.0
@export_range(0.35, 1.0, 0.01) var perspective := 0.62
@export_range(1, 4, 1) var pixel_size := 1.0
@export_range(0, 65535, 1) var shape_seed := 37
@export_group("Lifecycle / seconds")
@export_range(0.1, 2.0, 0.01) var opening_time := 0.65
@export_range(0.1, 20, 0.1) var hold_time := 3.6
@export_range(0.1, 4, 0.1) var cooling_time := 1.1
@export_range(0.1, 4, 0.1) var fade_time := 0.8
@export_group("Lava")
@export_range(0, 1, 0.01) var flow_speed := 0.22
@export_range(0.06, 0.4, 0.01) var channel_width := 0.31
@export_range(8, 24, 1) var crust_scale := 15.0
@export_range(0, 1, 0.01) var lava_opacity := 0.94
@export var lava_dark := Color("632326")
@export var lava_red := Color("ad3d2a")
@export var lava_orange := Color("e47737")
@export var crust_color := Color("29262b")
@export_group("Bubbles")
@export_range(0, 24, 1) var bubble_count := 7
@export_range(0.7, 5, 0.1) var bubble_period := 2.4
@export_range(1, 8, 0.5) var bubble_radius := 3.5
@export var bubble_color := Color("d86332")
@export_group("Short flames")
@export_range(0, 16, 1) var flame_count := 5
@export_range(2, 20, 1) var flame_height := 8.0
@export_range(0.5, 4, 0.1) var flame_period := 1.8
@export var flame_color := Color("f49a48")
@export_group("Rising smoke")
@export_range(0, 12, 1) var smoke_count := 3
@export_range(1, 6, 0.1) var smoke_period := 3.2
@export_range(4, 40, 1) var smoke_height := 22.0
@export_range(0, 0.35, 0.01) var smoke_opacity := 0.16
@export var smoke_color := Color("8b7a77")
@export_group("Impact sparks")
@export_range(0, 32, 1) var spark_count := 14
@export_range(0.1, 1, 0.01) var spark_duration := 0.48
@export_range(8, 80, 1) var spark_speed := 34.0
@export var spark_color := Color("ffc16a")

func sanitized():
	var copy = duplicate()
	var ranges := {"radius":[16.,128.,54.],"perspective":[0.35,1.,0.62],"pixel_size":[1.,4.,1.],"shape_seed":[0.,65535.,37.],"opening_time":[0.1,2.,0.65],"hold_time":[0.1,20.,3.6],"cooling_time":[0.1,4.,1.1],"fade_time":[0.1,4.,0.8],"flow_speed":[0.,1.,0.22],"channel_width":[0.06,0.4,0.31],"crust_scale":[8.,24.,15.],"lava_opacity":[0.,1.,0.94],"bubble_count":[0.,24.,7.],"bubble_period":[0.7,5.,2.4],"bubble_radius":[1.,8.,3.5],"flame_count":[0.,16.,5.],"flame_height":[2.,20.,8.],"flame_period":[0.5,4.,1.8],"spark_count":[0.,32.,14.],"spark_duration":[0.1,1.,0.48],"spark_speed":[8.,80.,34.],"smoke_count":[0.,12.,3.],"smoke_period":[1.,6.,3.2],"smoke_height":[4.,40.,22.],"smoke_opacity":[0.,0.35,0.16]}
	for key in ranges:
		var value := float(get(key))
		copy.set(key, clampf(value, ranges[key][0], ranges[key][1]) if is_finite(value) else ranges[key][2])
	copy.pixel_size = roundf(copy.pixel_size)
	for key in ["lava_dark", "lava_red", "lava_orange", "crust_color", "bubble_color", "flame_color", "spark_color", "smoke_color"]:
		var c: Color = get(key)
		if not is_finite(c.r) or not is_finite(c.g) or not is_finite(c.b): c = Color("9a3b2c")
		copy.set(key, Color(clampf(c.r,0,1),clampf(c.g,0,1),clampf(c.b,0,1),1))
	return copy

func total_time() -> float:
	return opening_time + hold_time + cooling_time + fade_time

func heat_at(age: float) -> float:
	return 1.0 - smoothstep(opening_time + hold_time, opening_time + hold_time + cooling_time, age)

func opacity_at(age: float) -> float:
	return 1.0 - smoothstep(total_time() - fade_time, total_time(), age)

func detail_scale() -> float:
	# Area growth adds detail, never light intensity, flame height or pixel size.
	return clampf(pow(radius / 54.0, 2.0), 0.4, 3.0)
