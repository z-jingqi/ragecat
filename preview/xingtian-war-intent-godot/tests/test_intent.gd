extends SceneTree
const Effect = preload("res://components/battle_intent.gd")
const Profile = preload("res://components/intent_profile.gd")
const Canvas = preload("res://components/pixel_canvas.gd")
var failures: int = 0

func expect(ok:bool,message:String) -> void:
	if not ok: failures+=1; push_error(message)

func count(image:Image) -> int:
	var n:=0
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x,y).a>0.01:n+=1
	return n

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var fx=Effect.new(); root.add_child(fx); fx.play()
	expect(count(fx.get_frame())==0,"zero momentum must be empty")
	var counts:=[]
	for v in [0.25,0.6,1.0]: fx.set_momentum(v); counts.append(count(fx.get_frame()))
	expect(counts[0]>0 and counts[0]<counts[1] and counts[1]<counts[2],"coverage should grow with momentum")
	fx.seek(1.7); var a:PackedByteArray=fx.get_frame().get_data(); fx.seek(8.2); fx.seek(1.7)
	expect(a==fx.get_frame().get_data(),"seek must be deterministic")
	fx.clear(); fx.seek(1.0); fx.set_momentum(1.0); expect(count(fx.get_frame())==0,"clear must not resurrect")
	fx.play(); fx.set_momentum(NAN); expect(fx.momentum==0.0,"NaN input sanitizes")
	fx.set_momentum(7.0); expect(fx.momentum==1.0,"momentum clamps")
	fx.advance(-1.0); expect(fx.elapsed==0.0,"negative delta ignored")
	fx.play(Vector2(INF,0)); expect(not fx.active,"invalid origin stops")
	var p=Profile.new(); p.radius=INF; p.opacity=NAN
	fx.play(Vector2.ZERO,p); expect(fx.profile.radius==34.0 and fx.profile.opacity==0.88,"invalid profile sanitizes")
	expect(is_inf(p.radius) and is_nan(p.opacity),"caller profile is unchanged")
	fx.set_layer_enabled("ring",false); fx.set_layer_enabled("cracks",false); fx.set_momentum(1.0)
	expect(count(fx.get_frame())==0,"both disabled gives empty frame")
	fx.play(); fx.set_momentum(1.0); expect(count(fx.get_frame())==0,"play preserves layer switches")
	fx.set_layer_enabled("ring",true); expect(count(fx.get_frame())>0,"layer enable shows current moment")
	var other=Effect.new(); root.add_child(other); other.play(); other.set_momentum(0.3); other.seek(0.4)
	expect(fx.elapsed==0.0 and fx.momentum==1.0,"independent instances")
	fx.play(Vector2.ZERO,Resource.new()); expect(fx.profile is Profile,"wrong Resource safely defaults")
	fx.set_layer_enabled("cracks",true)
	# Review regression: at max radius/squash the old 144x104 image lost cracks.
	for seed_value in [1,19,37,65535]:
		var extreme=Profile.new(); extreme.radius=50; extreme.perspective=0.65; extreme.shape_seed=seed_value
		fx.play(Vector2.ZERO,extreme); fx.set_momentum(1.0)
		var wide=Canvas.new(Vector2i(320,288),Vector2(160,180))
		fx._ring(wide,1.0); fx._cracks(wide,1.0)
		var outside:=0
		for y in 288:
			for x in 320:
				if wide.image.get_pixel(x,y).a<=0:continue
				var native:Vector2=Vector2(x,y)-wide.anchor+Effect.ANCHOR
				if not Rect2(Vector2.ZERO,Vector2(Effect.SIZE)).has_point(native):outside+=1
		expect(outside==0,"max geometry must fit canvas for seed %d"%seed_value)
	fx.play()
	var scene=load("res://preview.tscn").instantiate(); root.add_child(scene); await process_frame; scene.set_process(false)
	scene.clear_all(); scene.timeline.value=2.0
	expect(not scene.main_fx.active,"UI seek cannot revive clear")
	scene.replay(); scene.timeline.value=2.0
	expect(scene.paused and scene.main_fx.active,"UI seek pauses after replay")
	scene.profile.radius=50; scene.profile.perspective=0.65; scene.replay()
	expect(scene.main_fx.get_parent().scale.x==2.0 and scene.samples[0].get_parent().scale.x==1.0,"large ground view backs off to integer zoom")
	scene.free()
	var output:=OS.get_environment("XINGTIAN_CAPTURE_DIR")
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		for i in range(9): fx.set_momentum(float(i)/8.0); fx.seek(1.0); fx.get_frame().save_png(output.path_join("intent-%02d.png"%i))
	fx.queue_free(); other.queue_free()
	print("BATTLE_INTENT_TESTS failures=",failures," coverage=",counts)
	quit(1 if failures else 0)
