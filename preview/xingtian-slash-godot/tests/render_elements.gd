extends SceneTree
const Profile=preload("../elements/element_profile.gd")
const Slash=preload("../elements/elemental_slash.gd")
var checks:=0
var failures:=0
var records:Array=[]
var folder:=OS.get_environment("ELEMENT_SLASH_CAPTURE_DIR")
func _initialize()->void: call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func capture(name_value:String,view:Viewport)->Image:
	await process_frame; await RenderingServer.frame_post_draw
	var image:=view.get_texture().get_image()
	if not folder.is_empty(): image.save_png(folder.path_join(name_value+".png"))
	return image
func count(image:Image)->int:
	var n:=0
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x,y).a>.01: n+=1
	return n
func hash_image(image:Image)->String: return image.get_data().hex_encode().sha256_text()
func diff(a:Image,b:Image)->int:
	var n:=0
	for y in a.get_height():
		for x in a.get_width():
			if a.get_pixel(x,y)!=b.get_pixel(x,y): n+=1
	return n
func run()->void:
	var view:=SubViewport.new(); view.size=Vector2i(256,224); view.transparent_bg=true; view.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(view)
	var effect=Slash.new(); view.add_child(effect)
	for element in 3:
		var p=Profile.new(); p.element=element; p.apply_palette(); effect.play(Vector2(128,120),p)
		check(count(await capture("%d-zero"%element,view))==0,"Element %d empty at zero"%element)
		effect.seek(.025); var early:=await capture("%d-sweep"%element,view)
		effect.seek(.08); var peak:=await capture("%d-peak"%element,view)
		check(count(peak)>250,"Element %d readable native silhouette"%element)
		check(diff(early,peak)>100,"Element %d sweeps out"%element)
		effect.seek(.29); var tail:=await capture("%d-tail"%element,view)
		check(count(tail)<count(peak),"Element %d dissolves"%element)
		effect.seek(effect.lifetime()); check(count(await capture("%d-end"%element,view))==0,"Element %d complete cleanup"%element)
		effect.seek(.08); check(hash_image(await capture("%d-repeat"%element,view))==hash_image(peak),"Element %d deterministic seek"%element)
		effect.set_layer_enabled("attachment",false); var bare:=await capture("%d-bare"%element,view)
		check(diff(peak,bare)>25,"Element %d rim switch changes rendered pixels"%element)
		effect.set_layer_enabled("attachment",true); effect.set_layer_enabled("arc",false)
		var rim:=await capture("%d-rim"%element,view); check(count(rim)>25,"Element %d independent rim"%element)
		effect.set_layer_enabled("arc",true)
		p.facing_left=true; effect.play(Vector2(128,120),p); effect.seek(.08)
		check(diff(await capture("%d-mirror"%element,view),peak)>200,"Element %d mirror changes rendered direction"%element)
		p.attachment_strength=0.; effect.play(Vector2(128,120),p); effect.set_layer_enabled("arc",false); effect.seek(.2)
		check(count(await capture("%d-rim-zero"%element,view))==0,"Element %d strength zero suppresses all attachments"%element)
		effect.set_layer_enabled("arc",true)
		p=Profile.new(); p.element=element; p.apply_palette(); p.radius=88; p.edge_reach=25; p.attachment_count=12; p.debris_count=16
		effect.play(Vector2(128,120),p); effect.seek(.09); var max_image:=await capture("%d-max"%element,view)
		var border:=0
		for y in max_image.get_height():
			for x in max_image.get_width():
				if (x<4 or x>=252 or y<4 or y>=220) and max_image.get_pixel(x,y).a>.01: border+=1
		check(border==0,"Element %d maximum stays in bounds"%element)
		effect.clear(); effect.seek(.08); check(count(await capture("%d-clear"%element,view))==0,"Element %d clear survives seek"%element)
		records.append({"element":element,"peak_pixels":count(peak),"rim_pixels":count(rim),"tail_pixels":count(tail)})
	view.free()
	var scene=load("res://elemental_preview.tscn").instantiate(); root.add_child(scene); scene.set_process(false); scene.paused=true
	scene.seek_all(.23); await capture("workshop-peak",root)
	for i in 3:
		var detail:=await capture("detail-%d"%i,scene.views[i*2]); var game:=await capture("game-%d"%i,scene.views[i*2+1])
		check(detail.get_width()==128 and game.get_width()==384,"Element %d true integer detail and native game view"%i)
	for left in [false,true]:
		scene.mirror_button.button_pressed=left
		for age in [.025,.06,.08,.16,.25,.35,.5]:
			scene.seek_all(age+.15)
			await process_frame; await RenderingServer.frame_post_draw
			for i in 3:
				var image:Image=scene.views[i*2].get_texture().get_image()
				var bg:=image.get_pixel(0,0); var edge:=0
				for x in image.get_width():
					if image.get_pixel(x,0)!=bg or image.get_pixel(x,image.get_height()-1)!=bg: edge+=1
				for y in image.get_height():
					if image.get_pixel(0,y)!=bg or image.get_pixel(image.get_width()-1,y)!=bg: edge+=1
				check(edge==0,"Element %d default detail fits phase %.3f mirrored %s"%[i,age,left])
	scene.mirror_button.button_pressed=false
	scene.seek_all(.175); await capture("workshop-sweep",root)
	scene.seek_all(.44); await capture("workshop-dissolve",root)
	scene.clear_all(); scene.sliders.radius.value=88; scene.sliders.edge_reach.value=25; scene.sliders.attachment_count.value=12; scene.sliders.debris_count.value=16
	check(scene.cleared and not scene.effects[0].started,"Native controls preserve Clear")
	await capture("workshop-cleared",root)
	scene.replay(); scene.set_process(false); scene.paused=true; scene.seek_all(.23); await capture("workshop-max",root)
	for i in 3:
		var image:=await capture("max-detail-%d"%i,scene.views[i*2])
		var bg:=image.get_pixel(0,0); var edge:=0
		for x in image.get_width():
			if image.get_pixel(x,0)!=bg or image.get_pixel(x,image.get_height()-1)!=bg: edge+=1
		for y in image.get_height():
			if image.get_pixel(0,y)!=bg or image.get_pixel(image.get_width()-1,y)!=bg: edge+=1
		check(edge==0,"Element %d detail fits maximum settings without cropping"%i)
	for configuration in [[73.,3.],[54.,15.],[20.,25.],[78.,3.],[52.,17.],[40.,25.]]:
		scene.sliders.radius.value=configuration[0]; scene.sliders.edge_reach.value=configuration[1]
		for left in [false,true]:
			scene.mirror_button.button_pressed=left; scene.seek_all(.23)
			await process_frame; await RenderingServer.frame_post_draw
			for i in 3:
				var image:Image=scene.views[i*2].get_texture().get_image()
				var bg:=image.get_pixel(0,0); var edge:=0
				for x in image.get_width():
					if image.get_pixel(x,0)!=bg or image.get_pixel(x,image.get_height()-1)!=bg: edge+=1
				for y in image.get_height():
					if image.get_pixel(0,y)!=bg or image.get_pixel(image.get_width()-1,y)!=bg: edge+=1
				check(edge==0,"Element %d mixed radius/reach %s mirror %s fits"%[i,configuration,left])
	scene.free()
	if not folder.is_empty():
		var file:=FileAccess.open(folder.path_join("render-results.json"),FileAccess.WRITE); file.store_string(JSON.stringify({"checks":checks,"failures":failures,"cases":records},"  "))
	print("ELEMENT_SLASH_GPU: %d checks, %d failures"%[checks,failures]); quit(1 if failures else 0)
