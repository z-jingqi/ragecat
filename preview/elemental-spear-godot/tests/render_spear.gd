extends SceneTree
const P=preload("../components/spear_profile.gd")
const Layer=preload("../components/stage_layer.gd")
const Effect=preload("../components/elemental_spear.gd")
var view:SubViewport
var layer
var checks=0
var failures=0
var records=[]
var element=0
var folder=""
func _initialize()->void: call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func capture(name_value:String)->Image:
	await process_frame; await RenderingServer.frame_post_draw
	var img=view.get_texture().get_image()
	if not folder.is_empty(): img.save_png(folder.path_join(name_value+".png"))
	return img
func measure(img:Image)->Dictionary:
	var count=0; var x0=999; var x1=-1; var y0=999; var y1=-1; var light=0.0
	for y in img.get_height():
		for x in img.get_width():
			var c=img.get_pixel(x,y)
			if c.a>.001:
				count+=1; x0=mini(x0,x); x1=maxi(x1,x); y0=mini(y0,y); y1=maxi(y1,y); light+=c.r+c.g+c.b
	return {"pixels":count,"x0":x0,"x1":x1,"y0":y0,"y1":y1,"light":light,"hash":img.get_data().hex_encode().sha256_text()}
func snap(name_value:String)->Dictionary:
	var result=measure(await capture(name_value)); result.name=name_value; records.append(result); return result
func run()->void:
	folder=OS.get_environment("SPEAR_CAPTURE_DIR")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--element="): element=clampi(int(arg.split("=")[1]),0,2)
	view=SubViewport.new(); view.size=Vector2i(380,330); view.transparent_bg=true; view.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(view)
	layer=Layer.new(); view.add_child(layer)
	var p=P.new()
	for key in P.PHASES: p.phase(key).element=element
	for key in P.PHASES:
		layer.play(Vector2(190,260),p,key); layer.seek(p.phase_duration(key)*.5)
		var first=await snap(key)
		check(first.pixels>4,key+" is visible at game scale")
		layer.seek(p.phase_duration(key)*.5); check((await snap(key+"-repeat")).hash==first.hash,key+" seek is deterministic")
		layer.seek(p.phase_duration(key)); check((await snap(key+"-end")).pixels==0,key+" is empty at endpoint")
		layer.clear(); layer.seek(.1); check((await snap(key+"-clear")).pixels==0,key+" clear stays empty")
	layer.play(Vector2(190,260),p,"form"); layer.seek(.1); var early=await snap("form-early")
	layer.seek(.49); var late=await snap("form-late"); check(late.y1-late.y0>early.y1-early.y0,"Double spear visibly extends")
	layer.play(Vector2(190,260),p,"field"); layer.seek(1.1); var standard=await snap("field-default")
	p.field_radius=88; layer.play(Vector2(190,260),p,"field"); layer.seek(1.1); var bigger=await snap("field-large")
	check(bigger.x1-bigger.x0>standard.x1-standard.x0,"Field radius changes footprint")
	p.field.intensity=.4; layer.play(Vector2(190,260),p,"field"); layer.seek(1.1); var dim=await snap("field-dim")
	check(dim.light<bigger.light,"Intensity changes rendered brightness")
	p.field.intensity=0; layer.play(Vector2(190,260),p,"field"); layer.seek(1.1); check((await snap("field-off")).pixels==0,"Zero intensity is completely empty")
	p.field.intensity=1; p.field.tint=Color("66d6ed"); layer.play(Vector2(190,260),p,"field"); layer.seek(1.1); check((await snap("field-tint")).hash!=bigger.hash,"Per-stage color changes rendered pixels")
	p.field.tint=Color.WHITE; p.field.size=.5; layer.play(Vector2(190,260),p,"field"); layer.seek(1.1); check((await snap("field-small")).pixels<bigger.pixels,"Per-stage size changes geometry")
	p=P.new()
	for key in P.PHASES: p.phase(key).element=element
	layer.play(Vector2(190,260),p,"dissolve"); layer.seek(.1); var before=await snap("fade-early")
	layer.seek(.82); var after=await snap("fade-late"); check(after.light<before.light,"Dissolve reduces residual brightness")
	layer.free()
	var effect=Effect.new(); view.add_child(effect); effect.play(Vector2(190,260),p)
	effect.seek(p.contact_time()+.1); check((await snap("composed-contact")).pixels>10,"Impact and field compose")
	effect.set_stage_enabled("impact",false); effect.set_stage_enabled("field",false); check((await snap("composed-off")).pixels==0,"Stage toggles independently empty composition")
	effect.play(Vector2(190,260),p); effect.seek(p.total_duration()); check((await snap("composed-finished")).pixels==0,"Complete composite cleans itself")
	view.free()
	var scene=load("res://preview.tscn").instantiate(); root.add_child(scene); scene.set_process(false); scene.select_element(element); scene.seek_all(scene.profile.contact_time()+1)
	await process_frame; await RenderingServer.frame_post_draw
	var ui=root.get_texture().get_image()
	if not folder.is_empty(): ui.save_png(folder.path_join("workshop.png"))
	var mismatch=0
	for y in 260:
		for x in 300:
			if ui.get_pixel(167+x,245+y)!=ui.get_pixel(650+x*2,108+y*2): mismatch+=1
	check(mismatch<20,"Native 1x and 2x show same actual frame without interpolation")
	scene.clear_all(); scene.sliders.field_radius.value=75; scene.seek_all(2); scene.paused=false; scene._process(.1)
	check(scene.effects[0].cleared and scene.effects[1].cleared,"Clear persists through native UI parameter/replay-clock edits")
	scene.replay(); check(not scene.effects[0].cleared,"Native UI Replay recovers")
	if not folder.is_empty():
		var file=FileAccess.open(folder.path_join("render-results.json"),FileAccess.WRITE); file.store_string(JSON.stringify({"element":element,"checks":checks,"failures":failures,"cases":records},"  "))
	scene.free(); print("ELEMENTAL_SPEAR_GPU: element %d, %d checks, %d failures"%[element,checks,failures]); quit(1 if failures else 0)
