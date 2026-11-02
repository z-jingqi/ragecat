extends SceneTree
const State=preload("res://effects/VFX-05_hit_flash/flash_state.gd")
var checks:=0
func check(ok:bool,message:String)->void:
 checks+=1
 if not ok:push_error(message);quit(1)
func _initialize()->void:
 var s:=State.new()
 check(s.amount()==0,"idle")
 s.trigger();check(is_equal_approx(s.amount(),0.46),"instant peak")
 s.tick(0.01);check(is_equal_approx(s.amount(),0.46),"brief hold")
 s.tick(0.04);var before:=s.amount();check(before>0 and before<0.46,"decay")
 s.trigger();check(s.amount()==s.peak,"retrigger refresh, no stacking")
 s.paused=true;s.tick(100);check(s.elapsed==0,"pause freezes")
 s.reset();check(not s.active and not s.paused and s.amount()==0,"reset")
 for hz in [30,60,144]:
  s.trigger()
  for i in range(hz):s.tick(1.0/hz)
  check(not s.active and s.amount()==0,"fps end")
 s.configure({"duration":-1,"peak":100,"hold":100});check(s.duration==0.02 and s.peak==0.8 and s.hold==0.01,"clamps")
 s.configure({"peak":NAN,"duration":INF});check(s.peak==0.8 and s.duration==0.02,"finite")
 s.trigger();s.tick(NAN);s.tick(-1);check(s.elapsed==0,"invalid delta")
 for i in range(1000):
  s.trigger();check(s.amount()<=0.8,"bounded retrigger")
  s.tick(0.5);check(s.amount()==0,"fully gone")
 s.configure({"peak":0});s.trigger();check(s.amount()==0,"zero amount")
 var scene=load("res://effects/VFX-05_hit_flash/flash.tscn").instantiate();root.add_child.call_deferred(scene)
 await process_frame
 for i in range(4):scene.apply_preset(i);scene.hit();check(scene.state.active,"preset hit")
 scene.toggle_pause();var age:float=scene.state.elapsed;scene.advance(0.1);check(scene.state.elapsed==age,"scene pause")
 scene.step_once();check(scene.state.elapsed>age,"step")
 scene.reset_all();check(scene.preset.selected==0 and not scene.state.paused,"reset controls")
 scene.repeat_hit();scene.toggle_pause();scene.advance(0.1);check(scene.repeat_after==0.035,"repeat timer pauses")
 scene.reset_all();check(scene.repeat_after<0.0,"reset cancels pending hit")
 scene.looping=false;scene.advance(0.04);check(scene.state.elapsed>0.035,"no ghost hit after reset")
 scene.repeat_hit();scene.advance(0.04);check(scene.state.elapsed==0.0 and scene.repeat_after<0.0,"repeat happens once")
 print("HIT FLASH PASS ",checks," checks")
 quit()
