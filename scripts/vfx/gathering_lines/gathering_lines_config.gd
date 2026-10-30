extends Resource
const SPECS = [["charge_seconds", "Build duration (s)", 0.2, 1.3, 0.05, 0.6], ["radius", "Gather radius (px)", 38, 78, 1, 62], ["streak_count", "Needle count", 8, 40, 1, 28], ["intensity", "Strength", 0.2, 1, 0.05, 0.9], ["gather_speed", "Inward speed", 0.5, 2, 0.1, 1], ["center_offset_y", "Center offset Y", -60, 0, 1, -38], ["upper_scale", "Upper radial scale", 0.3, 1, 0.05, 0.72], ["lower_scale", "Lower radial scale", 0.3, 1, 0.05, 0.42], ["end_radius", "Inner radius (px)", 0, 16, 1, 10], ["length_min", "Minimum length", 2, 10, 1, 5], ["length_max", "Maximum length", 10, 24, 1, 20], ["life_scale", "Lifetime scale", 0.5, 2, 0.1, 1], ["dissipate_seconds", "Dissipation (s)", 0.08, 0.4, 0.01, 0.15]]
@export_range(0.2,1.3,0.05) var charge_seconds := 0.6
@export_range(38,78,1) var radius := 62.0
@export_range(8,40,1) var streak_count := 28.0
@export_range(0.2,1,0.05) var intensity := 0.9
@export_range(0.5,2,0.1) var gather_speed := 1.0
@export_range(-60,0,1) var center_offset_y := -38.0
@export_range(0.3,1,0.05) var upper_scale := 0.72
@export_range(0.3,1,0.05) var lower_scale := 0.42
@export_range(0,16,1) var end_radius := 10.0
@export_range(2,10,1) var length_min := 5.0
@export_range(10,24,1) var length_max := 20.0
@export_range(0.5,2,0.1) var life_scale := 1.0
@export_range(0.08,0.4,0.01) var dissipate_seconds := 0.15
@export var main_color := Color("5ef5cb")
@export var highlight_color := Color("d7fff3")
@export var glow_color := Color("ffffff")
func sanitize() -> void:
	for spec in SPECS:
		var value: float=get(spec[0])
		set(spec[0],clampf(value,spec[2],spec[3]) if is_finite(value) else spec[5])
	if not is_finite(main_color.r) or not is_finite(main_color.g) or not is_finite(main_color.b) or not is_finite(main_color.a): main_color=Color("5ef5cb")
	if not is_finite(highlight_color.r) or not is_finite(highlight_color.g) or not is_finite(highlight_color.b) or not is_finite(highlight_color.a): highlight_color=Color("d7fff3")
	if not is_finite(glow_color.r) or not is_finite(glow_color.g) or not is_finite(glow_color.b) or not is_finite(glow_color.a): glow_color=Color("ffffff")
