extends SceneTree
const Profile=preload("../components/slash_profile.gd")
const Arc=preload("../components/copper_arc.gd")
const Particles=preload("../components/hit_particles.gd")
var failures:=0
var checks:=0
var viewport:SubViewport
var arc
var drops
var results:Array=[]

func check(value:bool,message:String)->void:
	checks+=1
	if not value: failures+=1; push_error(message)

func _initialize()->void:
	call_deferred("run")

func capture(name_value:String)->Dictionary:
	await process_frame
	await RenderingServer.frame_post_draw
	var image:=viewport.get_texture().get_image()
	var count:=0; var partial:=0; var x0:=999; var x1:=-1; var y0:=999; var y1:=-1
	for y in image.get_height():
		for x in image.get_width():
			var color:=image.get_pixel(x,y)
			if color.a>0.0:
				count+=1; x0=mini(x0,x); x1=maxi(x1,x); y0=mini(y0,y); y1=maxi(y1,y)
				if color.a<1.0: partial+=1
	var folder:=OS.get_environment("XINGTIAN_CAPTURE_DIR")
	if not folder.is_empty(): image.save_png(folder.path_join(name_value+".png"))
	var record:Dictionary={"name":name_value,"pixels":count,"partial_alpha":partial,"bounds":[x0,y0,x1,y1],"hash":image.get_data().hex_encode().sha256_text()}
	results.append(record)
	return record

func run()->void:
	viewport=SubViewport.new(); viewport.size=Vector2i(256,256); viewport.transparent_bg=true; viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
	arc=Arc.new(); viewport.add_child(arc); drops=Particles.new(); drops.blood=true; viewport.add_child(drops)
	var p=Profile.new(); arc.play(Vector2(128,128),p)
	check((await capture("arc-zero")).pixels==0,"Arc begins empty")
	arc.seek(1.0/60.0); var onset=await capture("arc-onset")
	check(onset.pixels>0 and onset.partial_alpha==0,"First rendered frame is decisive and hard-pixel")
	arc.seek(0.07); var peak=await capture("arc-peak")
	check(peak.pixels>onset.pixels and peak.partial_alpha==0,"Full arc has more area than onset with no soft alpha")
	arc.seek(0.18); var tail=await capture("arc-tail")
	check(tail.pixels>0 and tail.pixels<peak.pixels,"Tail closes down")
	arc.seek(p.duration); check((await capture("arc-end")).pixels==0,"Arc ends exactly empty")
	arc.seek(0.07); var repeated=await capture("arc-repeated")
	check(repeated.hash==peak.hash,"Repeat seek renders identically")
	p.direction_degrees=168; arc.play(Vector2(128,128),p); arc.seek(0.07); var reverse=await capture("arc-left")
	check(reverse.bounds[2]<145 and reverse.bounds[0]<128,"Direction is respected on canvas grid")
	p=Profile.new(); p.radius=88; p.thickness=28; p.direction_degrees=90; arc.play(Vector2(128,128),p); arc.seek(0.07); var maximum=await capture("arc-max-vertical")
	check(maximum.pixels>peak.pixels and maximum.bounds[0]>30 and maximum.bounds[1]>30 and maximum.bounds[2]<226 and maximum.bounds[3]<226,"Maximum rotated range stays within the fixed quad")
	p=Profile.new(); p.intensity=0; arc.play(Vector2(128,128),p); arc.seek(0.07)
	check((await capture("arc-no-intensity")).pixels==0,"Zero intensity produces no pixels")
	p=Profile.new(); p.body_color=Color("44aaff"); arc.play(Vector2(128,128),p); arc.seek(0.07)
	check((await capture("arc-custom-color")).hash!=peak.hash,"Custom palette affects actual shader output")
	arc.clear(); p=Profile.new(); drops.play(Vector2(128,128),p); drops.seek(0.12); var blood=await capture("blood-default")
	check(blood.pixels>5 and blood.pixels<100 and blood.partial_alpha==0,"Blood remains sparse hard pixels")
	p.blood_count=0; drops.play(Vector2(128,128),p); drops.seek(0.12)
	check((await capture("blood-zero")).pixels==0,"Zero blood count is empty")
	p=Profile.new(); p.blood_count=20; p.blood_speed=160; p.blood_duration=0.8; drops.play(Vector2(128,128),p); drops.seek(0.36); var max_blood=await capture("blood-max")
	check(max_blood.pixels>0 and max_blood.pixels<200,"Blood max remains bounded")
	drops.clear(); drops.seek(0.12); check((await capture("blood-clear")).pixels==0,"Clear cannot redraw blood")
	var folder:=OS.get_environment("XINGTIAN_CAPTURE_DIR")
	if not folder.is_empty():
		var file:=FileAccess.open(folder.path_join("render-probe.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks":checks,"failures":failures,"cases":results},"  "))
	print("XINGTIAN_GPU: %d checks, %d failures"%[checks,failures])
	viewport.free(); quit(1 if failures else 0)
