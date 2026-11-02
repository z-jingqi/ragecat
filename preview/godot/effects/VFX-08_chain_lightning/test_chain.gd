extends SceneTree
const Chain=preload("res://effects/VFX-08_chain_lightning/chain.gd")
var checks:=0
var failed:=false
var hits:Array=[]
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failed=true;push_error(message)
func _initialize()->void:call_deferred("run")
func run()->void:
	var data=JSON.parse_string(FileAccess.get_file_as_string("res://effects/VFX-08_chain_lightning/presets.json"))
	for key in Chain.DEFAULTS:check(data.defaults[key]==Chain.DEFAULTS[key],"default config parity "+key)
	var stage:=Node2D.new();root.add_child(stage)
	var fx:=Chain.new();fx.automatic=false;stage.add_child(fx)
	var targets:Array=[]
	for i in range(8):
		var n:=Node2D.new();n.position=Vector2(20+i*20,30);stage.add_child(n);targets.append(n)
	fx.target_hit.connect(func(t,index):hits.append([t,index]))
	for hz in [30,60,144]:
		hits.clear();fx.play(Vector2(0,30),targets,{"max_targets":5,"jump_range":30})
		for i in range(hz*2):fx.tick(1.0/hz);check(fx.links.size()<=5,"bounded links")
		check(hits.size()==5,"five exact hits at any fps");check(not fx.active,"complete");check(fx.get_child_count()==0,"no stale child")
		for i in range(5):check(hits[i][0]==targets[i] and hits[i][1]==i,"nearest order")
	fx.play(Vector2(0,30),targets);var geometry=fx.links[0].base.duplicate();fx.clear();fx.play(Vector2(0,30),targets);check(fx.links[0].base==geometry,"seed repeat")
	fx.paused=true;fx.tick(1);check(fx.age==0,"pause");fx.paused=false
	targets[0].position+=Vector2(3,5);fx.tick(0.01);check(fx.links[0].bolt.points[-1].distance_to(targets[0].position)<0.001,"endpoint follows")
	targets[0].position=Vector2(20,30)
	hits.clear();fx.play(Vector2(0,30),targets,{"jump_range":1});fx.tick(1);check(hits.is_empty() and not fx.active,"out of range")
	hits.clear();fx.play(Vector2(0,30),[targets[0],targets[0],null,5],{"max_targets":12});fx.tick(2);check(hits.size()==1,"duplicates and invalid candidates")
	hits.clear();var doomed:=Node2D.new();doomed.position=Vector2(10,30);stage.add_child(doomed);fx.play(Vector2(0,30),[doomed]);doomed.free();fx.tick(1);check(hits.is_empty() and not fx.active,"destroyed target no hit")
	fx.play(Vector2(0,30),targets);fx.clear();fx.tick(100);check(not fx.active and fx.links.is_empty(),"clear stable")
	hits.clear();fx.play(Vector2(0,30),targets);fx.tick(10);check(hits.size()==5,"large delta preserves all events")
	check(fx.clean({"jump_interval":NAN,"max_targets":100,"width":-10}).max_targets==12,"clamp count")
	check(fx.clean({"jump_interval":NAN}).jump_interval==Chain.DEFAULTS.jump_interval,"nan fallback")
	var callback:=func(_t,_i):fx.clear()
	fx.target_hit.connect(callback);hits.clear();fx.play(Vector2(0,30),targets);fx.tick(1);check(hits.size()==1 and not fx.active,"reset from callback safe");fx.target_hit.disconnect(callback)
	for i in range(1000):
		fx.play(Vector2(0,30),targets,{"seed":i});fx.tick(2);check(not fx.active and fx.links.is_empty(),"reuse cleanup")
	stage.free();print("CHAIN_CHECKS_PASSED ",checks);quit(1 if failed else 0)
