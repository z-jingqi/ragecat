extends SceneTree
const FX=preload("../components/radial_spikes.gd")
const Character=preload("../character.gd")
var count:int=0
var failures:int=0
var vp:SubViewport
var fx:Node2D
func check(ok:bool,label:String)->void:
	count+=1
	if not ok: failures+=1; push_error(label)
func _initialize()->void: call_deferred("run")
func render()->Image:
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	return vp.get_texture().get_image()
func pixels(im:Image)->int:
	var total:int=0
	for y in im.get_height():
		for x in im.get_width():
			if im.get_pixel(x,y).a>.02: total+=1
	return total
func run()->void:
	if DisplayServer.get_name()=="headless": push_error("Real renderer required"); quit(2); return
	var folder:String=OS.get_environment("RADIAL_CAPTURE_DIR")
	vp=SubViewport.new(); vp.size=Vector2i(360,240); vp.transparent_bg=true; vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(vp)
	var stage:Node2D=Node2D.new(); stage.y_sort_enabled=true; vp.add_child(stage)
	fx=FX.new(); stage.add_child(fx)
	var names:Array[String]=["earth"]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--element="): names=[arg.split("=")[1]]
	for name in names:
		var p:Resource=load("res://presets/"+name+".tres"); fx.configure(p); fx.play(Vector2(180,139),17)
		var bounds:Array[Rect2i]=[]
		for stamp in [.0,.18,.43,.80,minf(1.1,p.lifetime()-.35),minf(1.5,p.lifetime()-.1),2.5]:
			fx.seek(stamp); var im:Image=await render(); var used:Rect2i=im.get_used_rect(); bounds.append(used)
			if not folder.is_empty(): im.save_png(folder.path_join(name+"-%03d.png"%roundi(stamp*100)))
			if stamp==0 or stamp==2.5: check(not used.has_area(),name+" transparent before and after")
			else: check(used.has_area(),name+" visible at "+str(stamp))
		check(bounds[1].size.x<bounds[2].size.x and bounds[2].size.x<bounds[3].size.x,name+" visible outward expansion")
		fx.seek(.80); var peak:Image=await render()
		check(pixels(peak)>900 and pixels(peak)<12000,name+" readable restrained native pixel coverage")
		check(Rect2i(1,1,358,238).encloses(peak.get_used_rect()),name+" no default clipping")
		fx.seek(.40); await render(); fx.seek(.80); check(peak.get_data()==(await render()).get_data(),name+" exact seek reproducibility")
		fx.clear(); check(not (await render()).get_used_rect().has_area(),name+" clear removes every pixel")
		fx.play(Vector2(180,139),17); fx.seek(.80)
		var hero:Node2D=Character.new(); hero.position=Vector2(180,139); stage.add_child(hero)
		var composite:Image=await render(); if not folder.is_empty(): composite.save_png(folder.path_join(name+"-hero.png"))
		hero.queue_free(); await process_frame
		# Compare a 120 Hz path against arbitrary-time evaluation.
		fx.play(Vector2(180,139),17)
		for i in 96: fx.advance(1.0/120)
		check(peak.get_data()==(await render()).get_data(),name+" frame-rate independent at shared timestamp")
		fx.clear()
	print("PASS" if failures==0 else "FAIL"," radial native: ",count," assertions, ",failures," failures")
	quit(0 if failures==0 else 1)
