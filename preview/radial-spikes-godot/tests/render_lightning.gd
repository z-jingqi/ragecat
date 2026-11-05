extends SceneTree
const Canvas=preload("../components/spike_canvas.gd")
const Lightning=preload("../modules/lightning.gd")
const Preset=preload("../presets/lightning.tres")
var failures:int=0
var checks:int=0
var vp:SubViewport
var probe:Node2D
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func _initialize()->void: call_deferred("run")
func render(stamp:float)->Image:
	probe.age=stamp; probe.queue_redraw(); await process_frame; await process_frame; await RenderingServer.frame_post_draw
	return vp.get_texture().get_image()
func run()->void:
	if DisplayServer.get_name()=="headless": push_error("Native renderer required"); quit(2); return
	vp=SubViewport.new(); vp.size=Vector2i(80,80); vp.transparent_bg=true; vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(vp)
	probe=Canvas.new(); probe.position=Vector2(40,60); probe.spike={"pos":Vector2.ZERO,"height":28,"width":12,"lean":.12,"variant":.6,"seed":193,"layer":1,"strength":.9,"direction":Vector2.RIGHT}; probe.renderer=Lightning; probe.profile=Preset.duplicate(true); vp.add_child(probe)
	var dark:int=0; var lit:int=0; var changes:int=0; var previous:PackedByteArray=[]
	# Sample the shorter revised pulse envelope at 120Hz, not its expired tail.
	for i in range(1,49):
		var im:Image=await render(float(i)/240)
		if im.get_used_rect().has_area(): lit+=1
		else: dark+=1
		if i>1 and im.get_data()!=previous: changes+=1
		previous=im.get_data()
	check(dark>5 and lit>10,"each site has real dark gaps and short independent discharges")
	check(changes>18,"path and brightness evolve across the event")
	var at:float=.08; var complete:Image=await render(at); await render(.41); check(complete.get_data()==(await render(at)).get_data(),"path seek is exact")
	var spark_frames:int=0
	for i in range(1,25):
		probe.profile.debris_density=1; var with_sparks:Image=await render(float(i)/120)
		probe.profile.debris_density=0
		if with_sparks.get_data()!=(await render(float(i)/120)).get_data(): spark_frames+=1
	check(spark_frames>4,"spark density zero removes sparse events across the time window")
	var ground_frames:int=0
	for i in range(1,25):
		probe.profile.ground_opacity=1; var with_ground:Image=await render(float(i)/240)
		probe.profile.ground_opacity=0
		if with_ground.get_data()!=(await render(float(i)/240)).get_data(): ground_frames+=1
	check(ground_frames>4,"ground opacity zero removes short landing flash/crawlers across arrival window")
	probe.profile.ground_opacity=1
	probe.profile.lightning_direction_mode=0; var outward:Image=await render(.025)
	probe.profile.lightning_direction_mode=1; var inward:Image=await render(.025)
	probe.profile.lightning_direction_mode=2; var vertical:Image=await render(.025)
	check(outward.get_data()!=inward.get_data() and outward.get_data()!=vertical.get_data(),"three electrical directions visibly differ")
	probe.spike.strength=.4; var minor:Image=await render(.025)
	check(minor.get_used_rect().get_area()<vertical.get_used_rect().get_area(),"secondary site remains subordinate to main channel")
	probe.spike.strength=.9
	probe.profile.primary=Color(0,0,0,0); probe.profile.highlight=Color(0,0,0,0); probe.profile.shadow=Color(0,0,0,0)
	check(not (await render(at)).get_used_rect().has_area(),"three palette alphas respected")
	print("Native lightning: dark=",dark," lit=",lit," changed=",changes)
	print("PASS" if failures==0 else "FAIL"," lightning lifecycle: ",checks," assertions, ",failures," failures")
	quit(0 if failures==0 else 1)
