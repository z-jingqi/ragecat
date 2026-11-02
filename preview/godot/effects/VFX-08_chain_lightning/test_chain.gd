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
	check(Chain.DEFAULTS.width==1.25,"fine default width")
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
	check(fx.clean({"width":99}).width==3,"fine width maximum")
	var callback:=func(_t,_i):fx.clear()
	fx.target_hit.connect(callback);hits.clear();fx.play(Vector2(0,30),targets);fx.tick(1);check(hits.size()==1 and not fx.active,"reset from callback safe");fx.target_hit.disconnect(callback)
	# Arrival and overlap are temporal contracts, not a single-frame on/off flash.
	hits.clear();fx.play(Vector2(0,30),targets)
	fx.tick(0.03);check(hits.is_empty(),"no hit before visible tip arrival")
	check(fx.links[0].bolt.phase().reach>0 and fx.links[0].bolt.phase().reach<1,"partial first link")
	fx.tick(0.035);check(hits.size()==1,"hit at attack end")
	fx.tick(0.04);check(fx.links.size()==2 and fx.links[0].bolt.active,"old residue overlaps next jump")
	hits.clear();fx.play(Vector2(0,30),targets,{"attack":0.08,"jump_interval":0.04})
	fx.tick(0.06);check(fx.launched==1 and hits.is_empty(),"jump waits for arrival when attack exceeds interval")
	fx.tick(0.02);check(fx.launched==2 and hits.size()==1,"next link starts only after prior hit")
	check(fx.clean({"decay":99}).decay==0.25,"decay bound matches shared renderer")
	fx.play(Vector2(0,30),targets,{"max_targets":1});fx.tick(0.03)
	var bolt=fx.links[0].bolt
	check(bolt.branch_reach(bolt.forks[0])<1,"branch grows after root instead of full flash")
	fx.tick(0.17)
	var window:Vector2=bolt.segment_window(0,bolt.points.size()-1,bolt.phase().cooldown)
	check(window.y-window.x>0 and window.y-window.x<1,"late main segment contracts before removal")
	fx.tick(1);check(not fx.active and fx.get_child_count()==0,"temporal residue fully cleaned")
	for i in range(1000):
		fx.play(Vector2(0,30),targets,{"seed":i});fx.tick(2);check(not fx.active and fx.links.is_empty(),"reuse cleanup")
	stage.free();print("CHAIN_CHECKS_PASSED ",checks);quit(1 if failed else 0)
