extends SceneTree
func _initialize():call_deferred("run")
func run():
 var demo=load("res://effects/VFX-22_level_up/level_up.tscn").instantiate();root.add_child(demo);demo.set_process(false)
 demo.toggle_pause();assert(demo.paused)
 var a=demo.fx.age;demo.step_frame();assert(demo.fx.age>a)
 demo.apply_preset(2);assert(demo.config.height==80)
 demo.moving=true;demo.advance(0.1);assert(demo.fx.anchor==demo.host.position)
 demo.fx.stop();assert(not demo.fx.active)
 demo.reset_all();assert(not demo.paused and not demo.moving and demo.fx.active)
 demo.config.intensity=0;demo.trigger();assert(demo.fx.config.intensity==0)
 demo.free();print("LEVEL UP DEMO PASS 7");quit()
