extends Resource
## Visual configuration only. Range is not a gameplay collision or damage value.
@export_group("Arc / art pixels")
@export_range(20, 88, 1) var radius := 52.0
@export_range(4, 28, 1) var thickness := 16.0
@export_range(50, 220, 1) var sweep_degrees := 148.0
@export_range(-180, 180, 1) var direction_degrees := -12.0
@export_range(0.45, 1, 0.01) var squash := 0.78
@export_range(0, 3, 0.1) var roughness := 1.4
@export var reverse := false
@export_range(1, 3, 1) var pixel_size := 1.0
@export_group("Timing / seconds")
@export_range(0.12, 0.6, 0.01) var duration := 0.25
@export_range(0.025, 0.09, 0.001) var onset := 0.05
@export_range(0, 0.08, 0.005) var hold := 0.035
@export_group("Copper palette")
@export var edge_color := Color("efb079")
@export var body_color := Color("cc6942")
@export var inner_color := Color("a33c2e")
@export var shade_color := Color("62242c")
@export_range(0, 1.5, 0.05) var intensity := 1.0
@export_range(0, 65535, 1) var shape_seed := 19
@export_group("Hit sparks / independent")
@export var sparks_enabled := true
@export_range(0, 16, 1) var spark_count := 6
@export_range(0.08, 0.5, 0.01) var spark_duration := 0.24
@export_range(10, 120, 1) var spark_speed := 76.0
@export var spark_color := Color("cb5c40")
@export_group("Blood / independent")
@export var blood_enabled := true
@export_range(0, 20, 1) var blood_count := 9
@export_range(0.15, 0.8, 0.01) var blood_duration := 0.42
@export_range(10, 160, 1) var blood_speed := 92.0
@export var blood_color := Color("ba2e42")
@export var blood_shade := Color("722337")

func sanitized():
	var copy = duplicate()
	var limits := {
		"radius":[20.,88.,52.], "thickness":[4.,28.,16.], "sweep_degrees":[50.,220.,148.],
		"direction_degrees":[-180.,180.,-12.], "squash":[0.45,1.,0.78], "roughness":[0.,3.,1.4],
		"pixel_size":[1.,3.,1.], "duration":[0.12,0.6,0.25], "onset":[0.025,0.09,0.05],
		"hold":[0.,0.08,0.035], "intensity":[0.,1.5,1.], "shape_seed":[0.,65535.,19.],
		"spark_count":[0.,16.,6.], "spark_duration":[0.08,0.5,0.24], "spark_speed":[10.,120.,76.],
		"blood_count":[0.,20.,9.], "blood_duration":[0.15,0.8,0.42], "blood_speed":[10.,160.,92.]}
	for key in limits:
		var value := float(get(key))
		copy.set(key, clampf(value,limits[key][0],limits[key][1]) if is_finite(value) else limits[key][2])
	copy.thickness = minf(copy.thickness, copy.radius * 0.5)
	copy.pixel_size = roundf(copy.pixel_size)
	copy.onset = minf(copy.onset,copy.duration * 0.4)
	copy.hold = minf(copy.hold,copy.duration * 0.2)
	for key in ["edge_color","body_color","inner_color","shade_color","spark_color","blood_color","blood_shade"]:
		var color: Color = get(key)
		if not is_finite(color.r) or not is_finite(color.g) or not is_finite(color.b): color = Color("a33c2e")
		copy.set(key,Color(clampf(color.r,0,1),clampf(color.g,0,1),clampf(color.b,0,1),1))
	return copy

func hit_position() -> Vector2:
	# Point in the center of the forward cutting face, not a collision query.
	return Vector2(radius-thickness*0.4,0).rotated(deg_to_rad(direction_degrees))

func preview_duration() -> float:
	return maxf(duration,onset+maxf(spark_duration,blood_duration))
