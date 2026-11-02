extends SceneTree
var checks:=0
func check(v:bool)->void:
 assert(v);checks+=1
func _initialize()->void:call_deferred("run")
func run()->void:
 var f=load("res://effects/VFX-10_poison/poison.gd").new();root.add_child(f);f.automatic=false
 f.play(Vector2.ZERO);check(f.active);check(f.envelope()==0)
 f.tick(0.24);check(is_equal_approx(f.envelope(),1));var p=f.puff_state(4);f.play(Vector2.ZERO);f.tick(0.24);check(p==f.puff_state(4))
 for fps in [30,60,144]:
  f.play(Vector2.ZERO)
  for i in range(fps*4):f.tick(1.0/fps)
  check(not f.active and not f.draining);check(f.envelope()==0)
 for i in range(1000):
  f.play(Vector2(i,0),{"seed":i});f.tick(0.4);check(f.position.x==i);check(f.envelope()==1);f.stop();check(not f.active and f.envelope()==0)
 f.play(Vector2.ZERO,{"radius":1000,"density":1000,"duration":-1,"flow":100});check(f.config.radius==52 and f.config.density==24 and f.config.duration==0.3 and f.config.flow==2)
 f.play(Vector2.ZERO,{"radius":NAN});check(f.config.radius==40)
 f.tick(-1);f.tick(NAN);check(f.age==0)
 f.play(Vector2.ZERO,{"duration":0.3});f.tick(0.3);check(not f.active and f.draining);f.tick(0.5);check(not f.draining)
 f.active_finished.connect(func():f.play(Vector2.ZERO,{"duration":1}),CONNECT_ONE_SHOT)
 f.play(Vector2.ZERO,{"duration":0.3});f.tick(1);check(f.active and f.age==0)
 f.stop();f.queue_free()
 var scene=load("res://effects/VFX-10_poison/poison.tscn").instantiate();root.add_child(scene);scene.set_process(false)
 check(scene.world.field.active);scene.paused=true;scene._process(0.2);check(scene.world.field.age==0)
 scene.reset_all();check(not scene.paused);scene.sliders.radius.value=24;check(scene.world.field.config.radius==24)
 scene.sliders.density.value=0;check(scene.world.field.config.density==0)
 scene.palette();check(scene.world.field.config.body==Color("9560a0"));scene.reset_all();check(scene.world.field.config.body==Color("638d3a"))
 scene.queue_free();print("PASS poison ",checks," assertions");quit()
