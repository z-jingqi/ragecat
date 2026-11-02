extends Node2D
# Single strike. Geometry is frozen at trigger time; no per-frame random noise.
const DEFAULTS = preload("res://effects/VFX-08_lightning/defaults.gd")
var config: Dictionary = {}
var points := PackedVector2Array()
var forks: Array = []
var age := 0.0
var active := false
var paused := false
var start := Vector2.ZERO
var target := Vector2.ZERO
var duration := 0.18
var automatic := true

func number(value: Variant, fallback: float, low: float, high: float) -> float:
	if not (value is float or value is int): return fallback
	var f:=float(value)
	return clampf(f,low,high) if is_finite(f) else fallback
func clean(values: Dictionary) -> Dictionary:
	var c:Dictionary=DEFAULTS.DATA.duplicate(true)
	var ranges:={"width":Vector2(1,6),"segment_length":Vector2(5,24),"jitter":Vector2(0,20),"branches":Vector2(0,4),"branch_length":Vector2(4,36),"attack":Vector2(0.008,0.08),"hold":Vector2(0.008,0.12),"decay":Vector2(0.03,0.25),"seed":Vector2(0,65535)}
	for key in ranges:
		c[key]=number(values.get(key,c[key]),float(c[key]),ranges[key].x,ranges[key].y)
	for key in ["branches","seed"]: c[key]=int(c[key])
	for key in ["core","body","edge"]:
		var v:Variant=values.get(key,c[key])
		c[key]=Color.from_string(v,Color(c[key])) if v is String else (v if v is Color else Color(c[key]))
		c[key].a=1.0
	return c
func play(origin: Vector2, endpoint: Vector2, values: Dictionary={}) -> void:
	clear()
	config=clean(values)
	start=origin if origin.is_finite() else Vector2.ZERO
	target=endpoint if endpoint.is_finite() else start
	var delta:=target-start
	if delta.length()>2048: target=start+delta.normalized()*2048;delta=target-start
	duration=config.attack+config.hold+config.decay
	if delta.length()<1: return
	var length:=delta.length()
	var axis:=delta/length
	var side:=Vector2(-axis.y,axis.x)
	var count:=clampi(int(ceil(length/config.segment_length)),2,64)
	var rng:=RandomNumberGenerator.new();rng.seed=config.seed
	points.append(start)
	var sign_value:=1.0 if rng.randf()>0.5 else -1.0
	for i in range(1,count):
		var t:=float(i)/count
		var offset:float=sign_value*rng.randf_range(0.35,1.0)*minf(config.jitter,length*0.18)*sin(PI*t)
		points.append(start+axis*length*(t+rng.randf_range(-0.15,0.15)/count)+side*offset)
		sign_value=-sign_value
	points.append(target)
	for j in range(config.branches):
		var idx:=clampi(int(round(float(j+1)*count/(config.branches+1))),1,count-1)
		var root:Vector2=points[idx]
		var s:=1.0 if j%2==0 else -1.0
		var dist:float=config.branch_length*rng.randf_range(0.65,1)
		var tip:=root+axis*dist*0.55+side*s*dist*0.8
		var elbow:=root.lerp(tip,0.53)-axis*dist*0.2
		forks.append({"points":PackedVector2Array([root,elbow,tip]),"at":float(idx)/count})
	active=true
	queue_redraw()
func play_direction(origin: Vector2, direction: Vector2, length: float, values: Dictionary={}) -> void:
	var axis:=direction.normalized() if direction.is_finite() and direction.length_squared()>0.0001 else Vector2.DOWN
	play(origin,origin+axis*number(length,90,1,2048),values)
func replay() -> void: play(start,target,config)
func clear() -> void:
	active=false;age=0;points.clear();forks.clear();queue_redraw()
func tick(delta: float) -> void:
	if paused or not active or not is_finite(delta) or delta<=0:return
	age=minf(age+delta,duration)
	if age>=duration-0.000001:active=false;points.clear();forks.clear()
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
func _draw() -> void:
	if not active:return
	var state:=phase();var power:float=state.strength;var reach:float=state.reach
	var trim:=maxf(0,(0.45-power)/0.45)*0.85
	var width:float=maxf(1,config.width*(0.35+0.65*power))
	for branch in forks:
		if power<0.4 or reach<branch.at:continue
		stroke(branch.points,config.edge,maxf(1,width-1),minf(1,(reach-branch.at)*3))
	stroke(points,config.edge,width+2,reach,trim)
	stroke(points,config.body if power>0.3 else config.edge,width,reach,trim)
	if power>0.55:stroke(points,config.core,maxf(1,width-2),reach,trim)
	if reach>=1 and power>0.45:
		var q:=target.floor()
		var radius:=roundf(2+3*power)
		draw_line(q+Vector2(-radius,0),q+Vector2(radius,0),config.body,1,false)
		draw_line(q+Vector2(0,-radius),q+Vector2(0,1),config.core,1,false)
