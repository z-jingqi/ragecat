extends Resource
## Visual parameters only. A normalized amount never changes attack speed or gameplay.
@export_range(0.0, 1.5) var intensity: float = 1.0
@export_range(0.0, 0.6) var local_glow: float = 0.24
@export_range(0.0, 1.0) var flow_strength: float = 0.42
@export_range(0.0, 3.0) var flow_speed: float = 0.7
@export_range(0.0, 0.2) var breathing: float = 0.07
@export var dark_color: Color = Color("721622")
@export var seam_color: Color = Color("c32a37")
@export var hot_color: Color = Color("f77360")
@export var markings_enabled: bool = true
@export var flow_enabled: bool = true

func sanitized() -> Resource:
	var p = duplicate()
	p.intensity = _clean(intensity, 0.0, 1.5, 1.0)
	p.local_glow = _clean(local_glow, 0.0, 0.6, 0.24)
	p.flow_strength = _clean(flow_strength, 0.0, 1.0, 0.42)
	p.flow_speed = _clean(flow_speed, 0.0, 3.0, 0.7)
	p.breathing = _clean(breathing, 0.0, 0.2, 0.07)
	p.dark_color = _color(dark_color, Color("721622"))
	p.seam_color = _color(seam_color, Color("c32a37"))
	p.hot_color = _color(hot_color, Color("f77360"))
	return p

static func _clean(v: float, lo: float, hi: float, fallback: float) -> float:
	return clampf(v, lo, hi) if is_finite(v) else fallback

static func _color(c: Color, fallback: Color) -> Color:
	if not is_finite(c.r) or not is_finite(c.g) or not is_finite(c.b): return fallback
	return Color(clampf(c.r, 0, 1), clampf(c.g, 0, 1), clampf(c.b, 0, 1), 1)
