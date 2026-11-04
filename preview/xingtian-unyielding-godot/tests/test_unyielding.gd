extends SceneTree
const Effect=preload("res://components/unyielding.gd")
const Profile=preload("res://components/unyielding_profile.gd")
const Canvas=preload("res://components/pixel_canvas.gd")
var failures:int=0

func expect(ok:bool,message:String) -> void:
	if not ok: failures+=1; push_error(message)

func count(image:Image) -> int:
	var n:=0
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x,y).a>0.01:n+=1
	return n

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var fx=Effect.new(); root.add_child(fx); fx.enter()
	expect(fx.get_phase()=="entry","entry phase")
	fx.seek(200.0); expect(fx.get_phase()=="holding" and count(fx.get_frame())>0,"no automatic revival")
	expect(fx.revive(),"host can confirm revival")
	expect(not fx.exhaust(),"second conflicting resolution rejected")
	fx.advance(0.4); expect(fx.get_phase()=="revival","revival phase")
	fx.advance(2.0); expect(fx.get_phase()=="finished" and count(fx.get_frame())==0,"revival finishes empty")
	fx.enter(); fx.seek(1.0); expect(fx.exhaust(),"explicit exhaustion accepted"); fx.advance(2.0)
	expect(count(fx.get_frame())==0 and fx.get_phase()=="finished","exhaustion finishes empty")
	fx.seek(0.2); var original:PackedByteArray=fx.get_frame().get_data(); fx.seek(1.4); fx.seek(0.2)
	expect(original==fx.get_frame().get_data(),"absolute seek repeatability")
	fx.clear(); fx.seek(0.2); expect(count(fx.get_frame())==0 and not fx.revive(),"clear cannot resurrect")
	fx.enter(Vector2(INF,0)); expect(not fx.active,"invalid origin blocks")
	var profile=Profile.new(); profile.aura_opacity=NAN; profile.radius=INF; profile.shard_count=999
	fx.enter(Vector2.ZERO,profile)
	expect(fx.profile.radius==32.0 and fx.profile.shard_count==24 and fx.profile.aura_opacity==0.36,"config sanitizes")
	expect(is_inf(profile.radius) and is_nan(profile.aura_opacity),"caller resource unchanged")
	fx.advance(-1.0); expect(fx.elapsed==0.0,"negative delta ignored")
	fx.enter(Vector2.ZERO,Resource.new()); expect(fx.profile is Profile,"wrong resource defaults")
	fx.seek(NAN); expect(fx.elapsed==0.0,"NaN time safe")
	for key in fx.layers: fx.set_layer_enabled(key,false)
	fx.seek(0.2); expect(count(fx.get_frame())==0,"all layers off empty")
	fx.enter(); fx.seek(0.2); expect(count(fx.get_frame())==0,"layer flags survive entry")
	for key in fx.layers: fx.set_layer_enabled(key,true)
	fx.seek(0.25); var blood_on:PackedByteArray=fx.get_frame().get_data(); fx.set_layer_enabled("blood",false)
	expect(blood_on!=fx.get_frame().get_data(),"blood toggle really affects pixels")
	fx.set_layer_enabled("blood",true)
	var other=Effect.new(); root.add_child(other); other.enter(); other.seek(0.75)
	expect(fx.elapsed==0.25 and other.outcome.is_empty(),"instances independent")
	var mask=Image.create(8,8,false,Image.FORMAT_RGBA8); mask.fill(Color.WHITE); var mask_before=mask.get_data()
	fx.set_body_mask(mask,Vector2(-4,-20)); expect(mask.get_data()==mask_before,"silhouette is not mutated")
	fx.set_body_mask(null)
	# Review regression: initial max-radius ring used to cross the lower edge.
	var extreme=Profile.new(); extreme.radius=44; extreme.perspective=0.65
	fx.enter(Vector2.ZERO,extreme)
	for seconds in [0.0,0.02,0.2,0.4]:
		fx.seek(seconds)
		var wide=Canvas.new(Vector2i(352,336),Vector2(176,240)); fx._ring(wide,1.0); fx._shards(wide,1.0)
		var outside:=0
		for y in 336:
			for x in 352:
				if wide.image.get_pixel(x,y).a<=0:continue
				var native:Vector2=Vector2(x,y)-wide.anchor+Effect.ANCHOR
				if not Rect2(Vector2.ZERO,Vector2(Effect.SIZE)).has_point(native):outside+=1
		expect(outside==0,"max entry geometry fits canvas at %.2f"%seconds)
	var scene=load("res://preview.tscn").instantiate(); root.add_child(scene); await process_frame; scene.set_process(false)
	scene.clear_all(); scene.timeline.value=3.0
	expect(not scene.success_fx.active and not scene.failure_fx.active,"UI scrub cannot revive clear")
	scene.automatic_outcome=false; scene.replay(false); scene.sample_at(100.0)
	expect(scene.success_fx.get_phase()=="holding","Hold preview remains pending")
	scene.success_fx.revive(); scene.failure_fx.exhaust(); scene.success_fx.advance(0.1); scene.failure_fx.advance(0.1)
	expect(scene.success_fx.get_phase()=="revival" and scene.failure_fx.get_phase()=="exhaustion","manual outcomes separate")
	scene.profile.radius=44; scene.profile.perspective=0.65; scene.replay()
	expect(scene.success_fx.get_parent().scale.x==2.0 and scene.samples[0].get_parent().scale.x==1.0,"large entry view stays within panels at integer zoom")
	scene.free()
	var output:=OS.get_environment("XINGTIAN_CAPTURE_DIR")
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		for branch in ["revival","exhaustion"]:
			fx.enter(); fx.seek(2.8); fx.revive() if branch=="revival" else fx.exhaust()
			var times:Array=[0.0,0.12,0.24,0.4,0.65,1.4,2.8,3.05,3.25,3.5,3.85,4.3]
			for i in range(times.size()): fx.seek(times[i]); fx.get_frame().save_png(output.path_join("%s-%02d.png"%[branch,i]))
	fx.queue_free(); other.queue_free(); print("UNYIELDING_TESTS failures=",failures); quit(1 if failures else 0)
