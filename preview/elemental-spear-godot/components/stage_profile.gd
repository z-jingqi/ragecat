extends Resource
## A replaceable visual phase. All values affect this phase only.
@export var enabled: bool = true
@export_range(0.02,12.0,0.01) var duration: float = 0.5
@export_enum("Fire", "Lightning", "Ice") var element: int = 0
@export_range(0.25,2.0,0.05) var size: float = 1.0
@export var tint: Color = Color.WHITE
@export_range(0.0,1.5,0.05) var intensity: float = 1.0
## Optional RefCounted script implementing render(canvas, phase, state, config, stage).
@export var renderer_override: Script
func sanitize() -> void:
	duration = clampf(duration if is_finite(duration) else 0.5,0.02,12.0)
	size = clampf(size if is_finite(size) else 1.0,0.25,2.0)
	intensity = clampf(intensity if is_finite(intensity) else 1.0,0.0,1.5)
	element = clampi(element,0,2)
	for channel in ["r","g","b","a"]:
		tint[channel] = clampf(tint[channel] if is_finite(tint[channel]) else 1.0,0.0,1.0)
