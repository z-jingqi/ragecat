extends SceneTree
func _init()->void:call_deferred("run")
func run()->void:
	var d=load("res://effects/VFX-20_shield_heal/support.tscn").instantiate();root.add_child(d)
	d.toggle_pause();assert(d.paused);d.step_frame();assert(d.paused)
	d.apply_preset(2);assert(d.fx.config.mode=="heal")
	for key in ["body","core","edge","plus"]:
		d.set_palette_color(key,Color("ff5500"));assert(d.fx.config[key]=="ff5500");assert(d.color_pickers[key].color==Color("ff5500"))
	d.reset_all();assert(not d.paused);assert(d.fx.config.mode=="shield")
	d.fx.hit(Vector2.RIGHT);assert(d.fx.impact_age>=0)
	d.fx.break_shield();assert(d.fx.broken)
	d.trigger();assert(not d.fx.broken)
	d.queue_free();print("SUPPORT DEMO 16 checks");quit()
