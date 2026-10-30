extends RefCounted
## Deterministic accelerating inward points; no automatic launch.
const Config = preload("res://scripts/vfx/pulsing_orb/pulsing_orb_config.gd")
const START := 0.04
const BUILD_SECONDS := 0.36
var config := Config.new()
func configure(settings: Resource) -> void:
	config = settings.duplicate(true) if settings is Config else Config.new()
	config.sanitize()
func valid_stop(stop_at: float) -> bool: return is_finite(stop_at) and stop_at>=START
func duration(stop_at: float = -1) -> float:
	config.sanitize()
	return stop_at+config.dissipate_seconds+0.25 if valid_stop(stop_at) else INF
func sample(time: float,stop_at: float = -1) -> Dictionary:
	config.sanitize()
	var t := maxf(0,time) if is_finite(time) else 0.0
	var q := smoothstep(START,START+config.charge_seconds,t)
	var opacity := 1.0 if t>=START else 0.0
	var phase := "READY" if t<START else ("GATHER" if q<1 else "HOLD")
	if valid_stop(stop_at) and t>=stop_at:
		q=smoothstep(START,START+config.charge_seconds,stop_at)
		opacity=1-clampf((t-stop_at)/config.dissipate_seconds,0,1)
		phase="DISSIPATE" if opacity>0 else "FINISHED"
	return {"phase":phase,"charge":q,"opacity":opacity,"active":opacity>0,
		"orb_scale":(0.4+q*0.6)*(1+config.pulse_amount*sin(t*TAU*config.pulse_hz))*opacity}
