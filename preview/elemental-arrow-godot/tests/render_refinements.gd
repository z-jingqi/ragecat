extends SceneTree
# Real-render regression for head-local fire and shaft-bounded lightning.
# Run with a graphical renderer, never --headless:
# godot --path preview/elemental-arrow-godot --script tests/render_refinements.gd
# Add -- --lightning to include the shaft-only lightning checks.
const FX=preload("../components/elemental_arrow.gd")
const FIRE_PROFILE=preload("../presets/fire.tres")
const LIGHTNING_PROFILE=preload("../presets/lightning.tres")
const TIP=Vector2(140,110)
const SAMPLE_TIMES=[.21,.45,.72]
const SPEED=160.0
var fx:Node2D
var vp:SubViewport
var count:int=0
var failures:int=0
var folder:String

func _initialize()->void:
	call_deferred("run")

func render()->Image:
	fx.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	return vp.get_texture().get_image()

func check(ok:bool,label:String)->void:
	count+=1
	if not ok:
		failures+=1
		push_error(label)

func projected_bounds(im:Image,axis:Vector2)->Dictionary:
	var normal=Vector2(-axis.y,axis.x)
	var minimum=Vector2(INF,INF)
	var maximum=Vector2(-INF,-INF)
	var occupied:int=0
	for y in im.get_height():
		for x in im.get_width():
			if im.get_pixel(x,y).a<=.01:
				continue
			# Pixel centers make the same arrow-local test work in all directions.
			var offset=Vector2(x+.5,y+.5)-TIP
			var local=Vector2(offset.dot(axis),offset.dot(normal))
			minimum=minimum.min(local)
			maximum=maximum.max(local)
			occupied+=1
	return {"minimum":minimum,"maximum":maximum,"occupied":occupied}

func run()->void:
	if DisplayServer.get_name()=="headless":
		push_error("render_refinements.gd requires a real graphical renderer; headless is not a render pass")
		quit(2)
		return
	folder=OS.get_environment("ARROW_CAPTURE_DIR")
	vp=SubViewport.new()
	vp.size=Vector2i(280,220)
	vp.transparent_bg=true
	vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	fx=FX.new()
	vp.add_child(fx)
	fx.set_layer_enabled("body",false)
	fx.set_layer_enabled("air",false)
	var keys=["fire"]
	if "--lightning" in OS.get_cmdline_user_args():
		keys.append("lightning")
	for key in keys:
		var q:Resource=(FIRE_PROFILE if key=="fire" else LIGHTNING_PROFILE).duplicate(true)
		q.body_enabled=false
		q.air_enabled=false
		for element in ["fire","lightning","ice"]:
			q.get(element).enabled=element==key
		var attachment:Resource=q.get(key)
		attachment.size=1.0
		attachment.intensity=1.0
		attachment.glow=0.0
		for sample_time in SAMPLE_TIMES:
			for direction in 8:
				var axis=Vector2.from_angle(direction*PI/4)
				if key=="lightning":
					attachment.trail_length=0.0
				fx.play(TIP,axis*SPEED,q)
				fx.seek(sample_time,func(at): return {"tip":TIP+axis*(at-sample_time)*SPEED,"velocity":axis*SPEED})
				var im=await render()
				var bounds=projected_bounds(im,axis)
				var minimum:Vector2=bounds.minimum
				var maximum:Vector2=bounds.maximum
				var label="%s t=%.2f direction=%d"%[key,sample_time,direction]
				var detail="; measured x=[%.3f,%.3f], y=[%.3f,%.3f]"%[minimum.x,maximum.x,minimum.y,maximum.y]
				var low_x:float=-23.0 if key=="fire" else -float(q.length)+3.0
				var high_x:float=7.0 if key=="fire" else 1.0
				var half_width:float=13.0 if key=="fire" else 5.0
				check(bounds.occupied>0,"nonempty "+label)
				check(minimum.x>=low_x-.001 and maximum.x<=high_x+.001,"axial bound "+label+detail)
				check(minimum.y>=-half_width-.001 and maximum.y<=half_width+.001,"perpendicular bound "+label+detail)
				if not folder.is_empty():
					im.save_png(folder.path_join("refined-%s-%.2f-angle-%d.png"%[key,sample_time,direction]))
				if key=="lightning":
					attachment.trail_length=2.0
					fx.configure(q)
					var full_trail=await render()
					check(im.get_data()==full_trail.get_data(),"trail_length 0 and 2 render identically "+label)
		# Resource limits exceed the UI's size limit. Check that enlarged effects
		# render without viewport clipping, not that they retain default-size bounds.
		q.length=18.0
		attachment.size=3.0
		attachment.glow=1.0
		for direction in 8:
			var axis=Vector2.from_angle(direction*PI/4)
			fx.play(TIP,axis*SPEED,q)
			fx.seek(.45,func(at): return {"tip":TIP+axis*(at-.45)*SPEED,"velocity":axis*SPEED})
			var stress=await render()
			var occupied=stress.get_used_rect()
			var label="resource size=3 length=18 "+key+" direction="+str(direction)
			check(occupied.has_area(),"nonempty "+label)
			check(occupied.position.x>0 and occupied.position.y>0 and occupied.end.x<vp.size.x and occupied.end.y<vp.size.y,"unclipped "+label)
			if not folder.is_empty():
				stress.save_png(folder.path_join("refined-%s-resource-max-angle-%d.png"%[key,direction]))
	print("PASS" if failures==0 else "FAIL"," native arrow refinements: ",count," assertions; failures=",failures)
	quit(0 if failures==0 else 1)
