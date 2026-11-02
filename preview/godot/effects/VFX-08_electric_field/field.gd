extends Node2D
# Gameplay cadence is independent of decorative arc cadence.
signal target_tick(target: Node2D, tick_id: int, scheduled_time: float)
signal completed
const DEFAULTS={"radius":42.0,"duration":3.0,"tick_interval":0.5,"arc_interval":0.10,"arc_life":0.30,"density":3,"width":1.2,"seed":81,"boundary":true,"core":"f4f0e5","body":"c1b8ef","edge":"6a6098"}
var config:Dictionary=DEFAULTS.duplicate()
var targets:Array[WeakRef]=[]
var age:=0.0
var active:=false
var draining:=false
var paused:=false
var automatic:=true
var next_tick:=1
var generation:=0
var arcs:Array=[]
func num(v:Variant,f:float,lo:float,hi:float)->float:
 if not (v is int or v is float):return f
 return clampf(float(v),lo,hi) if is_finite(v) else f
func configure(values:Dictionary)->void:
 config=DEFAULTS.duplicate()
 var ranges={"radius":Vector2(8,90),"duration":Vector2(0.1,30),"tick_interval":Vector2(0.05,5),"arc_interval":Vector2(0.05,0.5),"arc_life":Vector2(0.06,0.3),"density":Vector2(1,5),"width":Vector2(1,2),"seed":Vector2(0,65535)}
 for k in ranges:config[k]=num(values.get(k,config[k]),config[k],ranges[k].x,ranges[k].y)
 config.density=int(config.density);config.seed=int(config.seed)
 config.boundary=values.get("boundary",true)==true
 for k in ["core","body","edge"]:
  var v=values.get(k,config[k]);var color:Color=Color.from_string(v,Color(DEFAULTS[k])) if v is String else (v if v is Color else Color(DEFAULTS[k]))
  if not(color.r>=0 and color.r<=1 and color.g>=0 and color.g<=1 and color.b>=0 and color.b<=1):color=Color(DEFAULTS[k])
  color.a=1;config[k]=color
func play(center:Vector2,candidates:Array,values:Dictionary={})->void:
 stop();configure(values);global_position=center if center.is_finite() else Vector2.ZERO
 set_candidates(candidates)
 active=true;age=0;next_tick=1;build_arcs();queue_redraw()
func set_candidates(candidates:Array)->void:
 # Replacing candidates does not restart time or repeat a delivered tick.
 targets.clear();var seen:Dictionary={}
 for t in candidates:
  if is_instance_valid(t) and t is Node2D and not seen.has(t.get_instance_id()):
   targets.append(weakref(t));seen[t.get_instance_id()]=true
   if targets.size()==64:break
func stop()->void:
 generation+=1;active=false;draining=false;age=0;arcs.clear();targets.clear();next_tick=1;queue_redraw()
func tick(dt:float)->void:
 if (not active and not draining) or paused or not is_finite(dt) or dt<=0:return
 if draining:
  age+=dt;build_arcs()
  if age>=config.duration+visual_lifetime():draining=false;arcs.clear()
  queue_redraw();return
 var token:=generation
 age=minf(age+dt,config.duration)
 # Tick1 occurs after the first interval, with inclusive final tick at duration.
 while next_tick*config.tick_interval<=age+0.000001:
  var id:=next_tick;next_tick+=1
  for ref in targets.duplicate():
   var t=ref.get_ref()
   if is_instance_valid(t) and t is Node2D and t.is_inside_tree() and t.global_position.is_finite() and t.global_position.distance_squared_to(global_position)<=config.radius*config.radius+0.0001:
    target_tick.emit(t,id,id*config.tick_interval)
    if generation!=token or not active:return
 if age>=config.duration-0.000001:
  active=false;draining=true;targets.clear();build_arcs();queue_redraw();completed.emit();return
 build_arcs();queue_redraw()
func _process(dt:float)->void:
 if automatic:tick(dt)
func visual_lifetime()->float:
 # Keep generations overlapping even for sparse user-configured cadence.
 return maxf(config.arc_life,config.arc_interval*1.4)
