extends SceneTree
const Field=preload("res://effects/VFX-08_electric_field/field.gd")
var checks:=0
var events:Array=[]
func check(value:bool,message:String)->void:
 checks+=1
 if not value:push_error(message);quit(1);assert(value,message)
func _initialize()->void:call_deferred("run")
func run()->void:
 var f:=Field.new();f.automatic=false;root.add_child(f)
 var inside:=Node2D.new();root.add_child(inside)
 var edge:=Node2D.new();root.add_child(edge);edge.position=Vector2(42,0)
 var outside:=Node2D.new();root.add_child(outside);outside.position=Vector2(42.01,0)
 f.target_tick.connect(func(t,id,time):events.append([t.get_instance_id(),id,time]))
 for fps in [30,60,144]:
  events.clear();f.play(Vector2.ZERO,[inside,inside,edge,outside])
  for frame in range(fps*3):f.tick(1.0/fps)
  check(events.size()==12,"inclusive boundary and dedup / fps")
  check(not f.active and f.arcs.is_empty(),"completed clears")
  var seen:Dictionary={}
  for e in events:check(not seen.has(str(e[0])+":"+str(e[1])),"one target per tick");seen[str(e[0])+":"+str(e[1])]=true
 f.play(Vector2.ZERO,[inside]);f.tick(0.49);events.clear();inside.position=Vector2(100,0);f.tick(0.01)
 check(events.is_empty(),"exit before tick not hit")
 inside.position=Vector2.ZERO;f.tick(0.001);check(events.is_empty(),"reentry does not repeat elapsed tick")
 f.tick(0.499);check(events.size()==1,"next tick hits")
 f.paused=true;var age:=f.age;f.tick(1);check(f.age==age,"pause freezes");f.paused=false
 f.stop();events.clear();f.tick(10);check(events.is_empty() and f.targets.is_empty(),"stop clears event backlog")
 f.play(Vector2.ZERO,[inside]);f.tick(NAN);check(f.age==0,"nonfinite dt")
 f.tick(-1);check(f.age==0,"negative dt")
 f.play(Vector2.ZERO,[outside]);outside.free();f.tick(3);check(not f.active,"deleted target safe")
 f.play(Vector2.ZERO,[inside]);f.tick(0.22);var saved:=f.arcs.duplicate(true);f.play(Vector2.ZERO,[inside]);f.tick(0.22);check(saved==f.arcs,"seed deterministic")
 f.play(Vector2.ZERO,[inside],{"density":5,"arc_interval":0.05,"arc_life":0.3,"duration":30,"radius":90})
 for i in range(1800):
  f.tick(1.0/60);check(f.arcs.size()<=35,"bounded arc history")
  for a in f.arcs:
   check(a.points.size()==8,"bounded vertices")
   check(a.widths.size()==7,"one width per segment")
   for w in a.widths:check(clampi(int(round(f.config.width*w)),1,2)<=2,"thin mainstroke cap")
   for p in a.points:check(p.is_finite() and p.length()<=91,"finite clamped zone arc")
 f.configure({"radius":INF,"density":-5,"width":99,"duration":NAN,"body":"notcolor"})
 check(f.config.radius==42 and f.config.density==1 and f.config.width==2 and f.config.duration==3,"sanitize")
 for i in range(1000):f.play(Vector2.ZERO,[inside]);f.tick(0.07);f.stop();check(f.arcs.is_empty() and f.targets.is_empty(),"reuse clears")
 # Stop/restart from a callback must abort the old generation.
 var stopper:=func(_t,_id,_time):f.stop()
 f.target_tick.connect(stopper);events.clear();f.play(Vector2.ZERO,[inside,edge]);f.tick(3);check(events.size()==1,"reentrant stop aborts remaining events");f.target_tick.disconnect(stopper)
 var restarter:=func(_t,_id,_time):f.play(Vector2.ZERO,[])
 f.target_tick.connect(restarter);events.clear();f.play(Vector2.ZERO,[inside,edge]);f.tick(2);check(events.size()==1 and f.age==0 and f.active,"reentrant play does not advance replacement");f.target_tick.disconnect(restarter)
 var many:Array=[]
 for i in range(80):var n:=Node2D.new();root.add_child(n);many.append(n)
 f.play(Vector2.ZERO,many);check(f.targets.size()==64,"target capacity")
 f.stop()
 for n in many:n.free()
 inside.free();edge.free();f.free()
 print("PASS field checks ",checks);quit()
