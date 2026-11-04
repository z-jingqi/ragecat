extends SceneTree
const Profile=preload("../components/slash_profile.gd")
const Impact=preload("../components/hit_impact.gd")
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
	var flipped:Image=image.duplicate(); flipped.flip_x()
	var record:Dictionary={"flipped_hash":flipped.get_data().hex_encode().sha256_text(),"name":name_value,"pixels":count,"partial_alpha":partial,"bounds":[x0,y0,x1,y1],"hash":image.get_data().hex_encode().sha256_text()}
	results.append(record)
	return record

func run()->void:
	viewport=SubViewport.new(); viewport.size=Vector2i(256,256); viewport.transparent_bg=true; viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
	arc=Arc.new(); viewport.add_child(arc); drops=Particles.new(); drops.blood=true; viewport.add_child(drops)
	var p=Profile.new(); p.glow_strength=0; arc.play(Vector2(128,128),p)
	check((await capture("arc-zero")).pixels==0,"Arc begins empty")
	arc.seek(1.0/60.0); var onset=await capture("arc-onset")
	check(onset.pixels>0 and onset.partial_alpha==0,"First rendered frame is decisive and hard-pixel")
	arc.seek(0.07); var peak=await capture("arc-peak")
	check(peak.pixels>onset.pixels and peak.partial_alpha==0,"Full arc has more area than onset with no soft alpha")
	arc.seek(0.24); var tail=await capture("arc-tail")
	check(tail.pixels>0 and tail.pixels<peak.pixels,"Tail closes down")
	arc.seek(p.duration+0.04); check((await capture("arc-thread")).pixels>0,"Residual thread follows the main blade")
	arc.seek(p.duration+p.thread_duration); check((await capture("arc-end")).pixels==0,"Arc and thread end exactly empty")
	arc.seek(0.07); var repeated=await capture("arc-repeated")
	check(repeated.hash==peak.hash,"Repeat seek renders identically")
	p.facing_left=true; arc.play(Vector2(128,128),p); arc.seek(0.07); var reverse=await capture("arc-left")
	check(reverse.hash==peak.flipped_hash,"Horizontal facing is respected on canvas grid")
	p=Profile.new(); p.glow_strength=0; p.radius=88; p.thickness=28; p.direction_degrees=90; arc.play(Vector2(128,128),p); arc.seek(0.07); var maximum=await capture("arc-max-vertical")
	check(maximum.pixels>peak.pixels and maximum.bounds[0]>16 and maximum.bounds[1]>16 and maximum.bounds[2]<240 and maximum.bounds[3]<240,"Maximum rotated range stays within the fixed quad")
	p=Profile.new(); p.intensity=0; arc.play(Vector2(128,128),p); arc.seek(0.07)
	check((await capture("arc-no-intensity")).pixels==0,"Zero intensity produces no pixels")
	p=Profile.new(); p.glow_strength=0; p.body_color=Color("44aaff"); arc.play(Vector2(128,128),p); arc.seek(0.07)
	check((await capture("arc-custom-color")).hash!=peak.hash,"Custom palette affects actual shader output")
	p=Profile.new(); p.glow_strength=0; p.echo_enabled=false; arc.play(Vector2(128,128),p); arc.seek(0.07)
	check((await capture("arc-no-echo")).pixels<peak.pixels,"Inner echo is a separate optional silhouette")
	p=Profile.new(); arc.play(Vector2(128,128),p); arc.seek(0.07)
	check((await capture("arc-with-light")).partial_alpha>0,"Warm light is restrained and independent of hard palette bands")
	p=Profile.new(); p.glow_strength=0; p.glint_enabled=false; arc.play(Vector2(128,128),p); arc.seek(0.07)
	check((await capture("arc-no-glint")).hash!=peak.hash,"Blade glint can be disabled independently")
	p=Profile.new(); p.thread_enabled=false; arc.play(Vector2(128,128),p); arc.seek(p.duration+0.04)
	check((await capture("arc-no-thread")).pixels==0,"Thread toggle clears the residual line")
	arc.clear(); p=Profile.new(); drops.play(Vector2(128,128),p); drops.seek(0.12); var blood=await capture("blood-default")
	check(blood.pixels>5 and blood.pixels<100 and blood.partial_alpha==0,"Blood remains sparse hard pixels")
	p.blood_count=0; drops.play(Vector2(128,128),p); drops.seek(0.12)
	check((await capture("blood-zero")).pixels==0,"Zero blood count is empty")
	p=Profile.new(); p.blood_count=20; p.blood_speed=160; p.blood_duration=0.8; drops.play(Vector2(128,128),p); drops.seek(0.36); var max_blood=await capture("blood-max")
	check(max_blood.pixels>0 and max_blood.pixels<200,"Blood max remains bounded")
	drops.clear(); drops.seek(0.12); check((await capture("blood-clear")).pixels==0,"Clear cannot redraw blood")
	var impact=Impact.new(); viewport.add_child(impact); p=Profile.new(); impact.play(Vector2(128,128),p)
	check((await capture("hit-zero")).pixels==0,"Contact starts empty before the first advance")
	impact.seek(0.012); var impact_first=await capture("hit-core")
	check(impact_first.pixels>40 and impact_first.pixels<250 and impact_first.partial_alpha==0,"Compact first-beat core has hard opaque pixels")
	impact.seek(0.025); var impact_second=await capture("hit-core-stretched")
	check(impact_second.hash!=impact_first.hash and impact_second.pixels<impact_first.pixels,"Second beat stretches and thins instead of lingering")
	impact.seek(0.065); var shards=await capture("hit-fragments")
	check(shards.pixels>8 and shards.pixels<impact_first.pixels,"Contact breaks into sparse copper fragments")
	impact.seek(0.15); var closing=await capture("hit-late")
	check(closing.pixels<shards.pixels,"Detached fragments thin and clean up")
	impact.seek(p.impact_duration); check((await capture("hit-end")).pixels==0,"Impact ends exactly empty")
	impact.seek(0.012); check((await capture("hit-repeat")).hash==impact_first.hash,"Impact replay is deterministic")
	p.facing_left=true; impact.play(Vector2(128,128),p); impact.seek(0.012)
	check((await capture("hit-left")).hash==impact_first.flipped_hash,"Impact is exact horizontal reflection")
	p=Profile.new(); p.impact_radius=24; p.pixel_size=3; impact.play(Vector2(128,128),p); impact.seek(0.08); var largest=await capture("hit-largest")
	check(largest.pixels>0 and largest.bounds[0]>64 and largest.bounds[2]<192,"Largest impact stays bounded at a three-pixel grid")
	p=Profile.new(); p.impact_enabled=false; impact.play(Vector2(128,128),p); impact.seek(0.012)
	check((await capture("hit-disabled")).pixels==0,"Impact profile toggle is fully empty")
	impact.clear(); p=Profile.new(); drops.play(Vector2(128,128),p); drops.seek(0.035); var spray=await capture("blood-short-filaments")
	check(spray.pixels>5 and spray.pixels<120,"Early blood fan is restrained")
	p.facing_left=true; drops.play(Vector2(128,128),p); drops.seek(0.035)
	check((await capture("blood-filaments-left")).hash==spray.flipped_hash,"Early blood fan mirrors complete pixel cells")
	p.blood_enabled=false; drops.play(Vector2(128,128),p); drops.seek(0.035)
	check((await capture("blood-all-disabled")).pixels==0,"Blood toggle also clears filaments")
	var folder:=OS.get_environment("XINGTIAN_CAPTURE_DIR")
	if not folder.is_empty():
		var file:=FileAccess.open(folder.path_join("render-probe.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks":checks,"failures":failures,"cases":results},"  "))
	print("XINGTIAN_GPU: %d checks, %d failures"%[checks,failures])
	viewport.free(); quit(1 if failures else 0)
