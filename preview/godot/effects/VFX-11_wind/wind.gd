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
func _draw() -> void:
	var envelope:=strength()
	if envelope<=0.001:return
	var sign_dir:=1.0 if bool(config.clockwise) else -1.0
	var phase:float=age*TAU*config.turns_per_second*sign_dir
	var seed_phase:float=fposmod(float(config.seed)*0.6180339,1.0)*TAU
	# Back half first, front half last: front ribbons sweep visibly across the funnel.
	for front in [false,true]:
		for layer in range(config.layers):
			var level:float=float(layer)/float(config.layers-1)
			var start:float=phase+layer*0.78+seed_phase
			var span:float=deg_to_rad(config.arc_degrees)*envelope
			for j in range(56):
				var t:float=float(j)/56.0
				var a:float=start+t*span
				if (sin(a)>0)!=front:continue
				var p:=point_at(level,a,envelope).round()
				var q:=point_at(level,a+span/56.0,envelope).round()
				var taper:float=pow(sin(PI*(t+0.5/56.0)),0.7)
				var w:float=maxf(1.0,round(config.width*taper*envelope))
				var color:=Color(config.body if front else config.edge)
				if front and taper>0.72 and sin(a)>0.72:color=Color(config.core)
				draw_line(p,q,color,w,false)
		# Leaves stay on analytic rising helices, not random jitter each frame.
		for i in range(config.leaves):
			var u:float=fposmod(age*0.65+float(i)/maxi(1,config.leaves),1.0)
			var a:float=phase+i*2.399+seed_phase+u*3.4
			if (sin(a)>0)!=front:continue
			var p:=point_at(u,a,envelope).round()
			var visibility:float=smoothstep(0,0.12,u)*(1-smoothstep(0.82,1,u))*envelope
			if visibility<0.2:continue
			var leaf:=Color(config.leaf if front else config.edge)
			draw_line(p,p+Vector2(2, -1 if cos(a)>0 else 1),leaf,1,false)
