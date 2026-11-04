extends "slash_profile.gd"
## Art-only heavy variant. These ranges never define damage, collision or attack speed.
@export_group("Ground pressure / art pixels")
@export var pressure_enabled:=true
@export_range(32,112,1) var pressure_radius:=72.0
@export_range(.12,.6,.01) var pressure_duration:=.32
@export_range(0,1.5,.05) var pressure_strength:=.85
@export var pressure_color:=Color("e9a463")
@export_range(1,6,.25) var pressure_thickness:=3.0
@export_range(.2,.7,.01) var pressure_squash:=.34
@export_range(0,16,1) var debris_count:=8
@export var pressure_echo:=true
func _init()->void:
	radius=70; thickness=20; duration=.44; onset=.075; hold=.07; roughness=.8
	thread_duration=.08; glow_strength=.18
	impact_radius=16; impact_duration=.18; impact_core_duration=.045
	spark_count=7; spark_speed=90; blood_count=9
func sanitized():
	var copy=super.sanitized()
	var limits:={"pressure_radius":[32.,112.,72.],"pressure_duration":[.12,.6,.32],"pressure_strength":[0.,1.5,.85],"pressure_thickness":[1.,6.,3.],"pressure_squash":[.2,.7,.34],"debris_count":[0.,16.,8.]}
	for key in limits:
		var value:=float(get(key))
		copy.set(key,clampf(value,limits[key][0],limits[key][1]) if is_finite(value) else limits[key][2])
	var color:Color=pressure_color
	if not is_finite(color.r) or not is_finite(color.g) or not is_finite(color.b): color=Color("e9a463")
	copy.pressure_color=Color(clampf(color.r,0,1),clampf(color.g,0,1),clampf(color.b,0,1),1)
	return copy
