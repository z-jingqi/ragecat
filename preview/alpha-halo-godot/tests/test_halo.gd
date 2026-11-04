extends SceneTree
const Halo=preload("../components/alpha_halo.gd")
const Profile=preload("../components/halo_profile.gd")
const Preview=preload("../preview.gd")
const XING=preload("../assets/xing_tian.png")
const HOU=preload("../assets/hou_yi.png")
var checks: int=0
var failures: int=0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks+=1
	if not value: failures+=1; push_error(message)
func run() -> void:
	var a=Halo.new(); root.add_child(a)
	check(a.set_frame(XING,Rect2(),Vector2(57,76)),"full texture accepted")
	check(a.source==XING and a.portrait.texture==XING,"source and portrait match")
	check(a.glow.size.x>a.display_size.x and a.glow.size.y>a.display_size.y,"geometry pads transparent boundary")
	var p=Profile.new(); p.width=8; a.configure(p)
	check(a.glow.position==Vector2(-37.5,-47) and a.glow.size==Vector2(75,94),"maximum width padded")
	p.width=2; check(a.profile.width==8,"configuration copied")
	for amount in [-3.0,0.0,0.3,1.0,5.0]:
		a.set_amount(amount); check(a.amount==clampf(amount,0,1),"amount clamped")
	a.seek(4.5); check(a.elapsed==4.5,"absolute time")
	a.advance(0.25); check(a.elapsed==4.75,"advance time")
	for value in [NAN,INF,-INF,-1.0]:
		a.seek(value); a.advance(value); check(a.elapsed==4.75,"invalid time ignored")
	a.set_amount(0.7)
	for value in [NAN,INF,-INF]:
		a.set_amount(value); check(a.amount==0.7,"invalid amount ignored")
	a.seek(1e300); a.advance(1e300); check(is_finite(a.elapsed),"huge clock finite")
	check(is_finite(float(a.shader_material.get_shader_parameter("strength"))),"shader strength finite for huge clock")
	a.clear(); a.configure(Profile.new()); a.set_frame(HOU,Rect2(),Vector2(57,76)); a.set_amount(1); a.seek(8); a.advance(1)
	check(not a.active and a.amount==0 and a.elapsed==0 and not a.glow.visible,"clear persists across config, frame, amount and time")
	a.start(1); check(a.active and a.amount==1 and a.glow.visible,"explicit restart")
	a.start(NAN); check(a.amount==0 and a.elapsed==0,"invalid restart amount becomes zero")
	a.set_flip(true,true); check(a.portrait.flip_h and a.portrait.flip_v,"portrait flip")
	check(a.shader_material.get_shader_parameter("flip_h") and a.shader_material.get_shader_parameter("flip_v"),"glow flip")
	for bad in [Rect2(-1,0,10,10),Rect2(0,0,1e6,10),Rect2(0,0,0,10),Rect2(NAN,0,10,10)]:
		check(not a.set_frame(XING,bad,Vector2(10,10)),"invalid region rejected")
	check(a.source==HOU,"rejected frame leaves source unchanged")
	check(not a.set_frame(null) and not a.set_frame(XING,Rect2(),Vector2(INF,1)),"invalid texture and size")
	check(a.set_frame(XING,Rect2(16,32,100,200),Vector2(38,76)),"sprite sheet region accepted")
	check(a.portrait.region_rect==Rect2(16,32,100,200),"sprite frame region")
	var atlas_frame=AtlasTexture.new(); atlas_frame.atlas=XING; atlas_frame.region=Rect2(16,32,100,200)
	check(a.set_frame(atlas_frame,Rect2(),Vector2(38,76)),"standard AtlasTexture frame accepted")
	check(a.source==XING and a.source_region==atlas_frame.region,"AtlasTexture resolved without baking")
	atlas_frame.margin=Rect2(1,1,2,2); check(not a.set_frame(atlas_frame),"virtual-margin atlas explicitly rejected")
	p=Profile.new(); p.width=NAN; p.intensity=INF; p.breathing=-1; p.breathing_speed=INF; p.color=Color(NAN,5,-1,0)
	a.configure(p); check(a.profile.width==2.8 and a.profile.intensity==0.58 and a.profile.breathing==0 and a.profile.breathing_speed==0.7,"profile sanitized")
	check(a.profile.color.a==1 and a.profile.color.g==1 and a.profile.color.b==0,"color sanitized")
	var b=Halo.new(); root.add_child(b); b.set_frame(XING); b.start(0.2); a.start(1)
	check(a.shader_material!=b.shader_material and b.amount==0.2,"instance state isolated")
	check(Preview.sample_amount(0)==0 and Preview.sample_amount(5)==1 and Preview.sample_amount(7)==1 and Preview.sample_amount(11)==0,"timeline endpoints")
	for i in range(1,41): check(Preview.sample_amount(1+i*0.1)>=Preview.sample_amount(1+(i-1)*0.1),"build monotonic")
	for i in range(1,41): check(Preview.sample_amount(7+i*0.1)<=Preview.sample_amount(7+(i-1)*0.1),"decay monotonic")
	for t in [NAN,INF,-INF]: check(Preview.sample_amount(t)==0,"invalid demo time")
	a.queue_free(); b.queue_free(); await process_frame
	print("HALO_HEADLESS ",checks," checks / ",failures," failures"); quit(0 if failures==0 else 1)
