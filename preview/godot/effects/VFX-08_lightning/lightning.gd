extends Node2D
# Single strike. Geometry is frozen at trigger time; no per-frame random noise.
const DEFAULTS = preload("res://effects/VFX-08_lightning/defaults.gd")
var config: Dictionary = {}
var points := PackedVector2Array()
var forks: Array = []
var widths := PackedFloat32Array()
var sparks: Array = []
var smoke_seeds: Array = []
var axis := Vector2.DOWN
var side := Vector2.RIGHT
var age := 0.0
var active := false
var paused := false
var start := Vector2.ZERO
var target := Vector2.ZERO
var duration := 0.55
var automatic := true

func number(value: Variant, fallback: float, low: float, high: float) -> float:
	if not (value is float or value is int): return fallback
	var f:=float(value)
	return clampf(f,low,high) if is_finite(f) else fallback
func clean(values: Dictionary) -> Dictionary:
	var c:Dictionary=DEFAULTS.DATA.duplicate(true)
	var ranges:={"width":Vector2(1,6),"segment_length":Vector2(5,24),"jitter":Vector2(0,20),"branches":Vector2(0,4),"branch_length":Vector2(4,64),"afterglow":Vector2(0,0.6),"impact_size":Vector2(0,28),"spark_count":Vector2(0,12),"attack":Vector2(0.008,0.08),"hold":Vector2(0.008,0.12),"decay":Vector2(0.03,0.25),"seed":Vector2(0,65535)}
	for key in ranges:
		c[key]=number(values.get(key,c[key]),float(c[key]),ranges[key].x,ranges[key].y)
	c.smoke=values.get("smoke",c.smoke)==true
	for key in ["branches","seed","spark_count"]: c[key]=int(c[key])
	for key in ["core","body","edge","ember","smoke_color"]:
		var v:Variant=values.get(key,c[key])
		c[key]=Color.from_string(v,Color(c[key])) if v is String else (v if v is Color else Color(c[key]))
		var color:Color=c[key]
		if not (is_finite(color.r) and is_finite(color.g) and is_finite(color.b)):color=Color(DEFAULTS.DATA[key])
		c[key]=Color(clampf(color.r,0,1),clampf(color.g,0,1),clampf(color.b,0,1),1)
	return c
func play(origin: Vector2, endpoint: Vector2, values: Dictionary={}) -> void:
	clear()
	config=clean(values)
	start=origin if origin.is_finite() else Vector2.ZERO
	target=endpoint if endpoint.is_finite() else start
	var delta:=target-start
	if delta.length()>2048: target=start+delta.normalized()*2048;delta=target-start
	duration=config.attack+config.hold+config.decay+config.afterglow
	if delta.length()<1: return
	var length:=delta.length()
	axis=delta/length
	side=Vector2(-axis.y,axis.x)
	var count:=clampi(int(ceil(length/config.segment_length)),2,64)
	var rng:=RandomNumberGenerator.new();rng.seed=config.seed
	points.append(start)
	# Correlated uneven displacement: long kinks plus short teeth, not a sine zigzag.
	var wander:=0.0
	for i in range(1,count):
		var t:=float(i)/count
		wander=clampf(wander*0.45+rng.randf_range(-1,1),-1,1)
		var offset:float=wander*minf(config.jitter,length*0.18)*sin(PI*t)
		points.append(start+axis*length*(t+rng.randf_range(-0.26,0.26)/count)+side*offset)
	points.append(target)
	for i in range(count):widths.append(rng.randf_range(0.65,1.35)*(1.0-float(i)/count*0.3))
	for j in range(config.branches):
		var idx:=clampi(int(round(float(j+1)*count/(config.branches+2))),1,count-1)
		var root:Vector2=points[idx]
		var sign_value:=1.0 if j%2==0 else -1.0
		var dist:float=minf(config.branch_length*rng.randf_range(0.6,1.15),length*(0.9-float(idx)/count))
		var branch:=PackedVector2Array([root])
		var steps:=clampi(int(dist/6),3,9)
		for k in range(1,steps+1):
			var t:=float(k)/steps
			var bend:=t*dist*(0.25+0.13*sin(t*2))*sign_value
			branch.append(root+axis*dist*t+side*(bend+rng.randf_range(-4.0,4.0)))
		forks.append({"points":branch,"at":float(idx)/count})
	for j in range(config.spark_count):
		sparks.append({"lateral":rng.randf_range(-65,65),"lift":rng.randf_range(25,62),"delay":rng.randf_range(0,0.045),"life":rng.randf_range(0.15,0.32),"size":rng.randf_range(1,2)})
	for j in range(4):
		smoke_seeds.append({"x":rng.randf_range(-7,7),"rise":rng.randf_range(18,35),"size":rng.randf_range(3,5),"delay":j*0.028})
	active=true
	queue_redraw()
func play_direction(origin: Vector2, direction: Vector2, length: float, values: Dictionary={}) -> void:
	var axis:=direction.normalized() if direction.is_finite() and direction.length_squared()>0.0001 else Vector2.DOWN
	play(origin,origin+axis*number(length,90,1,2048),values)
func replay() -> void: play(start,target,config)
func clear() -> void:
	active=false;age=0;points.clear();forks.clear();widths.clear();sparks.clear();smoke_seeds.clear();queue_redraw()