func build_arcs()->void:
 arcs.clear()
 var latest:=int(floor(age/config.arc_interval))
 var lifetime:=visual_lifetime()
 var span:=int(ceil(lifetime/config.arc_interval))
 for slot in range(maxi(0,latest-span),latest+1):
  for j in range(config.density):
   var start:float=slot*config.arc_interval+j*config.arc_interval/config.density
   var life:=age-start
   if start>=config.duration-0.000001 or life<0 or life>=lifetime:continue
   var rng:=RandomNumberGenerator.new();rng.seed=config.seed+slot*7919+j*104729
   var a:=rng.randf()*TAU;var b:=a+rng.randf_range(0.65,2.7)
   var r:float=config.radius*rng.randf_range(0.35,0.92)
   var p:=Vector2.from_angle(a)*r;var q:Vector2=Vector2.from_angle(b)*config.radius*rng.randf_range(0.35,0.92)
   var path:=PackedVector2Array([p]);var side:Vector2=(q-p).normalized().orthogonal();var wander:=0.0
   for i in range(1,7):
    var u:=i/7.0;wander=clampf(wander*0.45+rng.randf_range(-1,1),-1,1)
    var v:Vector2=p.lerp(q,u)+side*wander*7*sin(PI*u)
    if v.length()>config.radius-1:v=v.normalized()*(config.radius-1)
    path.append(v.round())
   path.append(q.round())
   var fork:=PackedVector2Array([path[3],(path[3]+side*rng.randf_range(5,10)).round(),(path[3]+side*rng.randf_range(12,17)+(q-p).normalized()*4).round()])
   for i in range(fork.size()):
    if fork[i].length()>config.radius-1:fork[i]=fork[i].normalized()*(config.radius-1)
   arcs.append({"points":path,"fork":fork,"life":life/lifetime,"widths":[rng.randf_range(0.65,1.3),rng.randf_range(0.65,1.3),rng.randf_range(0.65,1.3),rng.randf_range(0.65,1.3),rng.randf_range(0.65,1.3),rng.randf_range(0.65,1.3),rng.randf_range(0.65,1.3)],"spark":q.round()})
func pixel_line(a:Vector2,b:Vector2,color:Color,width:int=1)->void:
 var steps:=maxi(1,int(ceil(maxf(absf(b.x-a.x),absf(b.y-a.y)))))
 for i in range(steps+1):
  var p:=a.lerp(b,float(i)/steps).round();draw_rect(Rect2(p-Vector2.ONE*floor(width/2.0),Vector2.ONE*width),color)
func stroke(path:PackedVector2Array,color:Color,width:int,skip:int=0)->void:
 for i in range(skip,path.size()-1):pixel_line(path[i],path[i+1],color,width)
func visible_segment(arc:Dictionary,index:int)->Vector2:
 # Per-segment window: growing leader, full contact, then uneven shrinking remnants.
 var life:float=arc.life
 var head:=clampf(life/0.24,0,1)*7
 var end:=clampf(head-index,0,1)
 var release:=0.51+float((index*3+2)%7)*0.035
 var erosion:=clampf((life-release)/(0.96-release),0,1)
 if end<=0 or erosion>=1:return Vector2.ZERO
 return Vector2(erosion*0.55,maxf(erosion*0.55,end-erosion*0.45))
func _draw()->void:
 if not active and not draining:return
 if config.boundary:
  var fade:=clampf((age-config.duration)/visual_lifetime(),0,1) if draining else 0.0
  # Contour fragments retract individually during the harmless visual tail.
  for i in range(32):
   if fade>float((i*13)%32+1)/32:continue
   var a:=TAU*i/32.0;var b:=a+TAU/32*0.6*(1-fade)
   pixel_line(Vector2.from_angle(a)*config.radius,Vector2.from_angle(b)*config.radius,config.edge.darkened(0.25))
  for i in range(8):
   if fade>float(i+1)/8:continue
   var p:Vector2=Vector2.from_angle(TAU*i/8)*config.radius*0.72
   draw_rect(Rect2(p.round(),Vector2(2,1)),config.edge.darkened(0.35))
 for arc in arcs:
  var life:float=arc.life
  for i in range(7):
   var window:=visible_segment(arc,i)
   if window.y<=window.x:continue
   var w:=clampi(int(round(config.width*arc.widths[i]*(1.0-i*0.035))),1,2)
   if life>0.40:w=1
   var color:Color=config.body if life<0.53 else config.edge
   if life>=0.13 and life<0.29 and i%3==1:color=config.core
   pixel_line(arc.points[i].lerp(arc.points[i+1],window.x),arc.points[i].lerp(arc.points[i+1],window.y),color,w)
  # Forks start only after the leader reaches their junction, then retract first.
  var fork_head:=clampf((life-0.13)/0.18,0,1)*2
  var fork_tail:=clampf((life-0.43)/0.32,0,1)*2
  for i in range(2):
   var start:=clampf(fork_tail-i,0,1);var end:=clampf(fork_head-i,0,1)
   if end>start:pixel_line(arc.fork[i].lerp(arc.fork[i+1],start),arc.fork[i].lerp(arc.fork[i+1],end),config.body if life<0.4 else config.edge)
  # Endpoint sparks appear on arrival, move outward, cool and shrink.
  var spark_age:float=(life-0.24)/0.65
  if spark_age>=0 and spark_age<1:
   var p:Vector2=arc.spark;var offset:float=spark_age*5
   var color:Color=config.body if spark_age<0.35 else config.edge
   pixel_line(p+Vector2(offset,-offset),p+Vector2(offset+1-spark_age,-offset-2*(1-spark_age)),color)
   if spark_age<0.65:draw_rect(Rect2(p+Vector2(-offset,offset).round(),Vector2.ONE),color)
