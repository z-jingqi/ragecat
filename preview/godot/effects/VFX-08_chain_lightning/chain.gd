extends Node2D
## Bounded nearest-unvisited chain. Owns visuals, never modifies target health.
signal target_hit(target: Node2D, jump_index: int)
signal finished
const Bolt = preload("res://effects/VFX-08_lightning/lightning.gd")
const DEFAULTS = {"max_targets":5,"jump_range":72.0,"jump_interval":0.09,"width":1.25,"branches":1,"jitter":7.0,"seed":31,"core":"f7f3dc","body":"a4e5ef","edge":"477aaf","attack":0.065,"hold":0.025,"decay":0.18}
var config:Dictionary={}
var active:=false
var automatic:=true
var paused:=false
var age:=0.0
var next_jump:=0.0
var source:=Vector2.ZERO
var previous:WeakRef
var candidates:Array=[]
var visited:Array[int]=[]
var links:Array=[]
var launched:=0
var exhausted:=false
var generation:=0
func number(v:Variant,d:float,lo:float,hi:float)->float:
	return clampf(float(v),lo,hi) if (v is int or v is float) and is_finite(float(v)) else d
func clean(values:Dictionary)->Dictionary:
	var c:=DEFAULTS.duplicate(true)
	var ranges:={"max_targets":Vector2(1,12),"jump_range":Vector2(1,512),"jump_interval":Vector2(0.04,0.4),"width":Vector2(1,3),"branches":Vector2(0,3),"jitter":Vector2(0,20),"seed":Vector2(0,65535),"attack":Vector2(0.025,0.08),"hold":Vector2(0.008,0.12),"decay":Vector2(0.03,0.25)}
	for key in ranges:c[key]=number(values.get(key,c[key]),c[key],ranges[key].x,ranges[key].y)
	for key in ["max_targets","branches","seed"]:c[key]=int(c[key])
	for key in ["core","body","edge"]:
		var v:Variant=values.get(key,c[key]);var color:Color=Color.from_string(v,Color(c[key])) if v is String else (v if v is Color else Color(c[key]))
		c[key]=Color(color.r,color.g,color.b,1) if is_finite(color.r) and is_finite(color.g) and is_finite(color.b) else Color(DEFAULTS[key])
	return c
func clear()->void:
	generation+=1;active=false;age=0;launched=0;next_jump=0;exhausted=false;previous=null;candidates.clear();visited.clear()
	for link in links:link.bolt.free()
	links.clear();queue_redraw()
func play(origin:Vector2,targets:Array,values:Dictionary={})->void:
	clear();config=clean(values);source=origin if origin.is_finite() else Vector2.ZERO
	var ids:Array[int]=[]
	for target in targets:
		if is_instance_valid(target) and target is Node2D and not target.is_queued_for_deletion() and not ids.has(target.get_instance_id()):
			ids.append(target.get_instance_id());candidates.append(weakref(target))
		if candidates.size()>=128:break
	active=true;launch_next()
func valid(ref:WeakRef)->Node2D:
	if ref==null:return null
	var value=ref.get_ref()
	return value if is_instance_valid(value) and value is Node2D and not value.is_queued_for_deletion() and value.global_position.is_finite() else null
func local_target(target:Node2D)->Vector2:return to_local(target.global_position)
func launch_next()->void:
	if launched>=config.max_targets:exhausted=true;return
	var p:=valid(previous)
	if p!=null:source=local_target(p)
	var chosen:Node2D=null;var best:float=config.jump_range+0.0001
	for ref in candidates:
		var item:=valid(ref)
		if item==null or visited.has(item.get_instance_id()):continue
		var dist:=source.distance_to(local_target(item))
		if dist>=1 and dist<best:best=dist;chosen=item
	if chosen==null:exhausted=true;return
	var end:=local_target(chosen);var opts:=config.duplicate(true)
	opts.merge({"impact_size":0,"afterglow":0,"spark_count":0,"smoke":false,"branch_length":17,"segment_length":6,"seed":config.seed+launched*97},true)
	var bolt:=Bolt.new();bolt.automatic=false;add_child(bolt);bolt.play(source,end,opts)
	var shapes:Array=[]
	for branch in bolt.forks:shapes.append(branch.points.duplicate())
	links.append({"bolt":bolt,"from":previous,"to":weakref(chosen),"start":source,"end":end,"base":bolt.points.duplicate(),"forks":shapes,"hit":false,"index":launched})
	visited.append(chosen.get_instance_id());previous=weakref(chosen);source=end;launched+=1;next_jump=launched*maxf(config.jump_interval,config.attack)
