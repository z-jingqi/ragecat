extends RefCounted
signal arrived(pickup_id: int)
const STEP := 1.0/240.0
const CAPACITY := 32
var config: Dictionary
var gems: Array[Dictionary] = []
var elapsed := 0.0
var accumulator := 0.0
var next_id := 0
var generation := 0
var arrived_count := 0
var target := Vector2.ZERO
var target_valid := true
var paused := false
func _init() -> void:
 config = JSON.parse_string(FileAccess.get_file_as_string("res://effects/VFX-21_xp_pickup/default.json"))
func configure(values: Dictionary) -> void:
 var ranges := {"count":Vector2(1,32),"seed":Vector2(0,2147483647),"radius":Vector2(2,8),"scatter":Vector2(0,90),"drop_seconds":Vector2(0.08,1.0),"bounce_height":Vector2(0,42),"idle_seconds":Vector2(0.2,30),"attract_speed":Vector2(30,600),"acceleration":Vector2(60,2000),"trail_length":Vector2(0,40),"arrival_seconds":Vector2(0.05,0.35)}
 for key in values:
  if key in ranges and (values[key] is int or values[key] is float) and is_finite(float(values[key])):
   config[key] = clampf(float(values[key]),ranges[key].x,ranges[key].y)
  elif key in ["color_dark","color_body","color_light"] and values[key] is String and Color.html_is_valid(values[key]): config[key]=values[key]
 config.count=int(config.count);config.seed=int(config.seed)
func reset() -> void:
 generation+=1;gems.clear();elapsed=0.0;accumulator=0.0;arrived_count=0;paused=false;target_valid=true
func spawn(origin: Vector2) -> void:
 if not origin.is_finite():return
 var rng:=RandomNumberGenerator.new();rng.seed=int(config.seed)
 for i in range(mini(int(config.count),CAPACITY-gems.size())):
  var angle:=TAU*(float(i)+rng.randf_range(-0.25,0.25))/float(config.count)
  var ground:=origin+Vector2(cos(angle),sin(angle)*0.48)*float(config.scatter)*rng.randf_range(0.45,1.0)
  gems.append({"id":next_id,"phase":0,"age":0.0,"pos":origin,"origin":origin,"ground":ground,"velocity":Vector2.ZERO,"speed":0.0,"path":[],"arrival":Vector2.ZERO,"phase_offset":rng.randf()*TAU})
  next_id+=1
func attract(to: Vector2) -> void:
 if not to.is_finite():return
 target=to;target_valid=true
 for g in gems:
  if g.phase<2:g.phase=2;g.age=0.0;g.speed=35.0;g.velocity=Vector2.ZERO;g.path.clear()
func invalidate_target() -> void:
 target_valid=false
 for g in gems:
  if g.phase==2:
   g.phase=1;g.age=0.0;g.ground=g.pos;g.velocity=Vector2.ZERO;g.path.clear()
func tick(dt: float, to: Vector2, valid: bool=true) -> void:
 if paused or not is_finite(dt) or dt<=0:return
 if not valid or not to.is_finite():invalidate_target()
 else:target=to;target_valid=true
 # Bounded catch-up protects stalled hosts; no unbounded simulation work.
 accumulator+=minf(dt,0.25)
 while accumulator+0.00000001>=STEP:
  accumulator-=STEP;advance(STEP)
func advance(dt: float) -> void:
 var generation_at_start:=generation
 elapsed+=dt
 for g in gems:
  g.age+=dt
  match int(g.phase):
   0:
    var u:=clampf(g.age/float(config.drop_seconds),0,1)
    g.pos=g.origin.lerp(g.ground,1.0-pow(1.0-u,2.0))+Vector2(0,-sin(PI*u)*float(config.bounce_height))
    if u>=1:g.phase=1;g.age=0.0;g.pos=g.ground
   1:
    g.pos=g.ground+Vector2(0,sin(g.age*3.0+g.phase_offset)*1.0)
    if g.age>=float(config.idle_seconds):g.phase=4
   2:
    if not target_valid:continue
    g.speed=minf(float(config.attract_speed),g.speed+float(config.acceleration)*dt)
    var offset:Vector2=target-g.pos
    var distance:=offset.length()
    var step_distance:float=g.speed*dt
    if distance<=maxf(2.0,step_distance):
     g.pos=target;g.arrival=target;g.phase=3;g.age=0.0;g.path.clear();arrived_count+=1;arrived.emit(g.id)
     if generation!=generation_at_start:return
    else:
     g.velocity=offset/distance*g.speed
     g.pos+=g.velocity*dt
     var path:Array=g.path
     if path.is_empty() or g.pos.distance_to(path.back())>=1.0:path.append(g.pos)
     while path.size()>48:path.pop_front()
     var total:=0.0
     for j in range(path.size()-1,0,-1):
      total+=path[j].distance_to(path[j-1])
      if total>float(config.trail_length):
       for k in range(j):path.pop_front()
       break
   3:
    if g.age>=float(config.arrival_seconds):g.phase=4
 gems=gems.filter(func(g):return g.phase!=4)
