extends SceneTree
var checks:=0
func ck(ok:bool,msg:String) -> void:
	checks+=1
	if not ok:push_error(msg);quit(1)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var d=load("res://effects/VFX-11_wind/wind.tscn").instantiate();root.add_child(d);await process_frame
	d.set_process(false)
	ck(d.fx.active,"starts")
	d.toggle_pause();ck(d.paused,"pause")
	var t=d.fx.age;d.step_frame();ck(d.fx.age>t,"step")
	d.apply_preset(1);ck(not d.fx.config.clockwise,"reverse")
	d.apply_preset(2);ck(d.fx.config.height==28,"low vortex")
	d.sliders.radius.value=24;ck(d.fx.config.radius==24,"radius live")
	d.fx.stop();d.advance(0.25);ck(not d.fx.active,"graceful stop")
	d.reset_all();ck(d.fx.config.radius==32 and not d.paused,"reset")
	d.free();print("PASS ",checks," wind demo checks");quit()
