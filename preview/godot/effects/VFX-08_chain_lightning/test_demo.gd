extends SceneTree
var checks:=0
var failed:=false
func check(v:bool,s:String)->void:
	checks+=1
	if not v:failed=true;push_error(s)
func _initialize()->void:call_deferred("run")
func run()->void:
	var d=load("res://effects/VFX-08_chain_lightning/chain.tscn").instantiate();root.add_child(d);d.set_process(false)
	check(d.enemies.size()==6,"six targets");d.advance(0.04);check(d.enemies[0].order==-1,"no early hit");d.advance(0.025);check(d.enemies[0].order==0,"first arrival hit")
	d.sliders.max_targets.value=2;check(d.fx.config.max_targets==2,"count slider")
	d.sliders.jump_range.value=20;d.advance(1);check(d.fx.visited.is_empty(),"range slider")
	d.reset_all();check(d.fx.config.max_targets==5 and not d.paused and not d.moving,"reset")
	d.moving=true;d.advance(0.02);check(d.enemies[0].position!=d.enemies[0].base,"moving")
	d.fx.clear();d.loops=false;d.advance(10);check(not d.fx.active,"clear no auto")
	d.enemies[2].live=false;d.trigger();d.advance(1);check(not d.fx.visited.has(d.enemies[2].get_instance_id()),"removed skipped")
	d.free();print("CHAIN_DEMO_CHECKS_PASSED ",checks);quit(1 if failed else 0)
