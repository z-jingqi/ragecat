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
	w.lightning_selector.item_selected.emit(3)
	check(w.profile.lightning.arc_density==1.5 and w.sliders.trail_length.value==1,"reference cap preserves saved original density")
	w.lightning_selector.item_selected.emit(0)
	check(w.sliders.trail_length.value==1.5,"reference to spiral restores density")
	w.lightning_selector.item_selected.emit(1)
	check(w.profile.lightning.lightning_mode==1 and w.fx.profile.lightning.lightning_mode==1,"mode selector restores micro arcs")
	w.lightning_selector.item_selected.emit(0)
	check(w.profile.lightning.lightning_mode==0 and w.profile.fire.lightning_mode==3 and w.profile.ice.lightning_mode==3,"spiral mode selection affects lightning only")
	w.cleared=true; w.fx.clear()
	for mode in [1,2,3,0]: w.lightning_selector.item_selected.emit(mode)
	check(not w.fx.running,"mode change does not revive cleared effect")
	w.replay(); w.select_preset(2)
	check(w.lightning_selector.selected==3,"preset restores reference mode and selector")
	check(w.sliders.trail_length.max_value==1 and w.slider_labels.trail_length.text.begins_with("Arc visibility"),"reference exposes visibility rather than count")
	w.paused=true; w.time=.63; var before=w.profile.fire.duplicate(true)
	for mode in [0,1,2,3]: w.lightning_selector.item_selected.emit(mode)
	check(w.time==.63 and w.profile.fire.size==before.size and w.profile.fire.tint==before.tint and w.profile.ice.enabled==false,"four-way mode comparison preserves time and other elements")
	w.sliders.trail_length.value=.4
	check(w.profile.lightning.arc_density==.4 and w.profile.lightning.lightning_mode==3,"reference visibility control writes selected layer")
	w.paused=true; w.path_mode=3; var t=.6; var h=.0001
	var s=w.trajectory(t); var dv=(w.trajectory(t+h).tip-w.trajectory(t-h).tip)/(2*h)
	check(dv.distance_to(s.velocity)<.1,"curve velocity matches position derivative")
	w.path_mode=2; s=w.trajectory(t); dv=(w.trajectory(t+h).tip-w.trajectory(t-h).tip)/(2*h)
	check(dv.distance_to(s.velocity)<.1,"diagonal velocity matches position derivative")
	w.sliders.speed.value=60; check(w.timeline.max_value>4,"timeline covers slow flight")
	w.select_preset(2); check(w.profile.body_style==1 and w.profile.length==96 and w.body_selector.selected==1,"reference preset uses dedicated scalable body")
	w.cleared=true; w.fx.clear(); w.body_selector.item_selected.emit(0)
	check(w.profile.body_style==0 and not w.fx.running,"classic body restored without reviving Clear")
	w.path_mode=0; var start_right=w.trajectory(0).tip.x
	w.path_mode=1; var start_left=w.trajectory(0).tip.x
	check(start_right-w.profile.length>0 and start_left+w.profile.length<380,"long Classic arrow also fits both starting poses")
	w.body_selector.item_selected.emit(1); w.replay(); w.paused=true; w.time=.63
	w.sliders.length.value=128; w.path_mode=2
	check(w.scale_label.text.begins_with("128px"),"scale label follows actual length")
	var profile=load("res://components/arrow_profile.gd").new(); profile.length=999; profile.body_style=99; profile=profile.sanitized()
	check(profile.length==256 and profile.body_style==1,"design-scale length and body style bounded")
	w.queue_free(); await process_frame
	print("PASS" if failures==0 else "FAIL"," workshop wiring: ",n," assertions; failures=",failures)
	quit(0 if failures==0 else 1)
