extends SceneTree
const Heavy=preload("../components/heavy_profile.gd")
const Pressure=preload("../components/heavy_pressure.gd")
var view:SubViewport
var wave
var checks:=0
var failures:=0
var records:Array=[]
const ARENA=Rect2i(24,140,656,430)
func _initialize()->void: call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func capture(name_value:String,target:Viewport)->Image:
	await process_frame
	await RenderingServer.frame_post_draw
	var result:=target.get_texture().get_image()
	var folder:=OS.get_environment("XINGTIAN_HEAVY_CAPTURE_DIR")
	if not folder.is_empty(): result.save_png(folder.path_join(name_value+".png"))
	return result
func measure(image:Image)->Dictionary:
	var count:=0; var partial:=0; var x0:=999; var x1:=-1; var y0:=999; var y1:=-1; var light:=0.
	for y in image.get_height():
		for x in image.get_width():
			var c:=image.get_pixel(x,y)
			if c.a>0:
				count+=1; x0=mini(x0,x); x1=maxi(x1,x); y0=mini(y0,y); y1=maxi(y1,y); light+=c.r+c.g+c.b
				if c.a<1: partial+=1
	return {"pixels":count,"partial":partial,"x0":x0,"x1":x1,"y0":y0,"y1":y1,"brightness":light,"hash":image.get_data().hex_encode().sha256_text()}
func snap(name_value:String)->Dictionary:
	var result:=measure(await capture(name_value,view)); result.name=name_value; records.append(result); return result
func difference(a:Image,b:Image,rect:Rect2i)->int:
	var count:=0
	for y in range(rect.position.y,rect.end.y):
		for x in range(rect.position.x,rect.end.x):
			if a.get_pixel(x,y)!=b.get_pixel(x,y): count+=1
	return count
