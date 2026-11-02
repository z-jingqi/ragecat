extends Node2D
## One instantaneous area-hit notification per unique valid target. No health ownership.
signal target_hit(target: Node2D)
signal finished
const DEFAULTS = {"radius":42.0,"duration":0.5,"arcs":6,"width":2.0,"orb_radius":8.0,"pulse_hz":7.0,"seed":21,"core":"efffff","body":"81dcff","edge":"5977d8"}
var config: Dictionary = DEFAULTS.duplicate()
var paths: Array = []
var age := 0.0
var active := false
var automatic := true
var paused := false
var epoch := 0
var hit_ids: Array[int] = []
func clean(values: Dictionary) -> Dictionary:
 var c:=DEFAULTS.duplicate()
 var limits:={"radius":Vector2(8,80),"duration":Vector2(0.12,0.8),"arcs":Vector2(3,16),"width":Vector2(1,4),"orb_radius":Vector2(3,16),"pulse_hz":Vector2(0,16),"seed":Vector2(0,65535)}
 for k in limits:
  var v:Variant=values.get(k,c[k])
  if (v is float or v is int) and is_finite(float(v)): c[k]=clampf(float(v),limits[k].x,limits[k].y)
 for k in ["arcs","seed"]:c[k]=int(c[k])
 for k in ["core","body","edge"]:
  var v:Variant=values.get(k,c[k]);var color:Color=Color.from_string(v,Color(DEFAULTS[k])) if v is String else (v if v is Color else Color(DEFAULTS[k]))
  if not is_finite(color.r+color.g+color.b):color=Color(DEFAULTS[k])
  c[k]=Color(clampf(color.r,0,1),clampf(color.g,0,1),clampf(color.b,0,1),1)
 return c
func clear() -> void:
 epoch+=1;active=false;age=0;paths.clear();hit_ids.clear();queue_redraw()
func play(center: Vector2, candidates: Array = [], values: Dictionary = {}) -> void:
 clear();config=clean(values)
 global_position=center if center.is_finite() else Vector2.ZERO
 var rng:=RandomNumberGenerator.new();rng.seed=config.seed
 for i in range(config.arcs):
  var a:float=TAU*(float(i)+rng.randf_range(-0.32,0.32))/config.arcs
  var axis:=Vector2.from_angle(a);var side:=Vector2(-axis.y,axis.x)
  var points:=PackedVector2Array([axis*config.orb_radius*0.7])
  var reach:float=config.radius*rng.randf_range(0.68,1.0)
  for j in range(1,7):
   var t:=float(j)/6
   points.append((axis*(config.orb_radius*0.7+(reach-config.orb_radius*0.7)*t)+side*rng.randf_range(-7,7)*sin(PI*t)).round())
  paths.append({"points":points,"delay":rng.randf_range(0,0.07),"life":rng.randf_range(0.5,0.85),"width":rng.randf_range(0.65,1.3),"fork":i%3==0})
 active=true;var token:=epoch
 # Snapshot the hit set before callbacks. Visual extents never change the hit radius.
 var selected:Array[Node2D]=[]
 for candidate in candidates:
  if is_instance_valid(candidate) and candidate is Node2D and not candidate.is_queued_for_deletion():
   var id:int=candidate.get_instance_id()
   if not hit_ids.has(id) and candidate.global_position.is_finite() and global_position.distance_squared_to(candidate.global_position)<=config.radius*config.radius+0.0001:
    hit_ids.append(id);selected.append(candidate)
 for candidate in selected:
  if epoch!=token:return
  if is_instance_valid(candidate) and not candidate.is_queued_for_deletion():target_hit.emit(candidate)
 if epoch==token:queue_redraw()
func tick(dt:float) -> void:
 if not active or paused or not is_finite(dt) or dt<=0:return
 age=minf(age+dt,config.duration)
 if age>=config.duration-0.000001:
  active=false;paths.clear();queue_redraw();finished.emit();return
 queue_redraw()
func _process(dt:float) -> void:
 if automatic:tick(dt)
func stroke(points:PackedVector2Array,color:Color,width:float,reach:float,trim:float=0.0) -> void:
 for j in range(points.size()-1):
  var lo:=float(j)/(points.size()-1);var hi:=float(j+1)/(points.size()-1)
  if reach<=lo or trim>=hi:continue
  var a:=points[j].lerp(points[j+1],clampf((trim-lo)/(hi-lo),0,1)).round()+Vector2(0.5,0.5)
  var b:=points[j].lerp(points[j+1],clampf((reach-lo)/(hi-lo),0,1)).round()+Vector2(0.5,0.5)
  draw_line(a,b,color,maxf(1,round(width)),false)
func _draw() -> void:
 if not active:return
 var t:float=age/config.duration
 # A compact light orb, not an expanding explosion or shockwave.
 var envelope:float=minf(1,t/0.06)*clampf((1-t)/0.22,0,1)
 var pulse:float=1+0.09*sin(age*config.pulse_hz*TAU)
 var r:float=maxf(1,round(config.orb_radius*envelope*pulse))
 draw_circle(Vector2.ZERO,r+2,config.edge,false,1,false)
 draw_circle(Vector2.ZERO,r,config.body,true,-1,false)
 draw_circle(Vector2(-1,-1),maxf(1,r*0.7),config.core,true,-1,false)
 for item in paths:
  var u:float=(age-item.delay)/config.duration
  if u<0 or u>item.life:continue
  var reach:float=minf(1,u/0.16);var trim:float=clampf((u-0.2)/(item.life-0.2),0,1)
  var w:float=config.width*item.width*(1-0.55*trim)
  stroke(item.points,config.edge,w+2,reach,trim)
  stroke(item.points,config.body,w,reach,trim)
  if u<0.24:stroke(item.points,config.core,1,reach,trim)
  if item.fork and u>0.07 and u<0.48:
   var q:Vector2=item.points[3];var a:=q.angle()+0.55
   stroke(PackedVector2Array([q,q+Vector2.from_angle(a)*7,q+Vector2.from_angle(a+0.3)*14]),config.body,1,1,clampf((u-0.22)/0.26,0,1))
