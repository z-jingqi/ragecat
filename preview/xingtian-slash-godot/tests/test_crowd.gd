extends SceneTree
const Stage=preload("../crowd_stage.gd")
var checks:=0
var failures:=0
func check(value:bool,message:String)->void:
	checks+=1
	if not value: failures+=1; push_error(message)
func _initialize()->void: call_deferred("run")
func run()->void:
	var stage=Stage.new(); root.add_child(stage)
	check(stage.contact_points.size()==3 and stage.hits.size()==6,"Three contacts in each of two waves")
	check(stage.live_contacts()==0,"Nothing happens before explicit scheduled contacts")
	stage.seek(.63); check(stage.live_contacts()==3,"Three distinct hits survive on the same frame")
	var ids:={}
	for i in 3:
		var effect=stage.hits[i].node
		ids[effect.get_instance_id()]=true
		check(effect.impact.started and effect.blood.started and effect.arc.started==false,"Only per-target contact layers start")
	check(ids.size()==3,"Every target owns a separate impact instance")
	check(stage.hits[0].node.impact.position!=stage.hits[1].node.impact.position,"Contacts remain spatially separate")
	var shape=stage.hits[0].node.impact.samples()
	stage.seek(.69); stage.seek(.63); check(stage.hits[0].node.impact.samples()==shape,"Scrub is deterministic")
	stage.configure(1); stage.seek(.63); check(stage.live_contacts()==1,"Stagger is not silently converted to simultaneous hits")
	stage.seek(.8); check(stage.live_contacts()==6,"All six staggered contacts remain alive")
	stage.configure(2); stage.seek(.85); check(stage.live_contacts()==12,"Overlapping waves keep the preceding six blood tails")
	check(stage.hits[0].node.blood.started and stage.hits[6].node.blood.started,"New wave cannot overwrite previous wave")
	stage.set_blood(false)
	check(not stage.hits[0].node.blood.visible and stage.hits[6].node.impact.visible,"Blood is independently disabled across all waves")
	check(stage.live_contacts()==6,"Disabled blood tails are excluded from active count")
	stage.configure(0); stage.seek(.63); check(not stage.hits[0].node.blood.visible,"Scenario switch keeps blood preference")
	var before:Vector2=stage.contact_points[0]; stage.set_facing(true)
	check(is_equal_approx(stage.contact_points[0].x,-before.x) and is_equal_approx(stage.contact_points[0].y,before.y),"Mirror reflects contacts around hero without changing height")
	stage.clear(); stage.seek(.63); stage.set_facing(false)
	check(stage.cleared and stage.live_contacts()==0,"Clear survives scrubbing and mirror edits")
	stage.restart(); stage.seek(.63); check(stage.live_contacts()==3,"Only explicit replay starts cleared contacts")
	stage.seek(3.6); check(stage.live_contacts()==0,"Each scene clears before the loop boundary")
	var count=stage.get_child_count(); stage.configure(0); check(stage.get_child_count()==count,"Scenario rebuild does not leak effect children")
	var saved:float=stage.clock; stage.seek(NAN); check(stage.clock==saved,"Nonfinite time is ignored")
	stage.free()
	var scene=load("res://crowd_preview.tscn").instantiate(); root.add_child(scene); await process_frame; scene.set_process(false)
	scene.select_scenario(2); scene.seek_all(.85)
	check(scene.stage.live_contacts()==12 and scene.detail.live_contacts()==12,"Both viewports share the same contact clock")
	check(scene.stage.hits[6].node.impact.samples()==scene.detail.hits[6].node.impact.samples(),"Magnified view is the same geometry, not a denser effect")
	scene.clear_all(); scene.timeline.value=.85; check(scene.stage.cleared and scene.detail.cleared,"UI clear does not resurrect either viewport")
	scene.replay(); scene.seek_all(.85); check(scene.stage.live_contacts()==12,"UI replay restores the dense scenario")
	scene.blood_button.button_pressed=false; check(not scene.stage.hits[6].node.blood.visible and not scene.detail.hits[6].node.blood.visible,"UI blood checkbox applies to both views")
	check(scene.status.text.begins_with("6 active"),"Paused blood toggle immediately refreshes the UI counter")
	scene.seek_all(3.6); scene.clear_all(); scene.paused=false; scene._process(1.0/60.0)
	check(scene.stage.cleared and scene.detail.cleared,"Clear survives Resume at the loop boundary")
	scene.free()
	print("XINGTIAN_CROWD: %d checks, %d failures"%[checks,failures]); quit(1 if failures else 0)
