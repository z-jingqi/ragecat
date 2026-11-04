extends SceneTree
## Native-only framebuffer checks for the standalone multi-target presentation.
var scene
var checks:=0
var failures:=0
var records:Array=[]
const ARENA=Rect2i(28,158,760,490)
func _initialize()->void: call_deferred("run")
func check(value:bool,message:String)->void:
	checks+=1
	if not value: failures+=1; push_error(message)
func shot(name_value:String)->Image:
	await process_frame
	await RenderingServer.frame_post_draw
	var result:Image=root.get_texture().get_image()
	var folder:=OS.get_environment("XINGTIAN_CROWD_CAPTURE_DIR")
	if not folder.is_empty(): result.save_png(folder.path_join(name_value+".png"))
	return result
func differences(a:Image,b:Image,rect:Rect2i)->int:
	var n:=0
	for y in range(rect.position.y,rect.end.y):
		for x in range(rect.position.x,rect.end.x):
			if a.get_pixel(x,y)!=b.get_pixel(x,y): n+=1
	return n
func run()->void:
	scene=load("res://crowd_preview.tscn").instantiate(); root.add_child(scene); scene.set_process(false)
	var canvas:=await shot("canvas")
	check(canvas.get_width()==1280 and canvas.get_height()==800,"Native framebuffer has the requested logical resolution")
	for mode in 3:
		scene.select_scenario(mode); scene.seek_all(0)
		var baseline:=await shot("mode-%d-empty"%mode)
		var time_value:=.63 if mode==0 else (.80 if mode==1 else .85)
		scene.seek_all(time_value)
		var active:=await shot("mode-%d-hit"%mode)
		var changed:=differences(active,baseline,ARENA)
		check(changed>100,"Mode %d draws visible effect pixels at 1x"%mode)
		var matches:=0; var mask_pixels:=0
		for dy in range(-130,70):
			for dx in range(-100,100):
				var p:=Vector2i(388+dx,448+dy)
				var q:=Vector2i(1022+dx*2,452+dy*2)
				var a:=active.get_pixelv(p)!=baseline.get_pixelv(p)
				var b:=active.get_pixelv(q)!=baseline.get_pixelv(q)
				if a or b:
					mask_pixels+=1
					if a==b: matches+=1
		var agreement:=float(matches)/maxi(1,mask_pixels)
		check(agreement>.95,"Mode %d 2x detail preserves the 1x changed-pixel mask"%mode)
		scene.seek_all(time_value+.03); await shot("mode-%d-advance"%mode); scene.seek_all(time_value)
		check(differences(active,await shot("mode-%d-repeat"%mode),ARENA)==0,"Mode %d seeks back to exactly the same framebuffer"%mode)
		scene.clear_all(); var cleared:=await shot("mode-%d-clear"%mode)
		check(differences(cleared,baseline,ARENA)==0,"Mode %d clear leaves only the unchanged hero and test enemies"%mode)
		scene.paused=false; scene._process(4.0)
		check(differences(await shot("mode-%d-clear-resume"%mode),baseline,ARENA)==0,"Mode %d Resume cannot undo clear at the loop boundary"%mode)
		records.append({"mode":mode,"effect_pixels_1x":changed,"magnification_mask_agreement":agreement})
	scene.select_scenario(2); scene.seek_all(.85)
	var with_blood:=await shot("dense-blood-on")
	scene.blood_button.button_pressed=false
	var no_blood:=await shot("dense-blood-off")
	check(differences(with_blood,no_blood,ARENA)>10,"Blood checkbox changes native pixels in the dense overlap")
	check(scene.stage.live_contacts()==6,"Blood-off counter excludes invisible old tails")
	scene.stage.set_facing(true); scene.detail.set_facing(true)
	check(differences(no_blood,await shot("dense-mirrored"),ARENA)>100,"Mirror changes the actual portrait and contact presentation")
	scene.replay(); scene.seek_all(3.6); var ended:=await shot("dense-end")
	scene.seek_all(0); check(differences(ended,await shot("dense-reset"),ARENA)==0,"Final wave leaves no persistent pixels")
	# Isolate the approved portrait from enemy geometry and effect pixels, then
	# compare its warm-color silhouette about the fixed foot anchor.
	scene.stage.set_facing(false); scene.stage.enemies.clear(); scene.stage.seek(0)
	var portrait_right:=await shot("portrait-right-anchor")
	scene.stage.set_facing(true); scene.stage.enemies.clear(); scene.stage.seek(0)
	var portrait_left:=await shot("portrait-left-anchor")
	var foreground:=0; var matched:=0
	for y in range(365,480):
		for x in range(288,488):
			var a:=portrait_right.get_pixel(x,y); var b:=portrait_left.get_pixel(775-x,y)
			var ra:=a.r>a.b*1.05 and a.r>.08
			var rb:=b.r>b.b*1.05 and b.r>.08
			if ra or rb:
				foreground+=1
				if ra==rb: matched+=1
	check(foreground>200 and float(matched)/maxi(1,foreground)>.98,"Portrait mirrors about the fixed foot anchor without horizontal displacement")
	var folder:=OS.get_environment("XINGTIAN_CROWD_CAPTURE_DIR")
	if not folder.is_empty():
		var file:=FileAccess.open(folder.path_join("crowd-render.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks":checks,"failures":failures,"cases":records},"  "))
	print("XINGTIAN_CROWD_GPU: %d checks, %d failures"%[checks,failures]); scene.free(); quit(1 if failures else 0)
