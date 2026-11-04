extends SceneTree
const P=preload("../components/spear_profile.gd")
const E=preload("../components/elemental_spear.gd")
var view:SubViewport
var e
var checks=0
var failures=0
var folder=""
func _initialize()->void: call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func image_at(t:float)->Image:
	e.seek(t); await process_frame; await RenderingServer.frame_post_draw; return view.get_texture().get_image()
func code(img:Image)->String: return img.get_data().hex_encode().sha256_text()
func run()->void:
	folder=OS.get_environment("SPEAR_CAPTURE_DIR")
	view=SubViewport.new(); view.size=Vector2i(380,330); view.transparent_bg=true; view.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(view)
	e=E.new(); view.add_child(e)
	var body_codes=[]; var field_codes=[]
	for element in 3:
		var p=P.new()
		for key in P.PHASES: p.phase(key).element=element
		e.play(Vector2(190,260),p); body_codes.append(code(await image_at(p.offsets().hover+.08))); field_codes.append(code(await image_at(p.contact_time()+.8)))
	check(body_codes[0]!=body_codes[1] and body_codes[1]!=body_codes[2] and body_codes[0]!=body_codes[2],"Three actual spear silhouettes differ")
	check(field_codes[0]!=field_codes[1] and field_codes[1]!=field_codes[2] and field_codes[0]!=field_codes[2],"Three actual ground areas differ")
	for body in 3:
		for ground in 3:
			var p=P.new()
			for key in P.PHASES: p.phase(key).element=body
			p.field.element=ground; p.dissolve.element=ground
			e.play(Vector2(190,260),p)
			check(code(await image_at(p.offsets().hover+.08))==body_codes[body],"Ground swap leaves spear pixels unchanged")
			var img=await image_at(p.contact_time()+.8)
			check(code(img)==field_codes[ground],"Mixed ground exactly equals selected module pixels")
			if not folder.is_empty(): img.save_png(folder.path_join("mix-%d-%d.png"%[body,ground]))
			for key in P.PHASES: e.set_stage_enabled(key,false)
			check((await image_at(.5)).is_invisible(),"All stage toggles clear native composition")
			for key in P.PHASES: e.set_stage_enabled(key,true)
	# The stage-size/short-duration regression uses exact rendered endpoints too.
	for element in 3:
		var p=P.new(); p.field.duration=.02
		for key in P.PHASES: p.phase(key).element=element
		e.play(Vector2(190,260),p)
		var field=await image_at(p.contact_time()+.01999)
		var fade=await image_at(p.offsets().dissolve+.00001)
		check(not field.is_invisible() and not fade.is_invisible(),"Very short fields stay rendered through handoff")
		e.seek(p.total_duration()); await process_frame; await RenderingServer.frame_post_draw
		check(view.get_texture().get_image().is_invisible(),"Every mixed timeline eventually empties")
	view.free(); print("ELEMENTAL_SPEAR_MIX_GPU: %d checks, %d failures"%[checks,failures]); quit(1 if failures else 0)