func run()->void:
	view=SubViewport.new(); view.size=Vector2i(300,220); view.transparent_bg=true; view.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(view)
	wave=Pressure.new(); view.add_child(wave); var p=Heavy.new(); wave.play(Vector2(150,110),p)
	check((await snap("wave-zero")).pixels==0,"Wave is empty before the first advance")
	wave.seek(1./60.); var first:=await snap("wave-first")
	check(first.pixels>20 and first.partial==0,"Early wave is readable hard pixels at 1x")
	wave.seek(.08); var peak_image:=await capture("wave-peak",view); var peak:=measure(peak_image)
	check(peak.pixels>first.pixels,"Ground wave expands before thinning")
	wave.seek(.28); var tail:=await snap("wave-tail"); check(tail.pixels<peak.pixels,"Ground wave breaks down promptly")
	wave.seek(.32); check((await snap("wave-end")).pixels==0,"Default wave ends exactly at 320ms")
	wave.seek(.08); check((await snap("wave-repeat")).hash==peak.hash,"Repeated seek renders identical pixels")
	p.facing_left=true; wave.play(Vector2(150,110),p); wave.seek(.08); var flip:Image=peak_image.duplicate(); flip.flip_x()
	check((await snap("wave-mirror")).hash==measure(flip).hash,"Full ring and grit reflect exact pixel cells")
	p=Heavy.new(); p.pressure_radius=112; wave.play(Vector2(150,110),p); wave.seek(.08); var larger:=await snap("wave-large")
	check(larger.x1-larger.x0>peak.x1-peak.x0,"Radius control changes rendered horizontal reach")
	p=Heavy.new(); p.pressure_duration=.6; wave.play(Vector2(150,110),p); wave.seek(.32); check((await snap("wave-long")).pixels>20,"Duration changes the actual last visible frame")
	p=Heavy.new(); p.pressure_strength=.4; wave.play(Vector2(150,110),p); wave.seek(.08); var dim:=await snap("wave-dim")
	check(dim.pixels==peak.pixels and dim.brightness<peak.brightness,"Strength changes brightness without multiplying geometry")
	p.pressure_strength=0; wave.play(Vector2(150,110),p); wave.seek(.08); check((await snap("wave-strength-zero")).pixels==0,"Strength zero suppresses ring and grit")
	p=Heavy.new(); p.pressure_color=Color("50bdde"); wave.play(Vector2(150,110),p); wave.seek(.08); var tint:=await snap("wave-color")
	check(tint.hash!=peak.hash and tint.pixels==peak.pixels,"RGB color changes pixels without changing footprint")
	p=Heavy.new(); p.pressure_thickness=6; wave.play(Vector2(150,110),p); wave.seek(.08); check((await snap("wave-thick")).pixels>peak.pixels,"Width independently changes visible area")
	p=Heavy.new(); p.pressure_squash=.2; wave.play(Vector2(150,110),p); wave.seek(.08); var flat:=await snap("wave-flat")
	check(flat.y1-flat.y0<peak.y1-peak.y0,"Squash changes actual vertical footprint")
	p=Heavy.new(); p.debris_count=0; wave.play(Vector2(150,110),p); wave.seek(.08); check((await snap("wave-no-grit")).pixels<peak.pixels,"Grit count is visibly independent")
	p=Heavy.new(); p.pressure_radius=112; p.pressure_squash=.7; p.pressure_thickness=6; p.debris_count=16; p.pixel_size=3
	wave.play(Vector2(150,110),p); wave.seek(.18); var maximum:=await snap("wave-max-grid")
	check(maximum.x0>12 and maximum.x1<288 and maximum.y0>12 and maximum.y1<208,"Maximum radius thickness squash and grid stay bounded")
	wave.clear(); wave.seek(.08); check((await snap("wave-clear")).pixels==0,"Clear cannot resurrect the wave")
	view.free()
	var scene=load("res://heavy_preview.tscn").instantiate(); root.add_child(scene); scene.set_process(false)
	for mode in [1,2,3]:
		scene.select_scenario(mode); scene.seek_all(0); var base:=await capture("stage-%d-empty"%mode,root)
		scene.seek_all(.655); var active:=await capture("stage-%d-active"%mode,root)
		check(difference(base,active,ARENA)>200,"Heavy stage %d is visible at game scale"%mode)
		var union:=0; var matched:=0
		for dy in range(-110,80):
			for dx in range(-125,125):
				var a:=Vector2i(334+dx,386+dy); var b:=Vector2i(980+dx*2,386+dy*2)
				var da:=active.get_pixelv(a)!=base.get_pixelv(a); var db:=active.get_pixelv(b)!=base.get_pixelv(b)
				if da or db: union+=1; matched+=int(da==db)
		check(float(matched)/maxi(1,union)>.95,"Stage %d 2x is the same pixel footprint"%mode)
		if mode<3:
			scene.stage.set_wave(false); scene.detail.set_wave(false)
			check(difference(active,await capture("cleave-%d-wave-toggle"%mode,root),ARENA)==0,"Cleave pixels do not depend on the ground wave toggle")
		else:
			scene.stage.set_blood(false); scene.detail.set_blood(false)
			check(difference(active,await capture("ground-no-blood" ,root),ARENA)==0,"Independent wave never adds blood")
			scene.stage.set_wave(false); scene.detail.set_wave(false)
			check(difference(base,await capture("ground-wave-off",root),ARENA)==0,"Ground wave off leaves only the fixture and strike marker")
		scene.stage.set_wave(true); scene.detail.set_wave(true)
		scene.clear_all(); scene.paused=false; scene._process(4)
		check(difference(base,await capture("stage-%d-clear"%mode,root),ARENA)==0,"Stage %d Clear survives Resume"%mode)
	scene.select_scenario(3); scene.sliders.pressure_radius.value=112; scene.sliders.pressure_thickness.value=6; scene.sliders.pressure_squash.value=.7; scene.sliders.pressure_duration.value=.6; scene.sliders.debris_count.value=16; scene.profile.pixel_size=3; scene.rebuild()
	for left in [false,true]:
		scene.stage.set_facing(left); scene.detail.set_facing(left); scene.seek_all(0); var base:=await capture("max-%s-empty"%left,root)
		scene.seek_all(1.025); var active:=await capture("max-%s-active"%left,root)
		var edge:=difference(base,active,Rect2i(704,140,2,430))+difference(base,active,Rect2i(1254,140,2,430))+difference(base,active,Rect2i(704,140,552,2))+difference(base,active,Rect2i(704,568,552,2))
		check(edge==0,"Maximum wave does not hit magnified panel edges facing %s"%left)
	scene.wave_button.button_pressed=false; scene.seek_all(.83); await capture("stage-wave-off",root)
	scene.clear_all(); scene.sliders.pressure_strength.value=0; scene.color_button.color_changed.emit(Color("50bdde")); check(scene.stage.cleared,"Parameter edits keep a cleared native scene empty")
	var folder:=OS.get_environment("XINGTIAN_HEAVY_CAPTURE_DIR")
	if not folder.is_empty():
		var file:=FileAccess.open(folder.path_join("heavy-render.json"),FileAccess.WRITE); file.store_string(JSON.stringify({"checks":checks,"failures":failures,"cases":records},"  "))
	scene.free(); print("XINGTIAN_HEAVY_GPU: %d checks, %d failures"%[checks,failures]); quit(1 if failures else 0)
