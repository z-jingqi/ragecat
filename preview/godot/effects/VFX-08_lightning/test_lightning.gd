extends SceneTree
const Bolt=preload("res://effects/VFX-08_lightning/lightning.gd")
var count:=0
func check(value:bool,message:String) -> void:
	count+=1
	if not value:push_error(message);quit(1);assert(false,message)
func _initialize() -> void:
	var fx=Bolt.new();fx.automatic=false;root.add_child(fx)
	fx.play(Vector2(10,10),Vector2(10,100))
	check(fx.active,"active");check(fx.points[0]==Vector2(10,10),"start exact");check(fx.points[-1]==Vector2(10,100),"target exact")
	var p=fx.points.duplicate();var b=fx.forks.duplicate(true)
	fx.tick(0.05);check(fx.points==p and fx.forks==b,"geometry frozen")
	fx.replay();check(fx.points==p and fx.forks==b,"replay stable")
	fx.paused=true;fx.tick(1);check(fx.age==0,"pause");fx.paused=false
	fx.tick(-1);fx.tick(NAN);check(fx.age==0,"bad delta")
	fx.tick(1);check(not fx.active and fx.points.is_empty() and fx.forks.is_empty(),"expire fully")
	fx.play(Vector2.ZERO,Vector2.ZERO);check(not fx.active,"zero distance")
	fx.play(Vector2(NAN,0),Vector2(INF,0));check(not fx.active,"invalid endpoints")
	fx.play_direction(Vector2.ZERO,Vector2.ZERO,90);check(fx.target==Vector2(0,90),"direction fallback")
	fx.play(Vector2.ZERO,Vector2(0,99999));check(fx.target.length()==2048 and fx.points.size()<=65,"bounded length and count")
	var c=fx.clean({"width":NAN,"jitter":INF,"branches":999,"seed":-1,"hold":"bad","core":Color(1,0,0,0.1)})
	check(c.width==3.5 and c.jitter==10 and c.branches==4 and c.seed==0 and c.hold==0.065 and c.core.a==1,"sanitize")
	var values={"width":2,"seed":51}
	fx.play(Vector2.ZERO,Vector2(80,0),values);values.width=6;check(fx.config.width==2,"snapshot")
	for seed in range(1000):
		fx.play(Vector2.ZERO,Vector2.from_angle(seed*0.1)*100,{"seed":seed,"branches":seed%5})
		check(fx.points.size()<=65 and fx.forks.size()<=4,"bounded repeat")
		for q in fx.points:check(q.is_finite(),"finite geometry")
		var old=fx.points.duplicate();fx.tick(0.07);check(old==fx.points,"stable midstrike")
		fx.clear();check(not fx.active and fx.points.is_empty() and fx.forks.is_empty(),"clear")
	for fps in [30,60,144]:
		fx.play(Vector2.ZERO,Vector2(50,40))
		for k in range(fps):fx.tick(1.0/fps)
		check(not fx.active,"framerate clear")
	for angle in range(0,360,15):
		fx.play_direction(Vector2(5,7),Vector2.from_angle(deg_to_rad(angle)),73,{"jitter":0,"branches":0})
		check(fx.target.distance_to(Vector2(5,7))>72.99,"length and direction")
		check(fx.forks.is_empty(),"no forks")
	fx.play(Vector2.ZERO,Vector2(0,88))
	check(fx.duration==0.55,"composite duration")
	fx.tick(0.24);check(fx.active and fx.phase().strength==0,"aftermath without main bolt")
	fx.tick(0.32);check(not fx.active and fx.sparks.is_empty() and fx.smoke_seeds.is_empty() and fx.widths.is_empty(),"composite clears")
	fx.play(Vector2.ZERO,Vector2(0,88),{"spark_count":999,"branches":999,"smoke":false})
	check(fx.sparks.size()==12 and fx.forks.size()==4 and not fx.config.smoke,"layer bounds")
	for branch in fx.forks:check(branch.points.size()<=10,"branch point bound")
	var colors=fx.clean({"core":Color(NAN,0,0,1),"body":Color(9,-1,2,0.1)})
	check(colors.core==Color("f4f0e5") and colors.body==Color(1,0,1,1),"finite palette")
	print("LIGHTNING_CHECKS_PASS ",count)
	fx.free();quit()
