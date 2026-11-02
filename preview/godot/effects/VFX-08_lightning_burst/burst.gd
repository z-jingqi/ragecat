extends Node2D
## Sustained orb and continuously renewed fine arcs. Optional periodic hit notifications.
signal target_hit(target: Node2D)
signal finished
const DEFAULTS = {"radius":42.0,"duration":3.0,"arcs":6,"width":1.0,"orb_radius":8.0,"pulse_hz":3.0,"arc_interval":0.12,"hit_interval":0.0,"seed":21,"core":"efffff","body":"81dcff","edge":"5977d8"}
var config: Dictionary = DEFAULTS.duplicate()
var paths: Array = []
var age := 0.0
var active := false
var automatic := true
var paused := false
var epoch := 0
var hit_ids: Array[int] = []
var candidates: Array = []
var next_hit := 0.0
var visual_generations := 0
func clean(values: Dictionary) -> Dictionary:
 var c:=DEFAULTS.duplicate()
 var limits:={"radius":Vector2(8,80),"duration":Vector2(0.25,30),"arcs":Vector2(3,16),"width":Vector2(1,2),"orb_radius":Vector2(3,16),"pulse_hz":Vector2(0,16),"arc_interval":Vector2(0.04,0.4),"hit_interval":Vector2(0,5),"seed":Vector2(0,65535)}
 for k in limits:
  var v:Variant=values.get(k,c[k])
  if (v is float or v is int) and is_finite(float(v)): c[k]=clampf(float(v),limits[k].x,limits[k].y)
 for k in ["arcs","seed"]:c[k]=int(c[k])
 for k in ["core","body","edge"]:
  var v:Variant=values.get(k,c[k]);var color:Color=Color.from_string(v,Color(DEFAULTS[k])) if v is String else (v if v is Color else Color(DEFAULTS[k]))
  if not is_finite(color.r+color.g+color.b):color=Color(DEFAULTS[k])
  c[k]=Color(clampf(color.r,0,1),clampf(color.g,0,1),clampf(color.b,0,1),1)
 if c.hit_interval>0:c.hit_interval=maxf(0.1,c.hit_interval)
 return c
func clear() -> void:
 epoch+=1;active=false;age=0;paths.clear();hit_ids.clear();candidates.clear();next_hit=0;visual_generations=0;queue_redraw()
func play(center: Vector2, targets: Array = [], values: Dictionary = {}) -> void:
 clear();config=clean(values)
 global_position=center if center.is_finite() else Vector2.ZERO
 candidates=targets.duplicate();active=true
 rebuild_arcs()
 if config.hit_interval>0:
  next_hit=config.hit_interval
  emit_hits()
 queue_redraw()
func rebuild_arcs() -> void:
 for i in range(config.arcs):
  var cycle:int=int(floor((age+float(i)/config.arcs*config.arc_interval+0.0000001)/config.arc_interval))
  if i<paths.size() and paths[i].cycle==cycle:continue
  var rng:=RandomNumberGenerator.new();rng.seed=int(config.seed)+i*10007+cycle*104729
  var a:float=TAU*(float(i)+rng.randf_range(-0.4,0.4))/config.arcs+rng.randf_range(-0.25,0.25)
  var axis:=Vector2.from_angle(a);var side:=Vector2(-axis.y,axis.x)
  var points:=PackedVector2Array([axis*config.orb_radius*0.75])
  var reach:float=maxf(config.orb_radius+4,config.radius*rng.randf_range(0.65,1.0))
  var wander:=0.0
  for j in range(1,12):
   var t:=float(j)/11
   wander=wander*0.25+rng.randf_range(-1,1)
   points.append((axis*lerpf(config.orb_radius*0.75,reach,t)+side*wander*5*sin(PI*t)).round())
  var forks:Array=[]
  for j in range(2):
   var index:=rng.randi_range(3,8);var q:Vector2=points[index]
   var sign_value:=1 if j%2==0 else -1
   var branch:=PackedVector2Array([q])
   for k in range(1,5):branch.append((q+axis*k*2+side*(k*1.5*sign_value+rng.randf_range(-1.5,1.5))).round())
   forks.append(branch)
  var item:={"points":points,"forks":forks,"cycle":cycle}
  if i<paths.size():paths[i]=item
  else:paths.append(item)
  visual_generations+=1
func emit_hits() -> void:
 var token:=epoch;hit_ids.clear()
 var selected:Array[Node2D]=[]
 for candidate in candidates:
  if is_instance_valid(candidate) and candidate is Node2D and not candidate.is_queued_for_deletion():
   var id:int=candidate.get_instance_id()
   if not hit_ids.has(id) and candidate.global_position.is_finite() and global_position.distance_squared_to(candidate.global_position)<=config.radius*config.radius+0.0001:
    hit_ids.append(id);selected.append(candidate)
 for candidate in selected:
  if epoch!=token or not active:return
  if is_instance_valid(candidate) and not candidate.is_queued_for_deletion():target_hit.emit(candidate)
func tick(dt:float) -> void:
 if not active or paused or not is_finite(dt) or dt<=0:return
 var token:=epoch
 age=minf(age+dt,config.duration)
 if config.hit_interval>0:
  while next_hit<=age+0.000001 and next_hit<config.duration-0.000001:
   next_hit+=config.hit_interval
   emit_hits()
   if epoch!=token or not active:return
 if age>=config.duration-0.000001:
  active=false;paths.clear();candidates.clear();queue_redraw();finished.emit();return
 rebuild_arcs();queue_redraw()
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
 # Steady light sphere for the entire configured lifetime: no blast envelope.
 var pulse:float=1+0.055*sin(age*config.pulse_hz*TAU)
 var r:float=maxf(1,round(config.orb_radius*pulse))
 draw_circle(Vector2.ZERO,r+1,config.edge,true,-1,false)
 draw_circle(Vector2.ZERO,r,config.body,true,-1,false)
 draw_circle(Vector2(-1,-1),maxf(1,r*0.72),config.core,true,-1,false)
 for i in range(paths.size()):
  var item:Dictionary=paths[i]
  var phase:float=fposmod(age+float(i)/config.arcs*config.arc_interval,config.arc_interval)/config.arc_interval
  # No thick outline: main filament 1px by default, short dimmer 1px branches.
  stroke(item.points,config.core if phase<0.38 else config.body,config.width,1)
  for fork in item.forks:stroke(fork,config.body if phase<0.38 else config.edge,1,1)
