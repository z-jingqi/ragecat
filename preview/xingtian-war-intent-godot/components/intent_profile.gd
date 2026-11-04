extends Resource
## Visual inputs only. Momentum and its gameplay rules belong to the host.
@export_group("Ground geometry")
@export_range(18, 50, 1) var radius: float = 34.0
@export_range(0.25, 0.65, 0.01) var perspective: float = 0.42
@export_range(6, 16, 1) var crack_count: int = 10
@export_range(8, 24, 1) var ring_segments: int = 18
@export var shape_seed: int = 37
@export_group("Restrained light")
@export_range(0.1, 1, 0.01) var opacity: float = 0.88
@export_range(0, 0.15, 0.01) var breathing: float = 0.045
@export var dark: Color = Color("381c24")
@export var red: Color = Color("8d3038")
@export var edge: Color = Color("bd5c4b")

func sanitized() -> Resource:
	var p = duplicate()
	p.radius = safe(radius, 34.0, 18.0, 50.0)
	p.perspective = safe(perspective, 0.42, 0.25, 0.65)
	p.crack_count = clampi(crack_count, 6, 16)
	p.ring_segments = clampi(ring_segments, 8, 24)
	p.shape_seed = clampi(shape_seed, 0, 65535)
	p.opacity = safe(opacity, 0.88, 0.1, 1.0)
	p.breathing = safe(breathing, 0.045, 0.0, 0.15)
	for key in ["dark", "red", "edge"]:
		var c: Color = p.get(key)
		p.set(key, Color(safe(c.r, 0.4, 0.0, 1.0), safe(c.g, 0.1, 0.0, 1.0), safe(c.b, 0.15, 0.0, 1.0), 1.0))
	return p

static func safe(value: float, fallback: float, low: float, high: float) -> float:
	return clampf(value, low, high) if is_finite(value) else fallback
