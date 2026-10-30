extends RefCounted
## Style-independent one-handed sweep choreography; seconds and radians.
const WINDUP := 0.16
const SWEEP := 0.36
const FOLLOW := 0.53
const FADE := 0.79
const DURATION := 1.65
const Config = preload("res://scripts/vfx/slash/slash_config.gd")
var config := Config.new()
var direction: float:
	get: return deg_to_rad(config.direction_degrees)
	set(value): config.direction_degrees = rad_to_deg(value)

func timeline(time: float) -> float:
	config.sanitize()
	if time <= SWEEP: return time
	if time < follow_time(): return SWEEP+(time-SWEEP)*0.17/config.sweep_seconds
	return time-(config.sweep_seconds-0.17)

func follow_time() -> float: return SWEEP+config.sweep_seconds
func duration() -> float: return DURATION+config.sweep_seconds-0.17

func sample(time: float) -> Dictionary:
	var t := clampf(timeline(time), 0.0, DURATION)
	var end := -2.55+deg_to_rad(config.arc_degrees)
	var angle := -1.9
	if t >= WINDUP and t < SWEEP:
		angle = lerpf(-1.9, -2.55, smoothstep(WINDUP, SWEEP, t))
	elif t >= SWEEP:
		angle = lerpf(-2.55, end, ease(clampf((t-SWEEP)/(FOLLOW-SWEEP),0,1),0.65))
	if t > 1.05:
		angle = lerpf(end,-1.9,smoothstep(1.05,1.48,t))
	var phase := "READY"
	if t >= WINDUP: phase = "ANTICIPATION"
	if t >= SWEEP: phase = "SWEEP"
	if t >= FOLLOW: phase = "AFTERIMAGE / FADE"
	if t >= FADE: phase = "RECOVER"
	if t >= 1.48: phase = "READY"
	return {"angle":angle, "phase":phase,
		"trail": 1.0-smoothstep(FOLLOW,FADE,t) if t >= SWEEP and t < FADE else 0.0,
		"lean":sin(clampf((t-SWEEP)/0.5,0,1)*PI)*5.0}

func blade_point(angle: float, radius: float) -> Vector2:
	return Vector2(cos(angle)*radius, sin(angle)*radius*config.aspect).rotated(direction)
