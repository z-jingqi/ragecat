extends SceneTree
const Warning=preload("res://effects/VFX-17_boss_warning/warning.gd")
var checks:=0
var hits:=0
var ends:=0
func check(ok:bool,msg:String)->void:
	checks+=1
	if not ok:push_error(msg);quit(1)
func _initialize()->void:call_deferred("run")
func run()->void:
	var w:=Warning.new();w.automatic=false;root.add_child(w)
	w.activated.connect(func(_a):hits+=1)
	w.finished.connect(func():ends+=1)
	for shape in ["circle","ring","sector","rectangle"]:
		w.play(Vector2(10,20),{"shape":shape,"orientation_deg":37.0})
		for y in range(-60,61,5):
			for x in range(-60,61,5):
				var p:=Vector2(x,y);var world:=p.rotated(deg_to_rad(37))+Vector2(10,20)
				check(w.contains_world(world)==w.inside(p),"rotated geometry")
		var a:=w.area.duplicate()
		w.play(Vector2.ZERO,a,{"fill_alpha":0.0,"line_width":3.0})
		check(w.area==a,"style cannot change authority")
		w.tick(0.5);check(not w.fired,"no early event")
		var before:=hits;w.tick(10);check(hits==before+1 and not w.active,"one event on large frame")
		w.tick(10);check(hits==before+1,"no duplicate")
		check(w.image.get_used_rect().size==Vector2i.ZERO,"clear finish")
	for fps in [30,60,144]:
		w.play(Vector2.ZERO,{"countdown":1.0});var before:=hits
		for i in range(fps-1):w.tick(1.0/fps)
		check(hits==before,"fps no early")
		w.tick(1.0/fps);check(hits==before+1,"fps exact activation")
		for i in range(fps):w.tick(1.0/fps)
		check(not w.active,"fps finish")
	var target:=Node2D.new();root.add_child(target);target.position=Vector2(5,6)
	w.play(Vector2(15,16),{}, {},target,true);target.position=Vector2(20,21);w.tick(0.1);check(w.position==Vector2(30,31),"follow offset")
	w.play(Vector2(15,16),{}, {},target,false);target.position=Vector2(40,41);w.tick(0.1);check(w.position==Vector2(15,16),"lock position")
	w.play(Vector2.ZERO,{}, {},target,true);target.free();w.tick(0.1);check(not w.active,"dead follow host cancels")
	w.play(Vector2.ZERO,{"shape":"ring","radius":40,"inner_radius":20});check(not w.contains_world(Vector2.ZERO) and w.contains_world(Vector2(30,0)),"ring hole")
	w.play(Vector2.ZERO,{"shape":"rectangle","length":80,"width":20});check(w.contains_world(Vector2(40,10)) and not w.contains_world(Vector2(41,0)),"rectangle exact")
	w.play(Vector2.ZERO,{"shape":"sector","radius":40,"angle_deg":90});check(w.contains_world(Vector2(30,0)) and not w.contains_world(Vector2(-1,0)),"sector front")
	var restart:=func(_a):w.play(Vector2.ZERO,{"countdown":2.0})
	w.activated.connect(restart);w.play(Vector2.ZERO);w.tick(9);check(w.active and w.elapsed==0 and not w.fired,"reentrant replay")
	w.activated.disconnect(restart)
	for i in range(200):
		w.play(Vector2.ZERO,{"radius":i-50,"inner_radius":1000,"countdown":-5},{"line_width":-2,"fill_alpha":100});check(w.area.radius>=4 and w.area.inner_radius<w.area.radius,"bounds")
		var before:=hits;w.cancel();w.tick(2);check(hits==before and w.image.get_used_rect().size==Vector2i.ZERO,"cancel clean")
	w.play(Vector2.ZERO,{"radius":NAN},{"fill_alpha":NAN});check(is_finite(w.area.radius) and is_finite(w.style.fill_alpha),"nan default")
	w.tick(NAN);check(w.elapsed==0,"nan delta ignored")
	w.reset();check(w.elapsed==0 and not w.fired,"reset")

	for shape in ["circle","ring","sector","rectangle"]:
		w.play(Vector2.ZERO,{"shape":shape,"orientation_deg":27.0})
		var occupied:=0
		for y in range(128):
			for x in range(128):
				if w.image.get_pixel(x,y).a>0:
					occupied+=1
					check(w.contains_world(Vector2(x-64,y-64)),"raster is within authority")
		check(occupied>10,"shape visible")
		var start:=w.image.get_data()
		w.tick(0.6)
		check(w.image.get_data()!=start,"progress visible without boundary change")
		w.play(Vector2.ZERO,{"shape":shape,"radius":54,"length":96,"width":56,"orientation_deg":31.0})
		for i in range(128):
			check(w.image.get_pixel(i,0).a==0 and w.image.get_pixel(i,127).a==0 and w.image.get_pixel(0,i).a==0 and w.image.get_pixel(127,i).a==0,"maximum geometry not clipped")
	print("PASS ",checks," warning checks");w.free();quit()
