extends SceneTree
# Component regression for the optional sustained pair / short peak geometry.
# Default transient lifecycle is covered by test/render_wandering_lightning.
const L=preload("../modules/lightning_reference.gd")
const FX=preload("../components/elemental_arrow.gd")
const P=preload("../presets/lightning.tres")
class GeometryMask extends Node2D:
	var events=[]
	func _draw()->void:
		# Only the coarse carrier: no brightness, noise, branches, glow or body.
		for event in events:
			for i in range(event.carrier.size()-1):
				draw_line((event.carrier[i]+Vector2(280,50)).round(),(event.carrier[i+1]+Vector2(280,50)).round(),Color.WHITE,1,false)
var count=0
var failures=0
func check(ok:bool,label:String)->void:
	count+=1
	if not ok: failures+=1; push_error(label)
func _initialize()->void: call_deferred("run")
func run()->void:
	if DisplayServer.get_name()=="headless": push_error("Real renderer required"); quit(2); return
	var folder=OS.get_environment("ARROW_CAPTURE_DIR")
	var vp=SubViewport.new(); vp.size=Vector2i(360,100); vp.transparent_bg=true; vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(vp)
	var mask=GeometryMask.new(); vp.add_child(mask)
	var a=P.lightning.duplicate(true); a.arc_wandering=false; a.arc_jitter=0; a.arc_forks=0; a.glow=0
	for length in [64.0,96.0,128.0,256.0]:
		var previous:Image; var difference_sum=0.0; var changed=0
		for strike in 25:
			mask.events=L.arcs_at((strike+.2)/12.0,length,1,a); mask.queue_redraw()
			await process_frame; await process_frame; await RenderingServer.frame_post_draw
			var current=vp.get_texture().get_image()
			if previous:
				var union_pixels=0; var different=0
				for y in 100:
					for x in 360:
						var old=previous.get_pixel(x,y).a>.5; var fresh=current.get_pixel(x,y).a>.5
						if old or fresh: union_pixels+=1
						if old!=fresh: different+=1
				var ratio=float(different)/maxi(1,union_pixels); difference_sum+=ratio
				if ratio>=.30: changed+=1
			previous=current
		check(changed>=18,"real geometry-only raster moves without brightness or fine jitter, length "+str(length))
		print("Geometry raster length=",length," changed=",changed,"/24 mean XOR/union=",difference_sum/24)
	mask.queue_free(); vp.queue_free(); await process_frame
	var board=SubViewport.new(); board.size=Vector2i(1280,800); board.transparent_bg=false; board.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(board)
	var bg=ColorRect.new(); bg.size=board.size; bg.color=Color("101119"); board.add_child(bg)
	var times=[.02,.11,.19,.27]
	var premult=CanvasItemMaterial.new(); premult.blend_mode=CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	for i in 4:
		var label=Label.new(); label.position=Vector2(25,25+i*190); label.text="Actual main path / %.2fs / 256px at 3x"%times[i]; label.add_theme_font_size_override("font_size",18); board.add_child(label)
		var row=SubViewport.new(); row.size=Vector2i(320,56); row.transparent_bg=true; row.render_target_update_mode=SubViewport.UPDATE_ALWAYS; board.add_child(row)
		var fx=FX.new(); row.add_child(fx)
		var q=P.duplicate(true); q.length=256; q.lightning.arc_wandering=false; fx.play(Vector2(290,28),Vector2.RIGHT,q); fx.age=times[i]; fx.queue_redraw()
		var panel=TextureRect.new(); panel.texture=row.get_texture(); panel.material=premult; panel.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		panel.position=Vector2(160,42+i*190); panel.size=Vector2(960,168); board.add_child(panel)
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	if not folder.is_empty(): board.get_texture().get_image().save_png(folder.path_join("dynamic-main-paths.png"))
	print("PASS" if failures==0 else "FAIL"," native dynamic reference: ",count," assertions; failures=",failures)
	quit(0 if failures==0 else 1)
