extends SceneTree
const Profile=preload("../components/slash_profile.gd")
const Heavy=preload("../components/heavy_profile.gd")
const Pressure=preload("../components/heavy_pressure.gd")
const Stage=preload("../heavy_stage.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func _initialize()->void: call_deferred("run")
func run()->void:
	var p=Heavy.new()
	check(p is Profile and p.thickness>Profile.new().thickness,"Heavy is compatible with the approved blade and visibly weighted")
	check(p.pressure_radius==72 and p.pressure_duration==.32 and p.pressure_strength==.85 and p.pressure_color==Color("e9a463"),"Documented editable defaults")
	p.pressure_radius=INF; p.pressure_duration=-2; p.pressure_strength=NAN; p.pressure_squash=9; p.pressure_thickness=99; p.debris_count=99; p.pressure_color=Color(NAN,2,-1)
	var safe=p.sanitized()
	check(safe.pressure_radius==72 and safe.pressure_duration==.12 and safe.pressure_strength==.85,"Radius duration strength sanitized")
	check(safe.pressure_squash==.7 and safe.pressure_thickness==6 and safe.debris_count==16,"Ground shape and count bounded")
	check(safe.pressure_color==Color("e9a463") and is_inf(p.pressure_radius),"Color sanitized without mutating caller")
	p=Heavy.new(); var wave=Pressure.new(); root.add_child(wave); wave.play(Vector2(40,50),p)
	check(wave.samples().is_empty(),"Wave starts empty")
	wave.seek(.035); var early=wave.samples(); var early_r=wave.wave_radius()
	check(early.size()>30 and wave.position==Vector2(40,50),"Explicit wave has visible original geometry")
	wave.seek(.16); check(wave.wave_radius()>early_r,"Pressure propagates outward")
	wave.seek(.035); check(wave.samples()==early,"Analytic seek reproduces geometry")
	wave.play(Vector2.ZERO,p); wave.advance(.01); wave.advance(.025); check(wave.samples()==early,"Timestep split does not change the wave")
	wave.seek(p.pressure_duration); check(wave.samples().is_empty() and not wave.is_running(),"Exact configured end is empty")
	wave.seek(.035); check(wave.samples()==early,"Natural end remains seekable")
	wave.clear(); wave.seek(.035); check(wave.samples().is_empty(),"Explicit clear cannot resurrect")
	wave.set_enabled(false); wave.play(Vector2.ZERO,p); wave.seek(.035); check(wave.samples().is_empty(),"Disable survives new play")
	wave.set_enabled(true); check(wave.samples()==early,"Reenable uses same clock")
	wave.play(Vector2(INF,0),p); check(not wave.started,"Invalid origin clears")
	wave.play(Vector2.ZERO,Resource.new()); wave.seek(.035); check(wave.samples()==early,"Wrong profile falls back to heavy defaults")
	var t=wave.elapsed; wave.advance(-1); wave.seek(NAN); wave.advance(INF); check(wave.elapsed==t,"Invalid time is ignored")
	for key in ["pressure_strength","intensity"]:
		var muted=p.duplicate(); muted.set(key,0); wave.play(Vector2.ZERO,muted); wave.seek(.035); check(wave.samples().is_empty(),"Zero "+key+" suppresses ring and grit")
	var muted=p.duplicate(); muted.pressure_enabled=false; wave.play(Vector2.ZERO,muted); wave.seek(.035); check(wave.samples().is_empty(),"Wave profile toggle suppresses all layers")
	var large=p.duplicate(); large.pressure_radius=112; wave.play(Vector2.ZERO,large); wave.seek(.035)
	check(wave.wave_radius()>early_r and wave.debris.size()==8 and wave.profile.blood_count==9,"Radius changes range without increasing grit or blood")
	var long=p.duplicate(); long.pressure_duration=.6; wave.play(Vector2.ZERO,long); wave.seek(.32); check(not wave.samples().is_empty(),"Duration is independent and actually changes visible ending")
	var tint=p.duplicate(); tint.pressure_color=Color("50bdde"); wave.play(Vector2.ZERO,tint); wave.seek(.035); check(wave.samples()[0].color!=early[0].color,"Color changes actual samples")
	var thick=p.duplicate(); thick.pressure_thickness=6; wave.play(Vector2.ZERO,thick); wave.seek(.035); check(wave.samples().size()>early.size(),"Thickness changes band geometry")
	var flat=p.duplicate(); flat.pressure_squash=.2; wave.play(Vector2.ZERO,flat); wave.seek(.035); check(wave.samples()!=early,"Squash changes geometry")
	p.debris_count=0; wave.play(Vector2.ZERO,p); check(wave.debris.is_empty(),"Grit independently disabled")
	wave.free()
	p=Heavy.new(); var stage=Stage.new(); root.add_child(stage); stage.configure(p,2); stage.seek(.62)
	var hit_count:=0; var wave_halves:=0; var ids:={}
	for event in stage.events:
		if event.time<.62 and event.type=="hit": hit_count+=1; ids[event.node.get_instance_id()]=true
		if event.time<.62 and event.type=="pressure": wave_halves+=1
	check(hit_count==6 and ids.size()==6 and wave_halves==2,"Six contacts share one wave split into two depth halves")
	for event in stage.events:
		if event.type=="pressure": check(event.node.profile is Heavy,"Pressure keeps the extended profile")
	stage.set_wave(false); stage.set_blood(false); stage.set_facing(true)
	for event in stage.events:
		if event.time>.62: continue
		if event.type=="pressure": check(event.node.samples().is_empty(),"Mirror retains wave-off")
		if event.type=="hit": check(not event.node.blood.visible,"Mirror retains blood-off")
	stage.clear(); stage.set_facing(false); stage.seek(.62); check(stage.cleared,"Clear survives mirror and scrub")
	stage.restart(); stage.seek(.62); check(not stage.cleared,"Explicit replay resumes stage")
	stage.configure(p,0); check(stage.events.filter(func(e):return e.type=="pressure").is_empty(),"Normal comparison has no heavy pressure")
	stage.free()
	var scene=load("res://heavy_preview.tscn").instantiate(); root.add_child(scene); await process_frame; scene.set_process(false)
	scene.select_scenario(2); scene.seek_all(.62)
	for key in ["pressure_radius","pressure_duration","pressure_strength","pressure_thickness","pressure_squash","debris_count"]:
		scene.sliders[key].value=scene.sliders[key].max_value
		check(scene.stage.profile.get(key)==scene.profile.get(key) and scene.detail.profile.get(key)==scene.profile.get(key),"UI changes both stages: "+key)
	scene.color_button.color_changed.emit(Color("50bdde")); check(scene.stage.profile.pressure_color==Color("50bdde"),"Color picker signal is wired to runtime")
	scene.clear_all(); scene.sliders.pressure_radius.value=32; scene.color_button.color_changed.emit(Color("e0a060")); scene.paused=false; scene._process(5)
	check(scene.stage.cleared and scene.detail.cleared,"Clear survives sliders color and Resume at loop boundary")
	scene.replay(); scene.seek_all(.62); check(not scene.stage.cleared,"Replay uses edited settings")
	scene.reset_settings(); check(scene.profile.pressure_radius==72 and scene.profile.pressure_color==Color("e9a463"),"Reset restores documented defaults")
	scene.free(); print("XINGTIAN_HEAVY: %d checks, %d failures"%[checks,failures]); quit(1 if failures else 0)
