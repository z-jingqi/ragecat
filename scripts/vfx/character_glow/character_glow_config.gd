extends Resource
const SPECS = [["charge_seconds", "Build duration", 0.2, 1.3, 0.05, 0.6], ["intensity", "Glow strength", 0.2, 1, 0.05, 0.9], ["halo_width", "Contour width", 2, 10, 1, 8], ["floor_glow", "Floor strength", 0, 1, 0.05, 0.85], ["dissipate_seconds", "Dissipation", 0.08, 0.4, 0.01, 0.15]]
@export_range(0.2,1.3,0.05) var charge_seconds := 0.6
@export_range(0.2,1,0.05) var intensity := 0.9
@export_range(2,10,1) var halo_width := 8.0
@export_range(0,1,0.05) var floor_glow := 0.85
@export_range(0.08,0.4,0.01) var dissipate_seconds := 0.15
@export var floor_tint := Color("ffffff")
@export var contour_color := Color(0.04,1.0,0.59)
@export var rim_color := Color(0.44,1.0,0.77)
@export var body_tint := Color("8dffd0")
func sanitize() -> void:
	for spec in SPECS:
		var value: float=get(spec[0])
		set(spec[0],clampf(value,spec[2],spec[3]) if is_finite(value) else spec[5])
	if not is_finite(floor_tint.r) or not is_finite(floor_tint.g) or not is_finite(floor_tint.b) or not is_finite(floor_tint.a): floor_tint=Color("ffffff")
	if not is_finite(contour_color.r) or not is_finite(contour_color.g) or not is_finite(contour_color.b) or not is_finite(contour_color.a): contour_color=Color(0.04,1.0,0.59)
	if not is_finite(rim_color.r) or not is_finite(rim_color.g) or not is_finite(rim_color.b) or not is_finite(rim_color.a): rim_color=Color(0.44,1.0,0.77)
	if not is_finite(body_tint.r) or not is_finite(body_tint.g) or not is_finite(body_tint.b) or not is_finite(body_tint.a): body_tint=Color("8dffd0")
