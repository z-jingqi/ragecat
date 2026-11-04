extends SceneTree
const Body=preload("../components/body_state.gd")
const Profile=preload("../components/body_profile.gd")
var viewport: SubViewport
var actor
var checks: int=0
var failures: int=0
var folder: String
var records: Array=[]
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, message: String) -> void:
	checks+=1
	if not value: failures+=1; push_error(message)
func capture(name_value: String) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	var image=viewport.get_texture().get_image()
	image.save_png(folder.path_join(name_value+".png"))
	return image
func compare(reference: Image, candidate: Image) -> Dictionary:
	var changed: int=0; var alpha_errors: int=0; var outside: int=0; var energy: float=0; var outside_body: int=0
	for y in reference.get_height():
		for x in reference.get_width():
			var a=reference.get_pixel(x,y); var b=candidate.get_pixel(x,y)
			if a.a!=b.a: alpha_errors+=1
			if a.a==0 and b.a>0: outside+=1
			if a.r!=b.r or a.g!=b.g or a.b!=b.b:
				changed+=1
				if y<188 or y>380: outside_body+=1
				energy+=absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)
	return {"changed":changed,"alpha_errors":alpha_errors,"outside":outside,"energy":energy,"outside_body":outside_body}
func same(a: Image,b: Image) -> bool:
	return a.get_data()==b.get_data()
func run() -> void:
	folder=OS.get_environment("XINGTIAN_BODY_CAPTURE_DIR")
	if folder.is_empty(): push_error("Set XINGTIAN_BODY_CAPTURE_DIR"); quit(2); return
	viewport=SubViewport.new(); viewport.size=Vector2i(476,636); viewport.transparent_bg=true; viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
	actor=Body.new(); actor.position=Vector2(238,318); actor.scale=Vector2.ONE*0.25; viewport.add_child(actor)
	var mat=actor.material; actor.material=null
	var original=await capture("original")
	actor.material=mat; actor.start(0)
	check(same(original,await capture("normal")),"Zero amount is pixel-identical to original unshaded portrait")
	var last: int=0
	for amount in [0.2,0.45,0.7,1.0]:
		actor.set_amount(amount); actor.seek(5)
		var image=await capture("state-%03d"%roundi(amount*100))
		var diff=compare(original,image); diff["amount"]=amount; records.append(diff)
		check(diff.alpha_errors==0 and diff.outside==0,"Alpha and silhouette preserved at %.2f"%amount)
		check(diff.changed>last,"Coverage increases at %.2f"%amount); last=diff.changed
		check(diff.outside_body==0,"Only upper-body pixels change at %.2f"%amount)
	var full=await capture("full-repeat")
	actor.seek(5); check(same(full,await capture("repeat")),"Same amount/time repeats exactly")
	actor.seek(5.6); var flowing=await capture("flow-later")
	check(not same(full,flowing),"High-state highlight flows over time")
	var p=Profile.new(); p.breathing=0; p.flow_enabled=false; actor.configure(p); actor.seek(5)
	var still=await capture("flow-disabled-a"); actor.seek(5.6)
	check(same(still,await capture("flow-disabled-b")),"Flow and breathing can be disabled")
	p.intensity=0; actor.configure(p)
	check(same(original,await capture("zero-intensity")),"Zero intensity is exact original")
	actor.configure(Profile.new()); actor.clear(); actor.seek(9); actor.set_amount(1)
	check(same(original,await capture("cleared")),"Clear followed by seek and amount cannot resurrect")
	actor.start(0.5); check(not same(original,await capture("restarted")),"Explicit start restores")
	actor.set_amount(0); check(same(original,await capture("decayed")),"Decay ending at zero restores exact portrait")
	# Full UI uses a fixed logical viewport independent from native window size.
	var screen=load("res://preview.tscn").instantiate(); root.add_child(screen); viewport.queue_free()
	screen.paused=true; screen.age=5; screen._sample()
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join("preview-full.png"))
	var result={"checks":checks,"failures":failures,"states":records,"renderer":RenderingServer.get_video_adapter_name()}
	var file=FileAccess.open(folder.path_join("render-results.json"),FileAccess.WRITE); file.store_string(JSON.stringify(result,"\t")); file.close()
	print("BODY_NATIVE ",JSON.stringify(result)); quit(0 if failures==0 else 1)
