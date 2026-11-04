extends SceneTree
var n:int=0
var failures:int=0
func check(ok:bool,label:String)->void:
	n+=1
	if not ok: failures+=1; push_error(label)
func _initialize()->void: call_deferred("run")
func run()->void:
	var w=load("res://preview.tscn").instantiate(); root.add_child(w); await process_frame; w.paused=true
	w.select_preset(1); w.checks.ice.button_pressed=true
	check(w.profile.fire.enabled and w.profile.ice.enabled,"independent element toggles combine")
	w.edit_selector.selected=1; w._sync_sliders(); w.sliders.size.value=1.7
	check(is_equal_approx(w.profile.fire.size,1.7) and w.profile.ice.size==1,"selected element slider does not alter another layer")
	w.color_button.color_changed.emit(Color(.2,.7,1,.8))
	check(w.profile.fire.tint==Color(.2,.7,1,.8) and w.profile.ice.tint==Color.WHITE,"selected element color does not leak")
	w.edit_selector.selected=3; w._sync_sliders()
	check(w.color_button.color==Color.WHITE and w.sliders.size.value==1,"edit selector reads actual layer resources")
	w.checks.body.button_pressed=false
	check(not w.fx.profile.body_enabled and w.fx.profile.fire.enabled,"body can be hidden independently")
	w.cleared=true; w.fx.clear(); w.sliders.intensity.value=.5; w.select_preset(2); w.timeline.value=.5
	check(not w.fx.running,"clear survives parameter changes preset and scrub")
	w.replay(); check(w.fx.running,"replay restores after clear")
	check(w.sliders.trail_length.editable and w.sliders.size.editable and w.profile.lightning.trail_length==0,"lightning density and amplitude editable without tail")
	w.lightning_selector.item_selected.emit(0)
	w.sliders.trail_length.value=1.5
	check(w.profile.lightning.arc_density==1.5 and w.profile.lightning.trail_length==0 and w.profile.fire.arc_density==1,"density control affects lightning only")
	w.lightning_selector.item_selected.emit(2)
	var retained=w.profile.lightning.arc_density==1.5 and w.sliders.trail_length.value==1
	w.lightning_selector.item_selected.emit(0)
	check(retained and w.sliders.trail_length.value==1.5 and w.sliders.trail_length.max_value==2,"double visibility cap does not lose original density")
	w.lightning_selector.item_selected.emit(1)
	check(w.profile.lightning.lightning_mode==1 and w.fx.profile.lightning.lightning_mode==1,"mode selector restores micro arcs")
	w.lightning_selector.item_selected.emit(0)
	check(w.profile.lightning.lightning_mode==0 and w.profile.fire.lightning_mode==2 and w.profile.ice.lightning_mode==2,"spiral mode selection affects lightning only")
	w.cleared=true; w.fx.clear()
	for mode in [1,2,0]: w.lightning_selector.item_selected.emit(mode)
	check(not w.fx.running,"mode change does not revive cleared effect")
	w.replay(); w.select_preset(2)
	check(w.lightning_selector.selected==2,"preset restores double-helix mode and selector")
	check(w.sliders.trail_length.max_value==1 and w.slider_labels.trail_length.text.begins_with("Arc visibility"),"double helix exposes visibility rather than count")
	w.paused=true; w.time=.63; var before=w.profile.fire.duplicate(true)
	for mode in [0,1,2]: w.lightning_selector.item_selected.emit(mode)
	check(w.time==.63 and w.profile.fire.size==before.size and w.profile.fire.tint==before.tint and w.profile.ice.enabled==false,"three-way mode comparison preserves time and other elements")
	w.sliders.trail_length.value=.4
	check(w.profile.lightning.arc_density==.4 and w.profile.lightning.lightning_mode==2,"double-helix visibility control writes selected layer")
	w.paused=true; w.path_mode=3; var t=.6; var h=.0001
	var s=w.trajectory(t); var dv=(w.trajectory(t+h).tip-w.trajectory(t-h).tip)/(2*h)
	check(dv.distance_to(s.velocity)<.1,"curve velocity matches position derivative")
	w.path_mode=2; s=w.trajectory(t); dv=(w.trajectory(t+h).tip-w.trajectory(t-h).tip)/(2*h)
	check(dv.distance_to(s.velocity)<.1,"diagonal velocity matches position derivative")
	w.sliders.speed.value=60; check(w.timeline.max_value>4,"timeline covers slow flight")
	w.queue_free(); await process_frame
	print("PASS" if failures==0 else "FAIL"," workshop wiring: ",n," assertions; failures=",failures)
	quit(0 if failures==0 else 1)
