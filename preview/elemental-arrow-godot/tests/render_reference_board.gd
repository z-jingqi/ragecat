extends SceneTree
# Native visual review board. The approved reference is loaded only from an
# explicit local environment path; it is not bundled or made a runtime asset.
const FX=preload("../components/elemental_arrow.gd")
const P=preload("../presets/lightning.tres")
func _initialize()->void: call_deferred("run")
func label(parent:Node,text:String,at:Vector2,size:int=18)->void:
	var l=Label.new(); l.text=text; l.position=at; l.add_theme_font_size_override("font_size",size); parent.add_child(l)
func run()->void:
	if DisplayServer.get_name()=="headless": quit(2); return
	var board=SubViewport.new(); board.size=Vector2i(1920,1300); board.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(board)
	var canvas=Node2D.new(); board.add_child(canvas)
	var bg=ColorRect.new(); bg.size=Vector2(1920,1300); bg.color=Color("10141d"); canvas.add_child(bg)
	label(canvas,"APPROVED REFERENCE / native procedural comparison",Vector2(40,15),24)
	var source=Image.load_from_file(OS.get_environment("ARROW_REFERENCE_IMAGE"))
	var image_texture=ImageTexture.create_from_image(source)
	var atlas=AtlasTexture.new(); atlas.atlas=image_texture; atlas.region=Rect2(100,112,1570,360)
	var reference=TextureRect.new(); reference.texture=atlas; reference.position=Vector2(70,55); reference.size=Vector2(1780,408); reference.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST; canvas.add_child(reference)
	var premult=CanvasItemMaterial.new(); premult.blend_mode=CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	var row=0
	for length in [34.0,64.0,96.0,128.0]:
		var top=500+row*190
		label(canvas,"%dpx actual 1x"%length,Vector2(30,top),18)
		for col in 3:
			var vp=SubViewport.new(); vp.size=Vector2i(160,64); vp.transparent_bg=true; vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS; canvas.add_child(vp)
			var fx=FX.new(); vp.add_child(fx); var q=P.duplicate(true); q.length=length; q.body_style=1; q.lightning.arc_forks=1.4
			var tip=Vector2(145,32); var time=[.16,.48,.80][col]
			fx.play(tip,Vector2.RIGHT,q); fx.seek(time,func(_v): return {"tip":tip,"velocity":Vector2.RIGHT})
			var native=TextureRect.new(); native.texture=vp.get_texture(); native.material=premult; native.position=Vector2(30,top+20+col*43); native.size=Vector2(160,64); native.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST; canvas.add_child(native)
			var big=TextureRect.new(); big.texture=vp.get_texture(); big.material=premult; big.position=Vector2(220+col*555,top-10); big.size=Vector2(560,224); big.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST; canvas.add_child(big)
			label(canvas,"t=%.2fs / 3.5x"%time,Vector2(240+col*555,top+145),16)
		row+=1
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	board.get_texture().get_image().save_png(OS.get_environment("ARROW_CAPTURE_DIR").path_join("reference-board.png"))
	print("Saved native reference board")
	# Equal apparent arrow lengths, so a tiny source cannot hide visual differences.
	var hero=SubViewport.new(); hero.size=Vector2i(1920,1150); hero.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(hero)
	var hero_bg=ColorRect.new(); hero_bg.size=Vector2(1920,1150); hero_bg.color=Color("101119"); hero.add_child(hero_bg)
	label(hero,"APPROVED REFERENCE",Vector2(140,18),26)
	var ref=TextureRect.new(); ref.texture=atlas; ref.position=Vector2(140,60); ref.size=Vector2(1640,376); ref.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST; hero.add_child(ref)
	label(hero,"NATIVE GODOT / 256px source, 6x nearest / t=0.48s",Vector2(140,495),26)
	var large_vp=SubViewport.new(); large_vp.size=Vector2i(320,96); large_vp.transparent_bg=true; large_vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS; hero.add_child(large_vp)
	var actual=FX.new(); large_vp.add_child(actual); var config=P.duplicate(true); config.length=256; config.body_style=1; config.lightning.arc_forks=1.4
	var anchor=Vector2(290,48); actual.play(anchor,Vector2.RIGHT,config); actual.seek(.48,func(_v): return {"tip":anchor,"velocity":Vector2.RIGHT})
	var crop=AtlasTexture.new(); crop.atlas=large_vp.get_texture(); crop.region=Rect2(24,8,280,80)
	var big=TextureRect.new(); big.texture=crop; big.material=premult; big.position=Vector2(120,560); big.size=Vector2(1680,480); big.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST; hero.add_child(big)
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	hero.get_texture().get_image().save_png(OS.get_environment("ARROW_CAPTURE_DIR").path_join("reference-hero.png"))
	print("Saved native hero comparison"); quit()
