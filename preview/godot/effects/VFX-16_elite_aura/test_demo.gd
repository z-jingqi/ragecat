extends SceneTree
var n:=0
func _initialize() -> void:
 call_deferred("run")
func check(v:bool,m:String) -> void:
 n+=1
 assert(v,m)
func run() -> void:
 var demo=load("res://effects/VFX-16_elite_aura/elite_aura.tscn").instantiate();root.add_child(demo)
 await process_frame
 demo.toggle_pause();check(demo.paused,"pause")
 var a:float=demo.fx.age;demo.step_frame();check(demo.fx.age>a,"step")
 demo.moving=true;demo.advance(0.2);check(demo.fx.anchor==demo.host.position,"follow")
 demo.fx.stop();demo.loops=false;demo.advance(1);check(not demo.fx.active,"stop")
 demo.reset_all();check(not demo.paused and not demo.moving,"reset state");check(demo.fx.active,"reset play")
 demo.apply_preset(1);check(demo.config.body=="b986dc","palette")
 demo.apply_preset(3);check(demo.config.particles==8,"preset")
 print("PASS demo ",n);demo.queue_free();quit()
