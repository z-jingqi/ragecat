extends SceneTree
const Halo=preload("../components/alpha_halo.gd")
const Profile=preload("../components/halo_profile.gd")
const XING=preload("../assets/xing_tian.png")
const HOU=preload("../assets/hou_yi.png")
var viewport: SubViewport
var actor
var folder: String
var checks: int=0
var failures: int=0
var records: Array=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks+=1
	if not value: failures+=1; push_error(message)
func capture(label: String) -> Image:
	await process_frame; await RenderingServer.frame_post_draw
	var image=viewport.get_texture().get_image(); image.save_png(folder.path_join(label+".png")); return image
func same(a: Image,b: Image) -> bool: return a.get_data()==b.get_data()
func inspect(base: Image, lit: Image) -> Dictionary:
	var exterior: int=0; var opaque_errors: int=0; var strongest: float=0; var border: int=0; var energy: float=0
	for y in base.get_height():
		for x in base.get_width():
			var a=base.get_pixel(x,y); var b=lit.get_pixel(x,y)
			if a.a==1 and a!=b: opaque_errors+=1
			if a.a==0 and b.a>0.01:
				exterior+=1; strongest=maxf(strongest,b.a); energy+=b.a
				if x==0 or y==0 or x==base.get_width()-1 or y==base.get_height()-1: border+=1
	return {"exterior_pixels":exterior,"opaque_errors":opaque_errors,"strongest_alpha":strongest,"alpha_energy":energy,"viewport_border":border}