func tick(delta: float) -> void:
	if paused or not active or not is_finite(delta) or delta<=0:return
	age=minf(age+delta,duration)
	if age>=duration-0.000001:active=false;points.clear();forks.clear();widths.clear();sparks.clear();smoke_seeds.clear()
	queue_redraw()
func _process(delta: float) -> void:
	if automatic:tick(delta)
func phase() -> Dictionary:
	if not active:return {"reach":0.0,"strength":0.0}
	return {"reach":minf(age/config.attack,1.0),"strength":1.0 if age<config.attack+config.hold else maxf(0,1-(age-config.attack-config.hold)/config.decay)}
func stroke(path: PackedVector2Array, color: Color, width: float, reach: float=1.0, trim: float=0.0) -> void:
	for i in range(path.size()-1):
		var lo:=float(i)/(path.size()-1);var hi:=float(i+1)/(path.size()-1)
		if reach<=lo or trim>=hi:continue
		var a:=path[i].lerp(path[i+1],clampf((trim-lo)/(hi-lo),0,1)).floor()+Vector2(0.5,0.5)
		var b:=path[i].lerp(path[i+1],clampf((reach-lo)/(hi-lo),0,1)).floor()+Vector2(0.5,0.5)
		draw_line(a,b,color,maxf(1,round(width)),false)
func ellipse(center:Vector2,rx:float,ry:float,color:Color,irregular:float=0.0) -> void:
	if rx<0.5 or ry<0.5:return
	var polygon:=PackedVector2Array()
	for k in range(16):
		var a:=TAU*k/16.0
		var rough:=1.0+irregular*sin(k*2.7+config.seed)
		var q:Vector2=(center+side*cos(a)*rx*rough+axis*sin(a)*ry*rough).round()
		if not polygon.has(q):polygon.append(q)
	var area:=0.0
	for i in range(polygon.size()):area+=polygon[i].cross(polygon[(i+1)%polygon.size()])
	if polygon.size()>=3 and absf(area)>1:draw_colored_polygon(polygon,color)
func draw_impact() -> void:
	var t:float=age-config.attack
	if t<0 or config.impact_size<=0:return
	var radius:float=config.impact_size
	# Local ground flare, followed by warm residue and a broken outgoing arc.
	var heat:=clampf(1-t/0.25,0,1)
	if heat>0:
		ellipse(target,radius*(0.8+0.3*(1-heat)),3.5,config.edge.darkened(0.3),0.12)
		ellipse(target,radius*0.68*heat,2.5,config.ember,0.16)
	if t<0.065:
		var pop:=1-t/0.065
		ellipse(target,radius*(0.75+0.25*pop),4.0+pop*2,config.body,0.12)
		ellipse(target,radius*0.78,3.5,config.core,0.09)
	if t>0.03 and t<0.16:
		var spread:=radius*(0.8+(t-0.03)*4.0)
		for sign_value in [-1,1]:
			var arc:=PackedVector2Array()
			for k in range(5):
				var a:=float(k)/4*1.3-0.65
				arc.append(target+side*sign_value*cos(a)*spread+axis*sin(a)*spread*0.24)
			stroke(arc,config.body,1)
	for particle in sparks:
		var life:float=t-particle.delay
		if life<0 or life>=particle.life:continue
		var lateral:float=particle.lateral*life
		var h:float=maxf(0,particle.lift*life-100*life*life)
		var p:Vector2=target+side*lateral-axis*h
		var direction:Vector2=(side*particle.lateral-axis*(particle.lift-200*life)).normalized()
		var color:Color=config.core if life<0.06 else (config.ember if life<0.18 else config.edge)
		stroke(PackedVector2Array([p,p-direction*(3.0-2.0*life/particle.life)]),color,particle.size)
	if config.smoke:
		for puff in smoke_seeds:
			var life:float=t-0.08-puff.delay
			if life<0 or life>=0.34:continue
			var p:Vector2=target+side*(puff.x+sin(life*9+puff.x)*2)-axis*(3+puff.rise*life)
			var opacity:=0.6 if life<0.12 else (0.4 if life<0.23 else 0.2)
			var color:Color=config.smoke_color;color.a=opacity
			ellipse(p,puff.size*(1+life*2),puff.size*(1+life*2.6),color,0.18)
func _draw() -> void:
	if not active:return
	var state:=phase();var power:float=state.strength;var reach:float=state.reach
	# Smoke is behind the electrical strike; no bloom or screen-sized flash.
	draw_impact()
	if power<=0:return
	var trim:=maxf(0,(0.3-power)/0.3)*0.75
	for branch in forks:
		if power<0.25 or reach<branch.at:continue
		stroke(branch.points,config.edge,2,minf(1,(reach-branch.at)*3))
		if power>0.45:stroke(branch.points,config.body,1,minf(1,(reach-branch.at)*3))
	for layer in range(3):
		if layer==2 and power<0.4:continue
		for i in range(points.size()-1):
			var lo:=float(i)/(points.size()-1);var hi:=float(i+1)/(points.size()-1)
			if reach<=lo or trim>=hi:continue
			var segment:=PackedVector2Array([points[i],points[i+1]])
			var w:float=maxf(1,config.width*widths[i]*(0.3+0.7*power))
			var color:Color=config.edge if layer==0 else (config.body if layer==1 else config.core)
			w=w+2 if layer==0 else (w if layer==1 else maxf(1,w-1.5))
			stroke(segment,color,w,clampf((reach-lo)/(hi-lo),0,1),clampf((trim-lo)/(hi-lo),0,1))
