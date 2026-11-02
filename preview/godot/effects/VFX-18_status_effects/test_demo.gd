extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var d=load("res://effects/VFX-18_status_effects/status.tscn").instantiate();root.add_child(d);d.set_process(false)
 d.selector.select(1);d.replay();d.tick(0.2);assert(d.fx[0].states.size()==4)
 d.fx[0].remove_status("burning");d.tick(0.3);assert(d.fx[0].states.size()==3)
 d.intensity_slider.value=0;assert(d.fx[0].intensity==0)
 d.move_host=true;d.tick(0.1);assert(d.hosts[0].position.x!=58)
 d.reset();assert(not d.move_host and d.fx[0].states.size()==1)
 d.tick(4);assert(d.fx[0].states.is_empty())
 print("STATUS DEMO PASSED 6 checks");quit()
