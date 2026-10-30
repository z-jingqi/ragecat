extends "res://scripts/vfx/shared/component_lifecycle.gd"
const Config=preload("res://scripts/vfx/gathering_lines/gathering_lines_config.gd")
func _init() -> void: config=Config.new()
## Stable event-local noise: randomness never changes mid-flight or depends on frame rate.
func noise(seed: int) -> float:
	var value := (seed*1103515245+12345)&0x7fffffff
	value=((value^(value>>11))*48271)&0x7fffffff
	return float(value)/2147483647.0

func energy_event(index: int, time: float) -> Dictionary:
	var elapsed := maxf(0,time-START) if is_finite(time) else 0.0
	var during := minf(elapsed,config.charge_seconds)
	var travel: float = (0.8*during+2.5*during*during/(2*config.charge_seconds)+maxf(0,elapsed-config.charge_seconds)*3.3)*config.gather_speed
	var period: float = (0.65+noise(index*17+51)*0.8)*config.life_scale
	var clock: float = travel+noise(index*31+117)*period
	var cycle := floori(clock/period)
	var seed := index*1999+cycle*7919+127
	var flight: float = period*(0.55+noise(seed+17)*0.35)
	var age := fposmod(clock,period)
	return {"active":age<flight,"life":clampf(age/flight,0,1),
		"angle":noise(seed+41)*TAU,"radius":0.7+noise(seed+79)*0.5,
		"length":config.length_min+pow(noise(seed+131),2.0)*(config.length_max-config.length_min),
		"width":0.65+noise(seed+211)*0.95,
		"brightness":0.45+noise(seed+307)*0.55,
		"accent":noise(seed+401)>0.84}
