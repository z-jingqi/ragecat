extends SceneTree
const Demo=preload("res://effects/VFX-15_monster_death/demo.gd")
var checks:=0
func check(value:bool,msg:String)->void:
 checks+=1
 if not value:push_error(msg);quit(1)
func _initialize()->void:call_deferred("run")
func run()->void:
 var d:=Demo.new();root.add_child(d);d.set_process(false)
 check(not d.actual.playing,"initial waiting")
 d.advance(0.46);check(d.actual.playing or d.actual.finished,"triggered")
 d.cancel();d.advance(0.8);check(not d.actual.playing and not d.actual.finished and d.actual.elapsed==0,"cancel stays restored")
 d.replay();d.advance(0.46);check(d.fired,"replay after cancel")
 d.reset_all();check(d.looping and not d.paused and not d.fired,"reset controls")
 d.apply_preset(2);check(not d.actual.host_mode and d.actual.fragment_count==12,"standalone preset")
 d.apply_preset(1);check(d.actual.host_mode and d.actual.direction_degrees==0,"directional preset")
 d.configure({"fragment_count":0});check(d.actual.fragment_count==0 and d.enlarged.fragment_count==0,"views share config")
 print("DEATH DEMO CHECKS PASSED: ",checks);d.queue_free();quit()