func map_point(p:Vector2,old_a:Vector2,old_b:Vector2,new_a:Vector2,new_b:Vector2)->Vector2:
	var old_axis:Vector2=(old_b-old_a).normalized();var delta:=new_b-new_a;var axis:=delta.normalized() if delta.length()>0.001 else old_axis
	var q:=p-old_a
	return new_a+axis*(q.dot(old_axis)*delta.length()/maxf(old_a.distance_to(old_b),1))+Vector2(-axis.y,axis.x)*q.dot(Vector2(-old_axis.y,old_axis.x))
func update_links(dt:float)->bool:
	var token:=generation
	for link in links.duplicate():
		var bolt:Node2D=link.bolt;var a:=valid(link.from);var b:=valid(link.to)
		if b==null:bolt.clear();continue
		var from:Vector2=local_target(a) if a!=null else link.start
		var end:=local_target(b)
		# Morph frozen random geometry to moving anchors, never regenerate per frame.
		if bolt.active:
			for j in range(bolt.points.size()):bolt.points[j]=map_point(link.base[j],link.start,link.end,from,end)
			for j in range(bolt.forks.size()):
				for k in range(bolt.forks[j].points.size()):bolt.forks[j].points[k]=map_point(link.forks[j][k],link.start,link.end,from,end)
			bolt.tick(dt)
		if not link.hit and bolt.age>=config.attack-0.000001:
			link.hit=true;target_hit.emit(b,link.index)
			if token!=generation:return false
	for i in range(links.size()-1,-1,-1):
		if not links[i].bolt.active:links[i].bolt.free();links.remove_at(i)
	return true
func tick(dt:float)->void:
	if not active or paused or not is_finite(dt) or dt<=0:return
	queue_redraw()
	var end:=age+dt;var guard:=0
	while active and age<end-0.0000001 and guard<32:
		guard+=1
		var boundary:=end if exhausted else minf(end,next_jump)
		# Hit callbacks coincide with tip arrival even when a frame crosses that instant.
		for link in links:
			if not link.hit and link.bolt.active:
				var remaining:float=config.attack-link.bolt.age
				if remaining>0.000001:boundary=minf(boundary,age+remaining)
		var step:=maxf(0,boundary-age)
		if not update_links(step):return
		age=boundary
		if not exhausted and age>=next_jump-0.0000001:launch_next()
		if exhausted and links.is_empty():active=false;finished.emit();return
func _process(dt:float)->void:
	if automatic:tick(dt)
func _draw()->void:
	for link in links:
		var target:=valid(link.to)
		if target==null or not link.hit:continue
		var t:float=link.bolt.age-config.attack
		if t<0 or t>=0.1:continue
		var p:=local_target(target).round();var rng:=RandomNumberGenerator.new();rng.seed=config.seed+link.index*53
		for i in range(4):
			var axis:=Vector2.from_angle(i*TAU/4+rng.randf_range(-0.3,0.3))
			var r:=4+t*34;var a:Vector2=(p+axis*r).round()+Vector2(0.5,0.5);var b:Vector2=(p+axis*(r+3*(1-t/0.1))).round()+Vector2(0.5,0.5)
			draw_line(a,b,config.core if t<0.04 else config.body,1,false)
