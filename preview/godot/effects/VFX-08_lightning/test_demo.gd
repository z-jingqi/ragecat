extends SceneTree
var count:=0
func check(v:bool,msg:String)->void:
	count+=1
	if not v:push_error(msg);quit(1);assert(false,msg)
func _initialize()->void:call_deferred("run")
func run()->void:
	var demo=load("res://effects/VFX-08_lightning/lightning.tscn").instantiate();root.add_child(demo);demo.set_process(false)
	demo.toggle_pause();check(demo.paused,"pause")
	demo.step_frame();check(demo.fx.age>0,"step")
	demo.apply_preset(2);check(demo.config.width==1.5,"preset")
	demo.sliders.angle.value=25;check(demo.angle==25 and demo.fx.active,"angle")
	demo.sliders.length.value=64;check(absf(demo.fx.start.distance_to(demo.fx.target)-64)<0.001,"length")
	demo.sliders.branches.value=0;check(demo.fx.forks.is_empty(),"branches")
	demo.fx.clear();demo.loops=false;demo.advance(1);check(not demo.fx.active,"clear no loop")
	demo.reset_all();check(not demo.paused and demo.angle==90 and demo.length==88 and demo.config.width==1.5 and demo.rate==1 and demo.dark,"reset")
	demo.advance(1.2);check(demo.fx.active and demo.fx.age==0,"loop")
	print("LIGHTNING_DEMO_CHECKS_PASS ",count);demo.free();quit()
