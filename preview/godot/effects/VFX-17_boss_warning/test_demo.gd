extends SceneTree
const Demo=preload("res://effects/VFX-17_boss_warning/demo.gd")
var checks:=0
func check(ok:bool,msg:String)->void:
	checks+=1
	if not ok:push_error(msg);quit(1)
func _initialize()->void:call_deferred("run")
func run()->void:
	var d:=Demo.new();root.add_child(d);d.set_process(false)
	d.set_shape(2);check(d.fx.area.shape=="sector","selector")
	d.area.orientation_deg=45;d.trigger();check(d.fx.area.orientation_deg==45,"orientation")
	d.paused=true;var before:float=d.fx.elapsed;check(d.fx.elapsed==before,"pause")
	d.advance(1.0/60);check(d.fx.elapsed>before,"step")
	d.fx.cancel();d.loop=false;d.advance(2);check(not d.fx.active,"cancel persists")
	d.reset_all();check(d.area==d.Warning.DEFAULT_AREA and d.selector.selected==0,"reset config")
	check(d.sliders.radius.value==42 and not d.paused,"reset UI")
	d.follow=true;d.moving=true;d.trigger();d.elapsed=0.7;d.advance(0.1);check(d.fx.position==d.host.position,"follow")
	d.follow=false;d.trigger();var p:Vector2=d.fx.position;d.elapsed=1;d.advance(0.1);check(d.fx.position==p,"locked")
	print("PASS ",checks," preview checks");d.free();quit()
