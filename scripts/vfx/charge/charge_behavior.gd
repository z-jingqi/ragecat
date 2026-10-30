extends RefCounted
## Reusable sustained charge: never attacks or stops by itself.
## The caller explicitly supplies stop_at to begin a separate cleanup phase.
const Config = preload("res://scripts/vfx/charge/charge_config.gd")
const START := 0.2
var config := Config.new()

func configure(settings: Resource) -> void:
	config = settings.duplicate(true) if settings is Config else Config.new()
	config.sanitize()

func valid_stop(stop_at: float) -> bool:
	return is_finite(stop_at) and stop_at >= START

func duration(stop_at: float = -1.0) -> float:
	config.sanitize()
	return stop_at+config.dissipate_seconds+0.25 if valid_stop(stop_at) else INF

func sample(time: float, stop_at: float = -1.0) -> Dictionary:
	config.sanitize()
	var t := maxf(0,time) if is_finite(time) else 0.0
	var progress := clampf((t-START)/config.charge_seconds,0,1)
	var phase := "READY"
	var opacity := 0.0
	if t >= START:
		phase = "SUSTAIN" if progress >= 1.0 else ("GATHER" if progress < 0.65 else "INTENSIFY")
		opacity = 1.0
	if valid_stop(stop_at) and t >= stop_at:
		progress = clampf((stop_at-START)/config.charge_seconds,0,1)
		opacity = 1.0-clampf((t-stop_at)/config.dissipate_seconds,0,1)
		phase = "DISSIPATE" if opacity > 0.0 else "FINISHED"
	return {"phase":phase,"charge":progress*config.intensity,
		"opacity":opacity,"active":opacity>0.0}

func particle(index: int, time: float) -> Vector2:
	config.sanitize()
	var t := (maxf(0,time) if is_finite(time) else 0.0)*config.inward_speed
	var progress := fposmod(t*(0.8+index%3*0.12)+index*0.618034,1.0)
	var angle := index*2.399963+t*0.65
	return Vector2.from_angle(angle)*(8.0+config.radius*(1.0-progress))