func run() -> void:
	folder=OS.get_environment("ALPHA_HALO_CAPTURE_DIR")
	if folder.is_empty(): push_error("Set ALPHA_HALO_CAPTURE_DIR"); quit(2); return
	viewport=SubViewport.new(); viewport.size=Vector2i(128,128); viewport.transparent_bg=true; viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
	actor=Halo.new(); actor.position=Vector2(64,64); viewport.add_child(actor)
	var p=Profile.new(); p.breathing=0; actor.configure(p)
	for i in 2:
		var texture: Texture2D=XING if i==0 else HOU
		var crop=Rect2(texture.get_image().get_used_rect())
		actor.set_frame(texture,crop,Vector2(crop.size.x/crop.size.y*76,76)); actor.start(0)
		var original=await capture("hero-%d-normal"%i)
		var last_energy: float=0
		for amount in [0.25,0.5,1.0]:
			actor.set_amount(amount); var lit=await capture("hero-%d-%03d"%[i,roundi(amount*100)])
			var metrics=inspect(original,lit); metrics["hero"]=i; metrics["amount"]=amount; records.append(metrics)
			check(metrics.exterior_pixels>100,"visible exterior pixels at76px, hero%d"%i)
			check(metrics.opaque_errors==0,"opaque original art unchanged")
			check(metrics.alpha_energy>last_energy,"accumulation intensity increases"); last_energy=metrics.alpha_energy
			check(metrics.viewport_border==0,"glow not clipped by viewport")
		actor.seek(3); var full=await capture("hero-%d-repeat-a"%i); actor.seek(3)
		check(same(full,await capture("hero-%d-repeat-b"%i)),"fixed inputs deterministic")
		actor.set_amount(0); check(same(original,await capture("hero-%d-decayed"%i)),"decay restores original exactly")
		actor.clear(); actor.set_amount(1); actor.configure(p); actor.seek(2)
		check(same(original,await capture("hero-%d-cleared"%i)),"clear cannot resurrect")
		actor.start(1); check(not same(original,await capture("hero-%d-restarted"%i)),"explicit restart")
	# No baked stencil: changing frame on the same live node matches a fresh node.
	var reused=await capture("changed-source")
	var replacement=Halo.new(); replacement.position=actor.position; viewport.add_child(replacement)
	replacement.configure(p); replacement.set_frame(HOU,actor.source_region,actor.display_size); replacement.start(1)
	actor.visible=false; check(same(reused,await capture("fresh-source")),"same-instance texture switch has no stale alpha")
	replacement.queue_free(); await process_frame; actor.visible=true
	# Adjacent opaque atlas cells must not leak. Selected frame is all transparent.
	var atlas_image=Image.create(64,32,false,Image.FORMAT_RGBA8); atlas_image.fill(Color.WHITE)
	atlas_image.fill_rect(Rect2i(0,0,32,32),Color.TRANSPARENT)
	var atlas=ImageTexture.create_from_image(atlas_image)
	actor.set_frame(atlas,Rect2(0,0,32,32),Vector2(32,32)); actor.start(1)
	check((await capture("atlas-empty-neighbor")).get_used_rect()==Rect2i(),"opaque neighboring atlas frame excluded")
	# Full opaque frame reaches every texture boundary. Geometry still allows glow outside.
	actor.set_frame(atlas,Rect2(32,0,32,32),Vector2(32,32)); actor.start(0)
	var square_base=await capture("edge-base"); actor.start(1); var square_lit=await capture("edge-glow")
	check(square_lit.get_used_rect().size.x>square_base.get_used_rect().size.x,"glow survives tight texture boundary")
	check(inspect(square_base,square_lit).opaque_errors==0,"tight source remains unchanged")
	var atlas_frame=AtlasTexture.new(); atlas_frame.atlas=atlas; atlas_frame.region=Rect2(32,0,32,32)
	actor.set_frame(atlas_frame,Rect2(),Vector2(32,32))
	check(same(square_lit,await capture("atlas-wrapper-full")),"AtlasTexture wrapper resolves identical pixels")
	atlas_frame.region=Rect2(0,0,32,32); actor.set_frame(atlas_frame,Rect2(),Vector2(32,32))
	check((await capture("atlas-wrapper-empty")).get_used_rect()==Rect2i(),"animation AtlasTexture frame updates alpha immediately")
	actor.set_frame(atlas,Rect2(32,0,32,32),Vector2(32,32))
	p.intensity=0; actor.configure(p)
	check(same(square_base,await capture("zero-intensity")),"zero intensity returns exact source")
	p.intensity=0.58; p.width=0.5; actor.configure(p); var thin=await capture("thin-halo")
	p.width=8; actor.configure(p); var wide=await capture("wide-halo")
	check(wide.get_used_rect().size.x>thin.get_used_rect().size.x and wide.get_used_rect().size.x>square_lit.get_used_rect().size.x,"width parameter expands actual rendered halo")
	p.color=Color("73d6ed"); actor.configure(p); var cyan=await capture("cyan-halo")
	check(not same(cyan,wide) and inspect(square_base,cyan).opaque_errors==0,"color changes only halo")
	actor.modulate=Color(1,1,1,0)
	check((await capture("host-hidden-alpha")).get_used_rect()==Rect2i(),"host opacity hides portrait and glow together")
	actor.modulate=Color.WHITE; p=Profile.new(); p.breathing=0; actor.configure(p)
	# Nonbinary alpha stays bounded, and zero state is the exact original composite.
	var soft=Image.create(32,32,false,Image.FORMAT_RGBA8); soft.fill(Color.TRANSPARENT)
	soft.fill_rect(Rect2i(12,6,8,20),Color(0.4,0.7,0.9,1)); soft.fill_rect(Rect2i(10,6,2,20),Color(0.4,0.7,0.9,0.35))
	actor.set_frame(ImageTexture.create_from_image(soft),Rect2(),Vector2(32,32)); actor.start(0)
	var soft_base=await capture("partial-alpha-base"); actor.start(1); var soft_lit=await capture("partial-alpha-glow")
	check(inspect(soft_base,soft_lit).opaque_errors==0 and soft_lit.get_used_rect().size.x>soft_base.get_used_rect().size.x,"partial-alpha input supported")
	actor.set_flip(true); var flipped=await capture("flipped"); check(not same(flipped,soft_lit),"asymmetric frame flip affects image and glow")
	actor.set_flip(false); check(same(soft_lit,await capture("unflipped")),"flip restoration exact")
	actor.position+=Vector2(11,7); var moved=await capture("moved")
	check(moved.get_used_rect().position==soft_lit.get_used_rect().position+Vector2i(11,7),"halo follows host translation")
	actor.position=Vector2(64,64); actor.scale=Vector2.ONE*1.5
	check((await capture("scaled")).get_used_rect().size.y>soft_lit.get_used_rect().size.y,"halo follows host scale")
	# Capture the real comparison UI on both background choices.
	viewport.queue_free(); var screen=load("res://preview.tscn").instantiate(); root.add_child(screen)
	screen.paused=true; screen.age=5; screen._sample()
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join("preview-full.png"))
	screen.light_background=true; screen._theme(); screen.queue_redraw()
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join("preview-light.png"))
	var result={"checks":checks,"failures":failures,"states":records,"renderer":RenderingServer.get_video_adapter_name()}
	var file=FileAccess.open(folder.path_join("render-results.json"),FileAccess.WRITE); file.store_string(JSON.stringify(result,"\t")); file.close()
	print("HALO_NATIVE ",JSON.stringify(result)); quit(0 if failures==0 else 1)
