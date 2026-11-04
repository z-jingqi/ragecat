extends SceneTree
const FX=preload("../components/elemental_arrow.gd")
const PRESET=preload("../presets/lightning.tres")
var fx:Node2D
var vp:SubViewport
var failures:int=0
var count:int=0
func check(ok:bool,label:String)->void:
	count+=1
	if not ok: failures+=1; push_error(label)
func _initialize()->void: call_deferred("run")
func render()->Image:
	fx.queue_redraw(); await process_frame; await process_frame; await RenderingServer.frame_post_draw
	return vp.get_texture().get_image()
func components(im:Image)->Array:
	var seen={}; var groups=[]
	for y in im.get_height():
		for x in im.get_width():
			var p=Vector2i(x,y); var c=im.get_pixelv(p)
			if c.a>.2 and c.g>.55 and c.b>.75: seen[p]=false
	for p in seen:
		if seen[p]: continue
		var queue=[p]; seen[p]=true; var group=[]
		while not queue.is_empty():
			var q=queue.pop_back(); group.append(q)
			for dy in range(-1,2):
				for dx in range(-1,2):
					var n=q+Vector2i(dx,dy)
					if seen.has(n) and not seen[n]: seen[n]=true; queue.append(n)
		if group.size()>=2: groups.append(group)
	return groups
func run()->void:
	if DisplayServer.get_name()=="headless": push_error("Real renderer required"); quit(2); return
	vp=SubViewport.new(); vp.size=Vector2i(96,80); vp.transparent_bg=true; vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(vp)
	fx=FX.new(); vp.add_child(fx)
	var q=PRESET.duplicate(true); q.body_enabled=false; q.air_enabled=false; q.lightning.glow=0; q.lightning.lightning_mode=1
	var total=0; var separate=0; var long_wire=0; var changed=0; var last=PackedByteArray(); var counts={}
	var folder=OS.get_environment("ARROW_CAPTURE_DIR")
	for frame in 60:
		var t=float(frame)/60
		fx.play(Vector2(64,40),Vector2.RIGHT*180,q); fx.seek(t,func(_v): return {"tip":Vector2(64,40),"velocity":Vector2.RIGHT*180})
		var im=await render(); var groups=components(im); total+=groups.size(); counts[groups.size()]=true
		if groups.size()>=2: separate+=1
		var long_present=false
		for group in groups:
			var lo=999; var hi=-999
			for p in group: lo=mini(lo,p.x); hi=maxi(hi,p.x)
			if hi-lo>=17: long_present=true
		if long_present: long_wire+=1
		if frame>0 and im.get_data()!=last: changed+=1
		last=im.get_data()
		if not folder.is_empty() and frame%3==0: im.save_png(folder.path_join("crackle-%02d.png"%frame))
	print("Crackle metrics: mean_components=",float(total)/60," separate_frames=",separate," long_wire_frames=",long_wire," changed_frames=",changed," count_variants=",counts.size())
	check(float(total)/60>=1.7,"multiple distinct short arcs across the sequence")
	check(separate>=30,"separate arcs in at least half the frames")
	check(long_wire<30,"no persistent full-shaft winding wire")
	check(changed>=25,"arcs change or expire across the sequence")
	check(counts.size()>=3,"arc count changes as independent bursts appear and disappear")
	var tip=Vector2(64,40); var stamp=.63
	fx.play(tip,Vector2.RIGHT*80,q)
	fx.seek(stamp,func(v): return {"tip":tip+Vector2((v-stamp)*80,0),"velocity":Vector2.RIGHT*80})
	var straight=await render()
	fx.play(tip,Vector2.RIGHT*80,q)
	fx.seek(stamp,func(v): return {"tip":tip+Vector2((v-stamp)*80,pow(v-stamp,2)*100),"velocity":Vector2(80,(v-stamp)*200)})
	var curved=await render()
	check(straight.get_data()==curved.get_data(),"different flight histories have identical current lightning; no wake")
	q.lightning.arc_density=0; fx.configure(q)
	var empty=await render()
	check(not empty.get_used_rect().has_area(),"zero density leaves no arcs or constant glow")
	print("PASS" if failures==0 else "FAIL"," native crackle: ",count," assertions; failures=",failures)
	quit(0 if failures==0 else 1)
