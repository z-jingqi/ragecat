extends Node2D
## Analytic pixel whirlwind. Center is the ground anchor, +Y is down.
signal finished
const DEFAULTS = {"radius":32.0,"height":66.0,"layers":6,"turns_per_second":2.2,"clockwise":true,"arc_degrees":235.0,"width":2.0,"leaves":9,"seed":17,"enter":0.18,"sustain":1.7,"exit":0.24,"core":"e8fff1","body":"91d7ce","edge":"487b88","leaf":"b9cf78"}
var config:Dictionary=DEFAULTS.duplicate(true)
var active:=false
var automatic:=true
var age:=0.0
var duration:=0.0
var center:=Vector2(64,105)
var exiting:=false
var exit_age:=0.0
var exit_start:=1.0
func configure(overrides:Dictionary) -> void:
	config=DEFAULTS.duplicate(true)
	for k in overrides:
		if config.has(k):config[k]=overrides[k]
	for k in ["radius","height","turns_per_second","arc_degrees","width","enter","sustain","exit"]:
		if not is_finite(float(config[k])):config[k]=DEFAULTS[k]
	config.radius=clampf(float(config.radius),8,44);config.height=clampf(float(config.height),20,84)
	config.layers=clampi(int(config.layers),3,9);config.turns_per_second=clampf(float(config.turns_per_second),0.2,5)
	config.arc_degrees=clampf(float(config.arc_degrees),90,300);config.width=clampf(float(config.width),1,3)
	config.leaves=clampi(int(config.leaves),0,24);config.enter=clampf(float(config.enter),0.05,1)
	config.sustain=clampf(float(config.sustain),0.05,30);config.exit=clampf(float(config.exit),0.08,1)
	for k in ["core","body","edge","leaf"]:
		if not Color.html_is_valid(str(config[k])):config[k]=DEFAULTS[k]
	duration=config.enter+config.sustain+config.exit
func play(at:Vector2,overrides:Dictionary={}) -> void:
	configure(overrides);center=at;age=0;active=true;exiting=false;exit_age=0;queue_redraw()
func strength() -> float:
	if not active:return 0
	if exiting:return exit_start*(1.0-smoothstep(0,config.exit,exit_age))
	return smoothstep(0,config.enter,age)*(1.0-smoothstep(duration-config.exit,duration,age))
func stop() -> void:
	if active and not exiting:exit_start=strength();exiting=true;exit_age=0
func clear() -> void:
	active=false;age=0;exiting=false;queue_redraw()
func tick(dt:float) -> void:
	if not active or not is_finite(dt) or dt<=0:return
	age+=dt
	if exiting:exit_age+=dt
	if age>=duration or (exiting and exit_age>=config.exit):
		active=false;queue_redraw();finished.emit();return
	queue_redraw()
func _process(dt:float) -> void:
	if automatic:tick(dt)
func point_at(level:float,angle:float,envelope:float) -> Vector2:
	var r:float=lerpf(4,config.radius,pow(level,0.78))*envelope
	return center+Vector2(cos(angle)*r, -level*config.height*envelope+sin(angle)*r*0.28)
# Stable indexed variation: never reseeded by frame rate or redraw order.
func variation(index:int, channel:int) -> float:
	return fposmod(sin(float(index*127+channel*311+int(config.seed)*17))*43758.5453,1.0)
func ribbon_state(index:int) -> Dictionary:
	var secondary:=index>=int(config.layers)
	var k:=index%int(config.layers)
	var base:float=(float(k)+0.25+variation(index,1)*0.5)/float(config.layers)
	var phase:float=variation(index,2)*TAU
	var speed:float=config.turns_per_second*lerpf(0.65,1.3,variation(index,3))
	var direction:=1.0 if bool(config.clockwise) else -1.0
	return {"level":clampf(base+sin(age*2.2+phase)*0.055,0.04,0.94),
		"start":phase+age*TAU*speed*direction,
		"span":deg_to_rad(config.arc_degrees)*lerpf(0.25 if secondary else 0.6,0.55 if secondary else 1.0,variation(index,4)),
		"slope":lerpf(0.08,0.22,variation(index,5))*direction,
		"radius":lerpf(0.88,1.04,variation(index,6)),"secondary":secondary}
func ribbon_point(state:Dictionary,t:float,envelope:float) -> Vector2:
	var level:float=clampf(state.level+(t-0.5)*state.slope,0.02,1.0)
	var a:float=state.start+t*state.span
	var p:=point_at(level,a,envelope)
	p.x=center.x+(p.x-center.x)*state.radius
	# The whole vortex leans gently; no repeated sinusoidal waves along a stroke.
	p.x+=sin(age*3.0+level*2.1)*level*2.0*envelope
	return p.round()
func _draw() -> void:
	var envelope:=strength()
	if envelope<=0.001:return
	var direction:=1.0 if bool(config.clockwise) else -1.0
	for front in [false,true]:
		for index in range(int(config.layers)*2):
			var state:=ribbon_state(index)
			for j in range(48):
				var t:=float(j)/48.0
				var a:float=state.start+t*state.span
				if (sin(a)>0)!=front:continue
				var taper:float=pow(sin(PI*(t+0.5/48.0)),0.7)
				# Short secondary wisps are thin; primaries have irregular bright shoulders.
				var w:float=maxf(1,round(config.width*taper*envelope*(0.55 if state.secondary else 1.0)))
				var color:=Color(config.body if front else config.edge)
				if front and not state.secondary and taper>0.67 and sin(a)>0.45:color=Color(config.core)
				draw_line(ribbon_point(state,t,envelope),ribbon_point(state,t+1.0/48.0,envelope),color,w,false)
		# Sparse independent splinters follow the same volume; not an equidistant ring.
		for i in range(int(config.layers)*2):
			var u:float=fposmod(age*lerpf(0.4,0.8,variation(i,12))+variation(i,13),1.0)
			var a:float=age*config.turns_per_second*TAU*direction*lerpf(0.7,1.25,variation(i,14))+variation(i,15)*TAU
			if (sin(a)>0)!=front or u<0.08 or u>0.91:continue
			var p:=point_at(u,a,envelope).round()
			var q:=point_at(u+0.014,a+0.06,envelope).round()
			draw_line(p,q,Color(config.body if front else config.edge),1,false)
		for i in range(config.leaves):
			var u:float=fposmod(age*lerpf(0.45,0.8,variation(i,20))+variation(i,21),1.0)
			var a:float=age*TAU*config.turns_per_second*direction*lerpf(0.75,1.2,variation(i,22))+variation(i,23)*TAU+u*3.4
			if (sin(a)>0)!=front:continue
			var p:=point_at(u,a,envelope).round()
			var visibility:float=smoothstep(0,0.12,u)*(1-smoothstep(0.82,1,u))*envelope
			if visibility<0.2:continue
			draw_line(p,p+Vector2(2,-1 if cos(a)>0 else 1),Color(config.leaf if front else config.edge),1,false)
