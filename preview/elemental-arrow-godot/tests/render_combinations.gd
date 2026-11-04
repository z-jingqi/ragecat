extends SceneTree
var n:int=0
var failures:int=0
func check(ok:bool,label:String)->void:
	n+=1
	if not ok: failures+=1; push_error(label)
func _initialize()->void: call_deferred("run")
func capture(w:Node2D)->Image:
	w.refresh(); await process_frame; await process_frame; await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func run()->void:
	var folder=OS.get_environment("ARROW_CAPTURE_DIR")
	var w=load("res://preview.tscn").instantiate(); root.add_child(w); await process_frame; w.paused=true
	for light in [false,true]:
		w.fixture.light_background=light; w.fixture.queue_redraw()
		for mask in 8:
			w.select_preset(0); w.path_mode=3; w.time=.67; w.paused=true
			for i in 3: w.checks[["fire","lightning","ice"][i]].button_pressed=bool(mask&(1<<i))
			var im=await capture(w)
			var again=await capture(w)
			check(im.get_data()==again.get_data(),"same-time deterministic mix "+str(mask))
			if not folder.is_empty(): im.save_png(folder.path_join("mix-%d-%s.png"%[mask,"light" if light else "dark"]))
	w.cleared=true; w.fx.clear(); w.sliders.length.value=55; w.timeline.value=.9
	var empty=await capture(w); check(not w.fx.running,"clear stays off after native controls")
	if not folder.is_empty(): empty.save_png(folder.path_join("cleared.png"))
	print("PASS" if failures==0 else "FAIL"," native composition: ",n," assertions; failures=",failures)
	quit(0 if failures==0 else 1)
