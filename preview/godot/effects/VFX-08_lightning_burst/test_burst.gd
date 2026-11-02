extends SceneTree
const Burst=preload("res://effects/VFX-08_lightning_burst/burst.gd")
var count:=0
var failures:=0
var hits:Array=[]
func check(ok:bool,label:String)->void:
 count+=1
 if not ok:failures+=1;push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
 var fx:=Burst.new();fx.automatic=false;root.add_child(fx)
 var inside:=Node2D.new();var edge:=Node2D.new();var outside:=Node2D.new()
 for t in [inside,edge,outside]:root.add_child(t)
 inside.position=Vector2(10,0);edge.position=Vector2(42,0);outside.position=Vector2(42.1,0)
 fx.target_hit.connect(func(t:Node2D):hits.append(t.get_instance_id()))
 fx.play(Vector2.ZERO,[inside,edge,outside,inside,null],{"hit_interval":0.5})
 check(hits.size()==2,"unique initial periodic hit and inclusive boundary")
 fx.tick(0.5);check(hits.size()==4,"second periodic hit")
 outside.position=Vector2(20,0);fx.tick(0.5);check(hits.size()==7,"moving target included at next tick")
 outside.position=Vector2(42.1,0)
 var snapshot:=""
 for fps in [30,60,120,144]:
  hits.clear();fx.play(Vector2.ZERO,[inside,edge,outside],{"duration":3,"hit_interval":0.5})
  for i in range(fps):fx.tick(1.0/fps)
  if snapshot=="":snapshot=var_to_str(fx.paths)
  check(var_to_str(fx.paths)==snapshot,"cadenced geometry frame rate agreement")
  check(hits.size()==6,"periodic hits frame rate agreement")
  for i in range(fps*2):fx.tick(1.0/fps)
  check(hits.size()==12,"no hit at expiry boundary")
  check(not fx.active and fx.paths.is_empty(),"end empty")
 for i in range(1000):
  hits.clear();fx.play(Vector2.ZERO,[inside,inside],{"duration":0.25,"arcs":100,"seed":i,"hit_interval":0.1})
  check(hits.size()==1,"pooled hit")
  check(fx.paths.size()==16,"bounded slots")
  fx.tick(1);check(not fx.active,"pooled finish")
 hits.clear();fx.play(Vector2.ZERO,[inside],{"duration":30,"arc_interval":0.04})
 for i in range(3599):
  fx.tick(1.0/120)
  check(fx.active,"persistent before expiry")
  check(fx.paths.size()==6,"no empty visual cadence and bounded slots")
  for item in fx.paths:check(item.points.size()==12 and item.forks.size()==2,"bounded detailed geometry")
 check(hits.is_empty(),"damage disabled by default")
 check(fx.visual_generations>4000,"arcs continuously regenerated throughout lifetime")
 fx.tick(1);check(not fx.active,"long expiry")
 fx.play(Vector2.ZERO,[],{"radius":NAN,"duration":INF,"width":-5,"seed":-1,"orb_radius":100,"pulse_hz":-1,"arc_interval":0,"hit_interval":0.001})
 check(fx.config.radius==42 and fx.config.duration==3 and fx.config.width==1 and fx.config.seed==0,"sanitization")
 check(fx.config.orb_radius==16 and fx.config.pulse_hz==0 and is_equal_approx(fx.config.arc_interval,0.04) and is_equal_approx(fx.config.hit_interval,0.1),"orb and tick clamps")
 fx.paused=true;var old:=var_to_str(fx.paths);fx.tick(1);check(fx.age==0 and old==var_to_str(fx.paths),"pause all")
 fx.paused=false;fx.tick(NAN);fx.tick(-1);check(fx.age==0,"invalid delta")
 fx.clear();check(not fx.active and fx.hit_ids.is_empty() and fx.candidates.is_empty(),"clear")
 var stop:=func(_t:Node2D):fx.clear()
 fx.target_hit.connect(stop);hits.clear();fx.play(Vector2.ZERO,[inside,edge],{"hit_interval":0.5});check(hits.size()==1 and not fx.active,"reentrant clear stops callbacks");fx.target_hit.disconnect(stop)
 var replay_once:=[false]
 var replace:=func(_t:Node2D):
  if not replay_once[0]:replay_once[0]=true;fx.play(Vector2(100,100),[],{"duration":2})
 fx.target_hit.connect(replace);hits.clear();fx.play(Vector2.ZERO,[inside,edge],{"hit_interval":0.5})
 check(hits.size()==1 and fx.active and fx.global_position==Vector2(100,100) and fx.config.duration==2,"reentrant replay replaces old flow")
 fx.target_hit.disconnect(replace)
 var victim:=Node2D.new();root.add_child(victim);victim.queue_free();hits.clear();fx.play(Vector2.ZERO,[victim],{"hit_interval":0.5});check(hits.is_empty(),"queued target ignored")
 inside.free();hits.clear();fx.play(Vector2.ZERO,[inside],{"hit_interval":0.5});fx.tick(1);check(hits.is_empty(),"freed target ignored")
 var fin:=[0];fx.finished.connect(func():fin[0]+=1)
 fx.play(Vector2.ZERO);fx.tick(99);fx.tick(99);check(fin[0]==1,"finished once")
 var demo=load("res://effects/VFX-08_lightning_burst/burst.tscn").instantiate();root.add_child(demo)
 await process_frame
 demo.set_process(false);demo.paused=true;demo.advance(0.02);demo.reset();check(demo.fx.active and not demo.paused,"demo reset")
 demo.loops=false;demo.fx.clear();demo.advance(4);check(not demo.fx.active,"clear doesn't replay")
 demo.config.radius=8;demo.trigger();check(demo.hits==0,"small radius")
 demo.config.radius=65;demo.trigger();check(demo.hits==4,"large radius")
 print("SUSTAINED ORB CHECKS: ",count," failures: ",failures)
 quit(1 if failures else 0)
