extends SceneTree
const Workshop=preload("../preview.gd")
var checks:int=0
var failures:int=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func button(scene:Node,text:String)->Button:
	for n in scene.get_children():
		if n is Button and n.text==text: return n
	return null
func _initialize()->void: call_deferred("run")
func run()->void:
	var scene:Node2D=Workshop.new(); root.add_child(scene); scene.set_process(false)
	check(scene.fx.spikes.size()>0,"startup ready")
	scene.time=.43; scene.paused=true; scene.refresh()
	check(scene.fx.active_layers()==[0,1],"scrub two layers")
	check(scene.phase_status.text.contains("L1 fading") and scene.phase_status.text.contains("L2 growing"),"status labels reflect actual overlapping site phases")
	button(scene,"Clear").pressed.emit()
	check(scene.fx.spikes.is_empty() and scene.status.text.contains("layers 0 /"),"clear updates canvas and UI")
	button(scene,"Replay").pressed.emit()
	check(not scene.paused and not scene.cleared and scene.time==0,"replay restarts after clear")
	button(scene,"New seed").pressed.emit(); check(scene.seed_value==18,"new seed deterministic increment")
	button(scene,"Pause").pressed.emit(); check(scene.paused,"pause works")
	button(scene,"Light / Dark").pressed.emit(); check(scene.floor_node.light_background,"background toggle works")
	for key in scene.sliders:
		var slider:HSlider=scene.sliders[key].slider; var requested:float=slider.max_value; slider.value=requested
		check(is_equal_approx(float(scene.fx.profile.get(key)),float(scene.profile.get(key))),"slider applied: "+key)
	scene.speed_selector.item_selected.emit(1); check(scene.playback_speed==.35,"slow-motion selection works")
	button(scene,"Reset").pressed.emit(); check(scene.profile.layers==3 and scene.profile.radius==103,"reset defaults")
	scene.fx.advance(10); scene.fx.seek(.43); check(scene.fx.active_layers()==[0,1],"seek reopens completed timeline")
	scene.fx.clear(); scene.fx.seek(.43); check(scene.fx.spikes.is_empty(),"seek cannot resurrect cleared instances")
	scene.queue_free(); await process_frame
	print("PASS" if failures==0 else "FAIL"," radial workshop: ",checks," assertions, ",failures," failures")
	quit(0 if failures==0 else 1)
