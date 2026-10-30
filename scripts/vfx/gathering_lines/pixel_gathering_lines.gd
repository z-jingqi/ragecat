extends "res://scripts/vfx/shared/pixel_commands.gd"
var behavior=preload("res://scripts/vfx/gathering_lines/gathering_lines_behavior.gd").new()
var time:=0.0
var stop_at:=-1.0
var effect_origin:=Vector2(192,132)
func gather_point(index: int, life: float, event: Dictionary = {}) -> Vector2:
	var data: Dictionary=behavior.energy_event(index,0.2) if event.is_empty() else event
	var angle: float=data.angle
	var distance: float = lerpf(behavior.config.radius*data.radius,behavior.config.end_radius,life*life)
	return effect_origin+Vector2(0,behavior.config.center_offset_y)+Vector2(cos(angle)*distance,sin(angle)*distance*(behavior.config.upper_scale if sin(angle)<0 else behavior.config.lower_scale))

func needle(point: Vector2, direction: Vector2, length: float, width: float, color: Color) -> void:
	var end := point+direction*length
	var normal := Vector2(-direction.y,direction.x)
	var low := point.min(end)-Vector2.ONE*2
	var high := point.max(end)+Vector2.ONE*2
	for y in range(floori(low.y),ceili(high.y)+1):
		for x in range(floori(low.x),ceili(high.x)+1):
			var delta := Vector2(x+0.5,y+0.5)-point
			var u := delta.dot(direction)/length
			if u<=0 or u>=1: continue
			# A thin luminous belly, not a white square cap. Both ends taper and fade.
			var taper := pow(sin(u*PI),0.8)
			var coverage := clampf(width*0.5*taper+0.52-absf(delta.dot(normal)),0,1)
			var alpha := color.a*taper*coverage
			if alpha>0.015: rect(Rect2(x,y,1,1),Color(color,alpha))

func gathering(state: Dictionary) -> void:
	var cfg = behavior.config
	var q: float = state.charge
	var sample_time := minf(time,stop_at) if state.phase=="DISSIPATE" else time
	var compression := smoothstep(0.82,1.0,q)
	var envelope: float = (0.25+0.75*q)*(1.0-compression*0.64)
	for i in range(cfg.streak_count):
		if behavior.noise(i*59+61)>smoothstep(0.0,0.8,q): continue
		var event: Dictionary=behavior.energy_event(i,sample_time)
		if not event.active: continue
		var life: float=event.life
		var opacity: float = pow(sin(life*PI),0.7)*state.opacity*cfg.intensity*envelope*event.brightness
		var point := gather_point(i,life,event)
		var outward := (point-effect_origin-Vector2(0,behavior.config.center_offset_y)).normalized()
		var length: float=event.length*(0.6+q*0.4)
		var tint: Color=cfg.highlight_color if event.accent else cfg.main_color
		needle(point,outward,length,event.width,Color(tint*cfg.glow_color,minf(1,opacity*(2.0 if event.accent else 1.8))*tint.a*cfg.glow_color.a))


func build_commands() -> Array:
	commands=[]
	var state: Dictionary=behavior.sample(time,stop_at)
	if state.active: gathering(state)
	return commands
