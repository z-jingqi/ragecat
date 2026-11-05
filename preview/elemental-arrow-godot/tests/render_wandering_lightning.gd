extends SceneTree
const FX=preload("../components/elemental_arrow.gd")
const P=preload("../presets/lightning.tres")
const L=preload("../modules/lightning_reference.gd")
var count=0
var failures=0
func check(ok:bool,label:String)->void:
	count+=1
	if not ok: failures+=1; push_error(label)
func _initialize()->void: call_deferred("run")
func run()->void:
	if DisplayServer.get_name()=="headless": push_error("Real renderer required"); quit(2); return
	var folder=OS.get_environment("ARROW_CAPTURE_DIR")
	var vp=SubViewport.new(); vp.size=Vector2i(360,160); vp.transparent_bg=true; vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(vp)
	var fx=FX.new(); vp.add_child(fx)
	for length in [64.0,96.0,128.0,256.0]:
		var q=P.duplicate(true); q.length=length; q.body_enabled=false; q.air_enabled=false
		var blank=0; var partial=0; var peaks=0; var consistent=true; var bounded=true; var readable=0; var active=0
		for frame in 180:
			var t=float(frame)/30; var events=L.arcs_at(t,length,1,q.lightning)
			fx.play(Vector2(300,80),Vector2.RIGHT,q); fx.age=t; fx.queue_redraw()
			await process_frame; await process_frame; await RenderingServer.frame_post_draw
			var im=vp.get_texture().get_image(); var rect=im.get_used_rect(); var strongest=0.0; var peak=false
			for event in events: strongest=maxf(strongest,event.opacity); peak=peak or event.kind=="peak"
			if events.is_empty(): blank+=1; consistent=consistent and not rect.has_area()
			elif peak: peaks+=1
			else: partial+=1
			if strongest>.2:
				active+=1
				if rect.has_area(): readable+=1
			if rect.has_area(): bounded=bounded and rect.position.x>0 and rect.position.y>0 and rect.end.x<vp.size.x and rect.end.y<vp.size.y
		check(blank>10 and consistent,"actual renderer fully clears quiet intervals at "+str(length))
		check(partial>70 and peaks>0 and peaks<30,"partial/peak temporal coverage at "+str(length))
		check(active>0 and readable==active,"live local arcs remain visible at actual 1x size "+str(length))
		check(bounded,"local arcs/forks/glow stay within attached viewport "+str(length))
		print("Native lifecycle length=",length," blank=",blank," partial=",partial," peak=",peaks," visible=",readable,"/",active)
	fx.queue_free(); vp.queue_free(); await process_frame
	var board=SubViewport.new(); board.size=Vector2i(1280,800); board.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(board)
	var bg=ColorRect.new(); bg.size=board.size; bg.color=Color("101119"); board.add_child(bg)
	var peak_time=.64
	for frame in 180:
		var t=float(frame)/60
		for event in L.arcs_at(t,96,1,P.lightning):
			if event.kind=="peak" and event.opacity>.75: peak_time=t; break
	var times=[0.0,.12,.25,.40,peak_time,.95]
	var premult=CanvasItemMaterial.new(); premult.blend_mode=CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	for i in times.size():
		var events=L.arcs_at(times[i],256,1,P.lightning); var state="QUIET" if events.is_empty() else "LOCAL"
		for event in events:
			if event.kind=="peak": state="PEAK"
		var label=Label.new(); label.position=Vector2(20,15+i*130); label.text="%.2fs  %s  %d live arcs"%[times[i],state,events.size()]; label.add_theme_font_size_override("font_size",16); board.add_child(label)
		var row=SubViewport.new(); row.size=Vector2i(320,60); row.transparent_bg=true; row.render_target_update_mode=SubViewport.UPDATE_ALWAYS; board.add_child(row)
		var arrow=FX.new(); row.add_child(arrow); var q=P.duplicate(true); q.length=256; arrow.play(Vector2(290,30),Vector2.RIGHT,q); arrow.age=times[i]; arrow.queue_redraw()
		var panel=TextureRect.new(); panel.texture=row.get_texture(); panel.material=premult; panel.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST; panel.position=Vector2(320,20+i*130); panel.size=Vector2(640,120); board.add_child(panel)
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	if not folder.is_empty(): board.get_texture().get_image().save_png(folder.path_join("wandering-sequence.png"))
	print("PASS" if failures==0 else "FAIL"," native wandering lightning: ",count," assertions; failures=",failures)
	quit(0 if failures==0 else 1)
