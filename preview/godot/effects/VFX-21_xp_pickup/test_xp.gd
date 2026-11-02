extends SceneTree
const State=preload("res://effects/VFX-21_xp_pickup/xp_state.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
 checks+=1
 if not ok:failures+=1;push_error(message)
func advance(s:RefCounted,seconds:float,fps:int=60,to:Vector2=Vector2(130,0))->void:
 for i in range(int(round(seconds*fps))):s.tick(1.0/fps,to)
func _initialize()->void:
 var a:=State.new();var b:=State.new()
 a.spawn(Vector2.ZERO);b.spawn(Vector2.ZERO)
 for i in range(a.gems.size()):check(a.gems[i].ground==b.gems[i].ground,"seed deterministic")
 advance(a,0.5);check(a.gems[0].phase==1,"settles")
 var pos:Vector2=a.gems[0].pos;a.paused=true;advance(a,0.1);check(a.gems[0].pos==pos,"paused")
 a.paused=false;a.attract(Vector2(130,0));var received:Array[int]=[];a.arrived.connect(func(id):received.append(id))
 advance(a,2.0);check(a.gems.is_empty(),"clear after arrival");check(received.size()==9,"one arrival each")
 advance(a,1);check(received.size()==9,"no duplicate callbacks")
 a.reset();a.spawn(Vector2.ZERO);a.attract(Vector2(130,0));advance(a,0.1);a.invalidate_target();check(a.gems[0].phase==1,"target lost returns idle");advance(a,0.2);check(a.arrived_count==0,"no reward on invalid target")
 a.attract(Vector2(20,0));advance(a,2);check(a.arrived_count==9,"retarget collects")
 a.reset();a.configure({"count":1000,"radius":-9,"acceleration":INF});a.spawn(Vector2.ZERO);a.spawn(Vector2.ZERO);check(a.gems.size()==32,"capacity");check(a.config.radius==2,"clamp");check(a.config.acceleration==780,"invalid ignored")
 for g in a.gems:check(g.path.size()<=48,"boundedhistory")
 a.reset();a.configure({"count":1,"idle_seconds":0.2});a.spawn(Vector2.ZERO);advance(a,1);check(a.gems.is_empty() and a.arrived_count==0,"expiry no reward")
 var samples:Array[Vector2]=[]
 for fps in [30,60,120]:
  var s:=State.new();s.configure({"count":1});s.spawn(Vector2.ZERO);s.attract(Vector2(130,0));advance(s,0.3,fps);samples.append(s.gems[0].pos)
 check(samples[0].distance_to(samples[1])<0.01 and samples[1].distance_to(samples[2])<0.01,"fps consistency")
 for repeat in range(100):
  a.reset();a.configure({"count":32});a.spawn(Vector2.ZERO);a.attract(Vector2(30,0))
  for i in range(60):
   a.tick(1.0/60,Vector2(30+sin(i*0.03)*5,cos(i*0.03)*5))
   check(a.gems.size()<=32,"pool capacity")
  check(a.arrived_count==32,"moving target once");check(a.gems.is_empty(),"pool cleaned")
 var interrupted:=State.new();interrupted.configure({"count":9});interrupted.spawn(Vector2.ZERO)
 var on_arrival:=func(_id):interrupted.reset()
 interrupted.arrived.connect(on_arrival)
 interrupted.attract(Vector2.ZERO);advance(interrupted,0.1,60,Vector2.ZERO);interrupted.arrived.disconnect(on_arrival);check(interrupted.gems.is_empty(),"reset inside arrival callback")
 var invalid:=State.new();invalid.spawn(Vector2(INF,0));check(invalid.gems.is_empty(),"invalid origin")
 invalid.spawn(Vector2.ZERO);invalid.tick(NAN,Vector2.ZERO);check(invalid.elapsed==0,"invalid dt")
 invalid.attract(Vector2(130,0));invalid.tick(0.1,Vector2(NAN,0));check(invalid.gems[0].phase==1,"invalid target")
 invalid.reset();check(invalid.target_valid,"reset restores validity")
 var start_usec:=Time.get_ticks_usec()
 for i in range(2400):
  if a.gems.is_empty():a.spawn(Vector2.ZERO);a.attract(Vector2(150,0))
  a.tick(1.0/120,Vector2(150,0))
 print("XP 32-object simulation benchmark us/frame: ",float(Time.get_ticks_usec()-start_usec)/2400.0)
 print("XP checks PASS: " if failures==0 else "XP checks FAILED: ",checks);quit(0 if failures==0 else 1)
