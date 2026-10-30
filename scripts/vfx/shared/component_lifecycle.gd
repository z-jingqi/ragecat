extends RefCounted
const START := 0.2
var config: Resource
func configure(settings: Resource) -> void:
	config = settings.duplicate(true)
	config.sanitize()
func valid_stop(stop_at: float) -> bool:
	return is_finite(stop_at) and stop_at >= START
func duration(stop_at: float = -1.0) -> float:
	config.sanitize()
	return stop_at+config.dissipate_seconds+0.25 if valid_stop(stop_at) else INF
func sample(time: float, stop_at: float = -1.0) -> Dictionary:
	config.sanitize()
	var t := maxf(0,time) if is_finite(time) else 0.0
	var build_t := minf(t,stop_at) if valid_stop(stop_at) and t>=stop_at else t
	var q := clampf((build_t-START)/config.charge_seconds,0,1)
	var opacity := 1.0 if t>=START else 0.0
	var phase := "HOLD" if q>=1 else ("ANTICIPATE" if q<0.15 else "GATHER")
	if t<START: phase="IDLE"
	if valid_stop(stop_at) and t>=stop_at:
		opacity=1.0-clampf((t-stop_at)/config.dissipate_seconds,0,1)
		phase="DISSIPATE" if opacity>0 else "FINISHED"
	return {"phase":phase,"charge":q,"opacity":opacity,"active":opacity>0,
	"crouch":smoothstep(0.0,0.25,q)*opacity}
