extends SceneTree
var count=0
var failures=0
func check(ok:bool,label:String)->void:
	count+=1
	if not ok: failures+=1; push_error(label)
func _initialize()->void: call_deferred("run")
func run()->void:
	if DisplayServer.get_name()=="headless": quit(2); return
	var w=load("res://reference_preview.tscn").instantiate(); root.add_child(w); await process_frame; w.paused=true
	for phase in 6:
		for t in [.15,.95,1.75]:
			w.time=phase*2+t; w._process(0)
			await process_frame; await process_frame; await RenderingServer.frame_post_draw
			for i in 4:
				var vp=w.effects[i].get_parent(); var rect=vp.get_texture().get_image().get_used_rect()
				check(rect.has_area() and rect.position.x>0 and rect.position.y>0 and rect.end.x<vp.size.x and rect.end.y<vp.size.y,"unclipped design/game panel %d phase %d t%.2f"%[i,phase,t])
			if is_equal_approx(t,.95):
				var folder=OS.get_environment("ARROW_CAPTURE_DIR")
				if not folder.is_empty(): root.get_texture().get_image().save_png(folder.path_join("restored-pose-%d.png"%phase))
	var held=w.time; await process_frame; check(w.time==held,"paused preview preserves time")
	w.replay(); check(not w.paused and w.time==0,"Replay resumes paused presentation")
	check(w.effects[0].age==0 and w.effects[1].age==0,"Replay resets every effect clock")
	w.paused=true
	w.toggle_background(); check(w.light and w.background.color==Color("d7d2c4"),"light background control works")
	w.toggle_background(); check(not w.light,"dark background restored")
	print("PASS" if failures==0 else "FAIL"," native reference presentation: ",count," assertions; failures=",failures)
	w.queue_free(); await process_frame; quit(0 if failures==0 else 1)
