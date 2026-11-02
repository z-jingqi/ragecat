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
 fx.play(Vector2.ZERO,[inside,edge,outside,inside,null])
 check(hits.size()==2,"unique snapshot and inclusive boundary")
 var snapshot:=var_to_str(fx.paths)
 for fps in [30,60,120,144]:
  hits.clear();fx.play(Vector2.ZERO,[inside,edge,outside]);check(var_to_str(fx.paths)==snapshot,"determinism")
  for i in range(int(ceil(0.55*fps))):fx.tick(1.0/fps)
  check(hits.size()==2,"one hit per trigger, not per frame")
  check(not fx.active and fx.paths.is_empty(),"end empty")
 for i in range(1000):
  hits.clear();fx.play(Vector2.ZERO,[inside,inside],{"arcs":100,"seed":i})
  check(hits.size()==1,"pooled hit")
  check(fx.paths.size()==16,"bounded arrays")
  fx.tick(1);check(not fx.active,"pooled finish")
 fx.play(Vector2.ZERO,[],{"radius":NAN,"duration":INF,"width":-5,"seed":-1})
 check(fx.config.radius==42 and fx.config.duration==0.5 and fx.config.width==1 and fx.config.seed==0,"sanitization")
 fx.paused=true;fx.tick(1);check(fx.age==0,"pause");fx.paused=false
 fx.tick(NAN);fx.tick(-1);check(fx.age==0,"invalid delta")
 fx.clear();check(not fx.active and fx.hit_ids.is_empty(),"clear")
 fx.play(Vector2.ZERO,[],{"orb_radius":100,"pulse_hz":-1});check(fx.config.orb_radius==16 and fx.config.pulse_hz==0,"orb clamps")
 check(not fx.config.has("sparks"),"no explosive particle layer")
 var stop:=func(_t:Node2D):fx.clear()
 fx.target_hit.connect(stop);hits.clear();fx.play(Vector2.ZERO,[inside,edge]);check(hits.size()==1 and not fx.active,"reentrant clear stops callbacks");fx.target_hit.disconnect(stop)
 var victim:=Node2D.new();root.add_child(victim);victim.queue_free();hits.clear();fx.play(Vector2.ZERO,[victim]);check(hits.is_empty(),"queued target ignored")
 inside.free();hits.clear();fx.play(Vector2.ZERO,[inside]);check(hits.is_empty(),"freed target ignored")
 var fin:=[0];fx.finished.connect(func():fin[0]+=1)
 fx.play(Vector2.ZERO);fx.tick(99);fx.tick(99);check(fin[0]==1,"finished once")
 var demo=load("res://effects/VFX-08_lightning_burst/burst.tscn").instantiate();root.add_child(demo)
 await process_frame
 demo.set_process(false);demo.paused=true;demo.advance(0.02);demo.reset();check(demo.fx.active and not demo.paused,"demo reset")
 demo.loops=false;demo.fx.clear();demo.advance(2);check(not demo.fx.active,"clear doesn't replay")
 demo.config.radius=8;demo.trigger();check(demo.hits==0,"small radius")
 demo.config.radius=65;demo.trigger();check(demo.hits==4,"large radius")
 print("BURST CHECKS: ",count," failures: ",failures)
 quit(1 if failures else 0)
