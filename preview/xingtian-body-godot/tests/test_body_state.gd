extends SceneTree
const Body=preload("../components/body_state.gd")
const Profile=preload("../components/body_profile.gd")
const Preview=preload("../preview.gd")
var checks: int=0
var failures: int=0
func check(value: bool, message: String) -> void:
	checks+=1
	if not value: failures+=1; push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var a=Body.new(); var b=Body.new(); root.add_child(a); root.add_child(b)
	check(a.texture==b.texture,"Portrait texture shared")
	check(a.material!=b.material,"Instance materials independent")
	check(a.material.get_shader_parameter("seam_map")==b.material.get_shader_parameter("seam_map"),"Static seam data shared")
	check(a.amount==0 and a.elapsed==0,"Starts original")
	a.set_amount(0.5); a.advance(1.2)
	check(is_equal_approx(a.amount,0.5) and is_equal_approx(a.elapsed,1.2),"External clock and amount are independent")
	check(b.amount==0 and b.elapsed==0,"Instances isolated")
	a.advance(-1); a.advance(NAN); a.advance(INF)
	check(is_equal_approx(a.elapsed,1.2),"Invalid delta ignored")
	a.seek(0.2); check(is_equal_approx(a.elapsed,0.2),"Backward seek supported")
	a.seek(-1); a.seek(INF); check(is_equal_approx(a.elapsed,0.2),"Invalid seek ignored")
	a.set_amount(4); check(a.amount==1,"Amount upper bound")
	a.set_amount(-4); check(a.amount==0,"Amount lower bound")
	a.set_amount(0.7); a.set_amount(NAN); check(is_equal_approx(a.amount,0.7),"Nonfinite amount ignored")
	var p=Profile.new(); p.intensity=0.6; a.configure(p); p.intensity=1.4
	check(is_equal_approx(a.profile.intensity,0.6),"Profile snapshot isolates caller edits")
	check(is_equal_approx(b.profile.intensity,1.0),"Profile isolated per instance")
	p.intensity=NAN; p.local_glow=INF; p.flow_speed=-3; p.breathing=100; p.flow_strength=8
	a.configure(p)
	check(is_equal_approx(a.profile.intensity,1.0),"NaN intensity sanitized")
	check(is_equal_approx(a.profile.local_glow,0.24),"Infinity glow sanitized")
	check(a.profile.flow_speed==0 and is_equal_approx(a.profile.breathing,0.2) and a.profile.flow_strength==1,"Bounds sanitized")
	a.configure(Resource.new()); check(a.profile is Profile,"Unexpected resource safe fallback")
	a.clear(); a.seek(4); a.advance(5); a.set_amount(1); a.configure(Profile.new())
	check(a.amount==0 and a.elapsed==0 and not a.active,"Clear is stable through seek, advance, amount and configure")
	check(a.material.get_shader_parameter("amount")==0,"Clear reaches shader")
	a.start(0.8); check(a.active and is_equal_approx(a.amount,0.8),"Explicit start restores")
	a.start(NAN); check(a.amount==0 and a.elapsed==0 and a.material.get_shader_parameter("amount")==0,"Invalid start atomically resets to original")
	a.start(0.8)
	a.seek(1.7e308); a.advance(1.7e308); check(is_finite(a.elapsed),"Finite elapsed overflow rejected")
	check(is_finite(a.material.get_shader_parameter("breathing_phase")) and is_finite(a.material.get_shader_parameter("flow_phase")),"Large clocks never upload infinite shader values")
	a.seek(20); check(is_equal_approx(a.amount,0.8),"Component never implements gameplay decay")
	check(Preview.sample_amount(0)==0 and Preview.sample_amount(1)==0,"Demo starts normal")
	check(Preview.sample_amount(3)>0 and Preview.sample_amount(3)<1,"Demo intermediate build")
	check(Preview.sample_amount(5)==1 and Preview.sample_amount(7)==1,"Demo full hold")
	check(Preview.sample_amount(9)>0 and Preview.sample_amount(9)<1,"Demo decay")
	check(Preview.sample_amount(11)==0 and Preview.sample_amount(12)==0,"Demo ends exactly original")
	check(Preview.sample_amount(NAN)==0,"Demo invalid time safe")
	var previous: float=0
	for i in range(41):
		var value=Preview.sample_amount(1+i*0.1); check(value>=previous,"Monotonic build %d"%i); previous=value
	previous=1
	for i in range(41):
		var value=Preview.sample_amount(7+i*0.1); check(value<=previous,"Monotonic decay %d"%i); previous=value
	var scene=load("res://preview.tscn").instantiate(); root.add_child(scene); await process_frame
	scene._clear(); scene.timeline.value=5; scene.state_slider.value=1; scene.settings.intensity=1.5; scene._configure()
	check(scene.actor.amount==0 and not scene.actor.active,"Preview clear remains off under controls")
	scene._start_cycle(5); check(scene.actor.active and scene.actor.amount==1,"Preview replay restores")
	scene._manual(0); check(scene.actor.amount==0 and not scene.automatic,"Normal button keeps exact baseline")
	scene._toggle_background(); check(scene.phase_label.get_theme_color("font_color")==Color("313b4b"),"Bright-background text remains legible")
	scene._toggle_background(); check(scene.phase_label.get_theme_color("font_color")==Color("edb4b1"),"Dark-background text restores")
	scene.queue_free(); a.queue_free(); b.queue_free(); await process_frame
	print("BODY_STATE_TESTS checks=%d failures=%d"%[checks,failures]); quit(0 if failures==0 else 1)
