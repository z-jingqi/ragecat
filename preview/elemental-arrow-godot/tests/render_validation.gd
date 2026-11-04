extends SceneTree
const FX=preload("../components/elemental_arrow.gd")
const Profile=preload("../components/arrow_profile.gd")
var fx:Node2D
var vp:SubViewport
var folder:String
var count:int=0
func _initialize()->void: call_deferred("run")
func render()->Image:
	fx.queue_redraw()
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	return vp.get_texture().get_image()
func pixels(im:Image)->int:
	var n=0
	for y in im.get_height():
		for x in im.get_width():
			if im.get_pixel(x,y).a>.01: n+=1
	return n
func check(ok:bool,label:String)->void:
	assert(ok,label)
	if not ok: push_error(label); quit(1)
	count+=1
func run()->void:
	folder=OS.get_environment("ARROW_CAPTURE_DIR")
	vp=SubViewport.new(); vp.size=Vector2i(280,220); vp.transparent_bg=true; vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(vp)
	fx=FX.new(); vp.add_child(fx)
	for key in ["plain","fire","lightning","ice"]:
		if key!="plain" and not ResourceLoader.exists("res://modules/"+key+".gd"): continue
		var q=Profile.new(); q.air_enabled=false
		if key!="plain": q.get(key).enabled=true
		for i in 8:
			var axis=Vector2.from_angle(i*PI/4)
			fx.play(Vector2(140,110),axis*160,q)
			fx.seek(.45,func(t): return {"tip":Vector2(140,110)+axis*(t-.45)*160,"velocity":axis*160})
			var im=await render(); check(pixels(im)>35,"nonempty "+key+" direction "+str(i))
			var bounds=im.get_used_rect(); check(bounds.position.x>0 and bounds.position.y>0 and bounds.end.x<280 and bounds.end.y<220,"default effect fits render bounds")
			if not folder.is_empty(): im.save_png(folder.path_join(key+"-angle-"+str(i)+".png"))
		fx.set_layer_enabled("body",false)
		if key!="plain":
			var solo=await render(); check(pixels(solo)>0,"attachment independent "+key)
			q.get(key).intensity=0; fx.configure(q); var zero=await render(); check(pixels(zero)==0,"zero intensity hidden "+key)
			q.get(key).intensity=1; q.get(key).tint=Color(1,1,1,0); fx.configure(q); var transparent=await render(); check(pixels(transparent)==0,"transparent tint hidden "+key)
			q.get(key).tint=Color(1,.35,.7,1); q.get(key).size=2; q.get(key).intensity=2; fx.configure(q); var stress=await render(); check(pixels(stress)>0,"custom color and max size render "+key)
			if not folder.is_empty(): stress.save_png(folder.path_join(key+"-custom-color.png"))
		fx.clear(); var empty=await render(); check(pixels(empty)==0,"clear leaves transparent frame")
		fx.set_layer_enabled("body",true)
	print("PASS native arrow render: ",count," assertions")
	quit()
