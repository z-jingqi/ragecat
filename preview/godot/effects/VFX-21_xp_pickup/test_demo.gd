extends SceneTree
var failed:=false
var checks:=0
func check(ok:bool,msg:String)->void:
 checks+=1
 if not ok:failed=true;push_error(msg)
func _initialize()->void:call_deferred("run")
func run()->void:
 var demo=load("res://effects/VFX-21_xp_pickup/xp_pickup.tscn").instantiate()
 root.add_child(demo);demo.set_process(false)
 check(demo.state.gems.size()==9,"initial count")
 demo.state.invalidate_target();demo.paused=true;demo.reset_all()
 check(demo.state.target_valid and not demo.paused,"reset target/pause")
 demo.sliders.count.value=32;demo.replay();check(demo.state.gems.size()==32,"count nextspawn")
 demo.sliders.radius.value=8;check(demo.state.config.radius==8,"radius slider")
 demo.sliders.trail_length.value=0;demo.state.attract(demo.target);demo.attracted=true
 demo.moving=true
 for i in range(120):demo.simulate(1.0/60)
 check(demo.state.arrived_count==32,"UI moving target allarrive")
 check(demo.state.gems.is_empty(),"UI finalclear")
 demo.cycle_palette();check(demo.state.config.color_body=="b28aff","palette")
 demo.reset_all();check(demo.state.config.color_body=="48d99b","reset palette")
 demo.queue_free();await process_frame
 print("XP demo checks ","FAIL" if failed else "PASS",": ",checks);quit(1 if failed else 0)
