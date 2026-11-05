extends SceneTree
# Sustained pair component used for brief peaks; not the default temporal behavior.
const FX=preload("../components/elemental_arrow.gd")
const P=preload("../presets/lightning.tres")
class DepthProbe extends "../components/elemental_arrow.gd":
	var mode=0
	func _draw()->void:
		if not running: return
		var lightning=renderers.lightning
		if mode in [0,2,4]: lightning.back(self,profile.lightning)
		if mode in [1,2,4]: Body.render(self,pose,age,profile)
		if mode in [3,4]: lightning.front(self,profile.lightning)
var count=0
var failures=0
var vp:SubViewport
var fx:Node2D
func check(ok:bool,label:String)->void:
	count+=1
	if not ok: failures+=1; push_error(label)
func _initialize()->void: call_deferred("run")
func render()->Image:
	fx.queue_redraw(); await process_frame; await process_frame; await RenderingServer.frame_post_draw
	return vp.get_texture().get_image()
func run()->void:
	if DisplayServer.get_name()=="headless": push_error("Real renderer required"); quit(2); return
	var folder=OS.get_environment("ARROW_CAPTURE_DIR")
	vp=SubViewport.new(); vp.size=Vector2i(360,320); vp.transparent_bg=true; vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(vp)
	fx=FX.new(); vp.add_child(fx)
	var q=P.duplicate(true); q.lightning.arc_wandering=false
	q.body_enabled=false; q.air_enabled=false; q.lightning.glow=0
	var tip=Vector2(180,160); var last=PackedByteArray(); var changes=0
	for frame in 60:
		var t=float(frame)/60
		fx.play(tip,Vector2.RIGHT*180,q); fx.seek(t,func(_v): return {"tip":tip,"velocity":Vector2.RIGHT*180})
		var im=await render(); var rect=im.get_used_rect()
		var white=0; var blue=0
		for y in rect.size.y:
			for x in rect.size.x:
				var pixel=im.get_pixelv(rect.position+Vector2i(x,y))
				if pixel.a>.6 and pixel.r>.7 and pixel.g>.8 and pixel.b>.85: white+=1
				if pixel.a>.25 and pixel.b>.4 and pixel.r<pixel.b*.65: blue+=1
		check(white>=3 and blue>=8,"white-cyan core and blue fringe readable frame "+str(frame))
		check(rect.size.x>=q.length*.65 and rect.size.x<=q.length*.75+4 and rect.size.y>=q.length*.08 and rect.size.y<=q.length*.32+6,"restrained shaft-local 1x reference at frame "+str(frame))
		if frame>0 and im.get_data()!=last: changes+=1
		last=im.get_data()
		if not folder.is_empty() and frame%6==0: im.save_png(folder.path_join("reference-%02d.png"%frame))
	check(changes>=29,"visible shape and rotation change throughout sequence")
	var stamp=.63
	fx.play(tip,Vector2.RIGHT*80,q)
	fx.seek(stamp,func(v): return {"tip":tip+Vector2((v-stamp)*80,0),"velocity":Vector2.RIGHT*80})
	var straight=await render()
	fx.play(tip,Vector2.RIGHT*80,q)
	fx.seek(stamp,func(v): return {"tip":tip+Vector2((v-stamp)*80,pow(v-stamp,2)*100),"velocity":Vector2(80,(v-stamp)*200)})
	check(straight.get_data()==(await render()).get_data(),"same current pose is independent of historical trajectory")
	q.lightning.arc_density=0; fx.configure(q)
	check(not (await render()).get_used_rect().has_area(),"density zero fully transparent")
	q.lightning.arc_density=1; q.body_enabled=true
	fx.queue_free(); await process_frame; fx=DepthProbe.new(); vp.add_child(fx)
	var overlap_total=0
	for direction in 8:
		var axis=Vector2.from_angle(direction*PI/4)
		fx.play(tip,axis*120,q); fx.seek(.63,func(_v): return {"tip":tip,"velocity":axis*120})
		fx.mode=0; var back=await render()
		fx.mode=1; var body=await render()
		fx.mode=2; var behind_body=await render()
		var overlap=0; var correct=true
		for y in back.get_height():
			for x in back.get_width():
				var b=body.get_pixel(x,y)
				if back.get_pixel(x,y).a>.05 and b.a>.999:
					overlap+=1
					correct=correct and behind_body.get_pixel(x,y).is_equal_approx(b)
		overlap_total+=overlap
		check(overlap>0 and correct,"rear arcs correctly occluded by opaque shaft direction "+str(direction))
		fx.mode=4; var complete=await render()
		var wood=0; var retained=0
		for y in body.get_height():
			for x in body.get_width():
				var pixel=body.get_pixel(x,y)
				var axial=(Vector2(x+.5,y+.5)-tip).dot(axis)
				if axial>=-q.length*.80 and axial<=-q.length*.16 and pixel.a>.9 and pixel.r>pixel.g*1.15 and pixel.g>pixel.b*1.15:
					wood+=1
					var visible=complete.get_pixel(x,y)
					if visible.r>visible.g*1.10 and visible.g>visible.b*1.10: retained+=1
		check(wood>0 and float(retained)/wood>=.40,"wood shaft remains readable direction "+str(direction))
		if not folder.is_empty(): complete.save_png(folder.path_join("reference-depth-angle-%d.png"%direction))
		# Verify the normal host component uses exactly the tested draw ordering.
		var probe=fx; probe.visible=false; var actual=FX.new(); vp.add_child(actual); fx=actual
		actual.play(tip,axis*120,q); actual.seek(.63,func(_v): return {"tip":tip,"velocity":axis*120})
		check(complete.get_data()==(await render()).get_data(),"host matches front/body/back ordering direction "+str(direction))
		actual.queue_free(); await process_frame; fx=probe; probe.visible=true
	print("Reference native metrics: changes=",changes," opaque rear intersections=",overlap_total)
	print("PASS" if failures==0 else "FAIL"," native reference: ",count," assertions; failures=",failures)
	quit(0 if failures==0 else 1)
