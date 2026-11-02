extends SceneTree
const Fx=preload("res://effects/VFX-20_shield_heal/support.gd")
var checks=0
func ok(v:bool)->void:
	assert(v);checks+=1
func _init()->void:call_deferred("run")
func run()->void:
	var f=Fx.new();root.add_child(f);f.automatic=false
	f.play(Vector2.ZERO,{"mode":"heal"});ok(f.config.body==Fx.HEAL_PALETTE.body);ok(f.config.core==Fx.HEAL_PALETTE.core);ok(f.config.edge==Fx.HEAL_PALETTE.edge)
	f.play(Vector2.ZERO);ok(f.config.body==Fx.DEFAULTS.body)
	for key in ["body","core","edge","plus"]:
		f.play(Vector2.ZERO,{"mode":"heal",key:"ff4400"});ok(f.config[key]=="ff4400")
	f.play(Vector2.ZERO,{"mode":"heal","core":"invalid"});ok(f.config.core==Fx.HEAL_PALETTE.core)
	f.play(Vector2.ZERO,{"mode":"heal","plus_count":999,"plus_size":999});ok(f.config.plus_count==8);ok(f.config.plus_size==5)
	f.play(Vector2.ZERO,{"mode":"heal","plus_count":-9,"plus_size":-9});ok(f.config.plus_count==0);ok(f.config.plus_size==1)
	var host=Node2D.new();root.add_child(host);host.position=Vector2(20,30)
	for mode in ["shield","heal"]:
		for rate in [30,60,144]:
			f.play(Vector2.ZERO,{"mode":mode},host,Vector2(1,2))
			for i in range(rate*4):f.tick(1.0/rate)
			ok(not f.active)
		for i in range(1000):
			f.play(Vector2.ZERO,{"mode":mode},host);f.tick(.1);ok(f.active);f.clear();ok(not f.active)
	f.play(Vector2.ZERO,{},host,Vector2(1,2));f.tick(.1);ok(f.anchor==Vector2(21,32));host.position=Vector2(42,13);f.tick(.1);ok(f.anchor==Vector2(43,15))
	f.hit(Vector2.RIGHT,99);ok(f.impact_strength==1);f.break_shield();ok(f.broken);f.tick(.5);ok(not f.active)
	f.play(Vector2.ZERO,{"mode":"heal"});f.break_shield();ok(not f.broken);f.stop();f.tick(.5);ok(not f.active)
	f.play(Vector2.ZERO,{"radius":999,"particles":999,"intensity":-4,"core":"bad_color","sustain":NAN});ok(f.config.radius==34);ok(f.config.particles==32);ok(f.config.intensity==0);ok(f.config.core==Fx.DEFAULTS.core);ok(f.config.sustain==Fx.DEFAULTS.sustain)
	f.tick(NAN);ok(f.elapsed==0);f.tick(-1);ok(f.elapsed==0)
	f.play(Vector2.ZERO,{},host);host.free();f.tick(.1);ok(not f.active)
	var n=[0];f.finished.connect(func():n[0]+=1)
	f.play(Vector2.ZERO);f.tick(100);f.tick(100);ok(n[0]==1)
	f.phase_changed.connect(func(p):if p=="sustain":f.clear())
	f.play(Vector2.ZERO);f.tick(.3);ok(not f.active)
	f.free()
	var g=Fx.new();root.add_child(g);g.automatic=false
	g.phase_changed.connect(func(p):if p=="exit":g.play(Vector2.ZERO,{"mode":"heal"}))
	g.play(Vector2.ZERO);g.tick(3);ok(g.active);ok(g.config.mode=="heal");ok(g.elapsed==0)
	g.free();print("SUPPORT CHECKS ",checks);quit()
