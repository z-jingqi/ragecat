extends "res://scripts/vfx/shared/pixel_commands.gd"
var behavior=preload("res://scripts/vfx/pulsing_orb/pulsing_orb_behavior.gd").new()
var time:=0.0
var stop_at:=-1.0
var effect_origin:=Vector2(192,80)
func disc(center: Vector2,radius: float,color: Color) -> void:
	var r := maxi(1,roundi(radius))
	for y in range(-r,r+1):
		var x := floorf(sqrt(maxf(0,r*r-y*y)))
		rect(Rect2(center+Vector2(-x,y),Vector2(2*x+1,1)),color)
func build_commands() -> Array:
	commands=[]
	var state: Dictionary=behavior.sample(time,stop_at)
	if not state.active: return commands
	var cfg=behavior.config
	var opacity: float=state.opacity
	var orb: float=cfg.orb_radius*state.orb_scale*(0.8+0.2*cfg.intensity)
	# Small anticipation core gathers into a clean bright, steady charged sphere.
	disc(effect_origin,orb+2*opacity,cfg.rim_color)
	disc(effect_origin,orb,cfg.body_color)
	disc(effect_origin-Vector2(1,1),orb*0.75,cfg.inner_color)
	disc(effect_origin-Vector2(1,1),orb*0.48,cfg.core_color)
	return commands
