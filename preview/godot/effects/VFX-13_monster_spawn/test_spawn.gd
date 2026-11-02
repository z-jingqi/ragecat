extends SceneTree
const Spawn=preload("res://effects/VFX-13_monster_spawn/spawn.gd")
const Lab=preload("res://effects/VFX-13_monster_spawn/lab.gd")
var checks:=0
var failures:=0
var appeared_count:=0
var completed_count:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,description:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(description)
func run()->void:
	var fx:=Spawn.new();root.add_child(fx)
	var body:=Sprite2D.new();root.add_child(body);body.visible=false;fx.host=body
	var original:=CanvasItemMaterial.new();body.material=original
	fx.appeared.connect(func():appeared_count+=1)
	fx.completed.connect(func():completed_count+=1)
	for fps in [30,60,144]:
		for duration in [0.18,0.55,2.0]:
			fx.configure({"duration":duration});appeared_count=0;completed_count=0;body.visible=false;fx.play()
			check(body.visible and body.material!=original,"bound host receives private material")
			var frames:=0
			while fx.active and frames<1000:fx.tick(1.0/fps);frames+=1
			check(not fx.active and fx.knots.is_empty(),"finished removes transient effect")
			check(appeared_count==1 and completed_count==1,"exactly once events")
			check(body.material==original and body.visible,"completed restores original material and reveals host")
			check(absf(frames/float(fps)-duration)<=1.0/fps+0.00001,"frame rate independent duration")
			fx.tick(1);check(completed_count==1,"finished tick is inert")
	fx.configure({"duration":0.55,"seed":42});body.visible=false;fx.play();var a:=fx.knots.duplicate(true);fx.cancel()
	check(not body.visible and body.material==original,"cancel before appearance restores hidden state")
	fx.play();check(fx.knots==a,"same seed reproduces entire schedule");fx.tick(0.1)
	var saved_age:float=fx.age;fx.tick(-1);fx.tick(NAN);fx.tick(INF);check(fx.age==saved_age,"invalid timestep ignored")
	fx.configure({"radius":55});check(fx.radius==29,"configuration immutable during playback")
	fx.cancel();fx.configure({"seed":43});fx.play();check(fx.knots!=a,"different seed changes particles");fx.cancel()
	body.visible=true;fx.play();fx.tick(0.4);fx.cancel();check(body.visible and body.material==original,"cancel restores preexisting visible host")
	fx.configure({"duration":NAN,"radius":INF,"particle_count":10000,"reveal_at":0.99,"reveal_span":5,"ring_width":-3,"palette":["bad!","ffffff","000000"]})
	check(is_finite(fx.duration) and is_finite(fx.radius),"nonfinite settings rejected")
	check(fx.particle_count==32 and fx.ring_width==1,"geometry bounds")
	check(fx.reveal_at+fx.reveal_span<=0.90001,"reveal ends before cleanup")
	fx.configure({"particle_count":0});fx.play();check(fx.knots.is_empty(),"zero particles is valid");fx.cancel()
	for i in range(1000):
		fx.configure({"seed":i,"particle_count":32});fx.play();check(fx.knots.size()==32,"bounded reuse allocations");fx.tick(0.05);fx.cancel();check(fx.knots.is_empty() and not fx.owns_host,"cancel cleans ownership and particles")
	fx.host=null;fx.play();fx.tick(9);check(not fx.active,"ring-only without host supported")
	fx.host=body;body.visible=false;fx.play();body.free();fx.tick(0.4);fx.cancel();check(not fx.owns_host,"freed host safe")
	var other:=Spawn.new();root.add_child(other);other.appeared.connect(func():other.cancel());other.play();other.tick(99);check(not other.active,"callback cancellation wins")
	other.free();fx.free()
	var lab:=Lab.new();root.add_child(lab);lab.set_process(false)
	lab.toggle_pause();check(lab.paused,"pause control")
	lab.step_frame();check(lab.effects[0].age>0,"step advances paused effect")
	lab.palette_toggle();check(lab.palette_index==1,"palette preset")
	lab.cancel();check(not lab.effects[0].active and not lab.looping,"cancel control")
	lab.reset_all();check(not lab.paused and lab.looping and lab.palette_index==0,"reset all defaults")
	lab.free()
	print("VFX-13: ",checks," state, lifecycle, boundary and UI checks; failures=",failures)
	quit(1 if failures>0 else 0)
