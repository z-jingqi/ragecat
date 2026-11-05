extends SceneTree
const FX=preload("../components/radial_spikes.gd")
var checks:int=0
var failures:int=0
var vp:SubViewport
var fx:Node2D
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func _initialize()->void: call_deferred("run")
func layer_image(layer:int,t:float)->Image:
	fx.seek(t)
	for i in fx.canvases.size(): fx.canvases[i].visible=layer<0 or fx.spikes[i].layer==layer
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	return vp.get_texture().get_image()
func run()->void:
	if DisplayServer.get_name()=="headless": push_error("Native renderer required"); quit(2); return
	vp=SubViewport.new(); vp.size=Vector2i(360,240); vp.transparent_bg=true; vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(vp)
	fx=FX.new(); vp.add_child(fx)
	var folder:String=OS.get_environment("RADIAL_CAPTURE_DIR")
	for name in ["earth","ice","lightning"]:
		fx.configure(load("res://presets/"+name+".tres")); fx.play(Vector2(180,139),17)
		var p:Resource=fx.profile
		for layer in range(1,3):
			var overlap_frames:int=0
			for frame in range(1,9):
				var t:float=.1+layer*p.layer_stride()+float(frame)/120
				var previous:Image=await layer_image(layer-1,t); var following:Image=await layer_image(layer,t)
				if previous.get_used_rect().has_area() and following.get_used_rect().has_area(): overlap_frames+=1
			check(overlap_frames>=4,name+" actual previous fade / following growth overlap, transition "+str(layer))
			var composite:Image=await layer_image(-1,.1+layer*p.layer_stride()+.075)
			if not folder.is_empty(): composite.save_png(folder.path_join(name+"-handoff-"+str(layer)+".png"))
			print(name," transition ",layer," both rendered in ",overlap_frames,"/8 sampled frames")
		check(not (await layer_image(0,.1+2*p.layer_stride()+p.stagger_window()+.03)).get_used_rect().has_area(),name+" inner ring gone when outer ring grows")
		check(not (await layer_image(-1,p.lifetime()+.02)).get_used_rect().has_area(),name+" complete pulse fully transparent at end")
	print("PASS" if failures==0 else "FAIL"," wave native: ",checks," assertions, ",failures," failures")
	quit(0 if failures==0 else 1)
