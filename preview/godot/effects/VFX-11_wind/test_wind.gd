extends SceneTree
const Wind=preload("res://effects/VFX-11_wind/wind.gd")
var checks:=0
func check(value:bool,message:String) -> void:
	checks+=1
	if not value:push_error(message);quit(1)
func _initialize() -> void:
	var f:=Wind.new();f.automatic=false;root.add_child(f)
	f.play(Vector2.ZERO)
	check(f.active,"starts")
	check(f.strength()==0,"zero start")
	f.tick(0.09);check(f.strength()>0 and f.strength()<1,"formation")
	f.tick(0.2);check(f.strength()==1,"sustain")
	f.stop();f.tick(0.1);check(f.active and f.strength()>0 and f.strength()<1,"stop drain")
	f.tick(1);check(not f.active,"stop clear")
	for fps in [30,60,144]:
		f.play(Vector2.ZERO)
		for i in range(fps):f.tick(1.0/fps)
		check(absf(f.age-1)<0.00001,"fps time")
		check(f.strength()==1,"fps plateau")
		f.tick(2);check(not f.active,"natural finish")
	for i in range(1000):
		f.play(Vector2(i,0),{"seed":i});f.tick(0.12)
		check(f.active and f.config.seed==i,"reuse seed")
		f.clear();check(not f.active and f.age==0,"clear")
	f.play(Vector2.ZERO,{"radius":999,"height":-1,"layers":99,"leaves":100,"width":-1,"enter":NAN,"core":"invalid"})
	check(f.config.radius==44 and f.config.height==20,"size clamp")
	check(f.config.layers==9 and f.config.leaves==24 and f.config.width==1,"capacity clamp")
	check(f.config.enter==0.18 and f.config.core==Wind.DEFAULTS.core,"invalid fallback")
	f.tick(-1);check(f.age==0,"negative dt")
	f.tick(NAN);check(f.age==0,"nan dt")
	f.play(Vector2.ZERO,{"clockwise":false,"leaves":0});f.tick(0.5)
	check(f.config.leaves==0 and not f.config.clockwise,"optional leaves/rotation")
	var p:=f.point_at(0.7,0.8,1)
	f.play(Vector2.ZERO,{"clockwise":false,"leaves":0});f.tick(0.5)
	check(p==f.point_at(0.7,0.8,1),"deterministic geometry")
	f.free();print("PASS ",checks," wind checks");quit()
