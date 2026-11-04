extends Resource
## Display only. Width is in the component's local pixels, before parent scaling.
@export var color: Color = Color("ef7965")
@export_range(0.0, 1.0) var intensity: float = 0.58
@export_range(0.5, 8.0) var width: float = 2.8
@export_range(0.0, 0.2) var breathing: float = 0.045
@export_range(0.0, 3.0) var breathing_speed: float = 0.7

func sanitized() -> Resource:
	var p = duplicate()
	p.intensity = clean(intensity, 0, 1, 0.58)
	p.width = clean(width, 0.5, 8, 2.8)
	p.breathing = clean(breathing, 0, 0.2, 0.045)
	p.breathing_speed = clean(breathing_speed, 0, 3, 0.7)
	p.color = Color(clean(color.r, 0, 1, 0.937), clean(color.g, 0, 1, 0.475), clean(color.b, 0, 1, 0.396), 1)
	return p

static func clean(value: float, lo: float, hi: float, fallback: float) -> float:
	return clampf(value, lo, hi) if is_finite(value) else fallback
