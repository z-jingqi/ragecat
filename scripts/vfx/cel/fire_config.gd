extends Resource
## A finite ignition/sustain/release study, or host-held fire ended by release().
@export_group("Shape")
@export_range(0.25,3,0.05) var size := 1.0
@export_range(-180,180,1) var direction_degrees := 0.0
@export_range(0.25,2,0.05) var intensity := 1.0
@export var seed_value := 59
@export_range(80,320,5) var base_width := 180.0
@export_range(80,360,5) var height := 220.0
@export_range(0,2,0.05) var curl := 1.0
@export_range(0,3,0.05) var flow_speed := 1.0
@export_range(0,24,0.5) var ember_rate := 8.0
@export_group("Timing")
@export_range(0.4,2,0.05) var duration_scale := 1.0
@export_range(0.06,0.5,0.01) var ignition_seconds := 0.15
@export_range(0.2,4,0.05) var sustain_seconds := 1.10
@export_range(0.15,1,0.01) var release_seconds := 0.40
@export_range(0.2,0.9,0.01) var ember_seconds := 0.55
@export_group("Independent layers")
@export var show_body := true
@export var show_channels := true
@export var show_core := true
@export var show_detached := true
@export var show_embers := true
@export_group("Flat cel palette")
@export var rim_color := Color("fa4424")
@export var body_color := Color("ff8b25")
@export var channel_color := Color("ffd34b")
@export var core_color := Color("fff1b3")
@export var ember_color := Color("ffc547")

func sanitize() -> void:
	for spec in [["size",0.25,3.0,1.0],["direction_degrees",-180.0,180.0,0.0],["intensity",0.25,2.0,1.0],["base_width",80.0,320.0,180.0],["height",80.0,360.0,220.0],["curl",0.0,2.0,1.0],["flow_speed",0.0,3.0,1.0],["ember_rate",0.0,24.0,8.0],["duration_scale",0.4,2.0,1.0],["ignition_seconds",0.06,0.5,0.15],["sustain_seconds",0.2,4.0,1.10],["release_seconds",0.15,1.0,0.40],["ember_seconds",0.2,0.9,0.55]]:
		var value: float = get(spec[0])
		set(spec[0],clampf(value,spec[1],spec[2]) if is_finite(value) else spec[3])
	for spec in [["rim_color",Color("fa4424")],["body_color",Color("ff8b25")],["channel_color",Color("ffd34b")],["core_color",Color("fff1b3")],["ember_color",Color("ffc547")]]:
		var color: Color = get(spec[0])
		if not is_finite(color.r) or not is_finite(color.g) or not is_finite(color.b): color = spec[1]
		set(spec[0],Color(clampf(color.r,0,1),clampf(color.g,0,1),clampf(color.b,0,1),1.0))

func duration() -> float:
	return (ignition_seconds+sustain_seconds+release_seconds+ember_seconds+0.04)*duration_scale
