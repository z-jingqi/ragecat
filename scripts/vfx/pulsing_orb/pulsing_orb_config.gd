extends Resource
const SPECS = [["orb_radius", "Orb radius", 8, 23, 1, 13], ["pulse_amount", "Pulse amplitude", 0, 0.3, 0.01, 0.08], ["pulse_hz", "Pulse frequency", 0.5, 4, 0.1, 2.4], ["intensity", "Strength", 0.25, 1.5, 0.05, 1], ["charge_seconds", "Build duration", 0.15, 1.3, 0.01, 0.36], ["dissipate_seconds", "Dissipation", 0.1, 1, 0.05, 0.15]]
@export_range(8,23,1) var orb_radius := 13.0
@export_range(0,0.3,0.01) var pulse_amount := 0.08
@export_range(0.5,4,0.1) var pulse_hz := 2.4
@export_range(0.25,1.5,0.05) var intensity := 1.0
@export_range(0.15,1.3,0.01) var charge_seconds := 0.36
@export_range(0.1,1,0.05) var dissipate_seconds := 0.15
@export var rim_color := Color("3c8ed7")
@export var body_color := Color("6cdae9")
@export var inner_color := Color("b6f5f0")
@export var core_color := Color("fffdf0")
func sanitize() -> void:
	for spec in SPECS:
		var value: float=get(spec[0])
		set(spec[0],clampf(value,spec[2],spec[3]) if is_finite(value) else spec[5])
	if not is_finite(rim_color.r) or not is_finite(rim_color.g) or not is_finite(rim_color.b) or not is_finite(rim_color.a): rim_color=Color("3c8ed7")
	if not is_finite(body_color.r) or not is_finite(body_color.g) or not is_finite(body_color.b) or not is_finite(body_color.a): body_color=Color("6cdae9")
	if not is_finite(inner_color.r) or not is_finite(inner_color.g) or not is_finite(inner_color.b) or not is_finite(inner_color.a): inner_color=Color("b6f5f0")
	if not is_finite(core_color.r) or not is_finite(core_color.g) or not is_finite(core_color.b) or not is_finite(core_color.a): core_color=Color("fffdf0")
