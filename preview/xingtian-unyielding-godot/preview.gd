extends Node2D
const Effect=preload("components/unyielding.gd")
const Profile=preload("components/unyielding_profile.gd")
const Fixture=preload("fixture.gd")
@export var configuration:Resource=preload("presets/default.tres")
const OUTCOME_TIME:float=2.8
var profile
var success_fx
var failure_fx
var samples:Array=[]
var elapsed:float=0.0
var paused:bool=false
var cleared:bool=false
var automatic_outcome:bool=true
var light_background:bool=false
var capture:bool=false
var capture_frame:int=0
var pause_button:Button
var scale_label:Label
var phase:Label
var timeline:HSlider
var updating:bool=false
var toggles:Dictionary={}

func _ready() -> void:
	profile=(configuration if configuration is Profile else Profile.new()).sanitized()
	capture="--capture" in OS.get_cmdline_user_args()
	text("RAGECAT  /  XING TIAN",Vector2(38,22),14,"b3978c")
	text("UNYIELDING",Vector2(38,46),31,"e7ccba")
	text("Contract → endure. Copper rises only on confirmed revival.",Vector2(38,91),15,"8f9ca9")
	text("01  CONFIRMED REVIVAL",Vector2(58,141),13,"c6a78d")
	text("02  EXHAUSTION",Vector2(442,141),13,"b8958e")
	success_fx=make_fx(Vector2(235,351),3.0)
	failure_fx=make_fx(Vector2(615,351),3.0)
	text("Copper gathers upward, then clears.",Vector2(58,414),12,"8f9ca9")
	text("Red fades. No revival cue.",Vector2(442,414),12,"8f9ca9")
	var sample_times:Array=[0.2,1.4,3.25,3.25]
	for i in range(4):
		var fx=make_fx(Vector2(135+i*187,587),2.0); samples.append(fx)
		text(["ENTRY", "HOLD", "REVIVAL", "FADE"][i],Vector2(70+i*187,479),12,"b4a08d")
		if i>=2: fx.seek(OUTCOME_TIME); fx.revive() if i==2 else fx.exhaust()
		fx.seek(sample_times[i])
	scale_label=text("3× live branches above  /  isolated phase samples below",Vector2(58,626),12,"73828e")
	text("VISUAL PARAMETERS",Vector2(855,140),14,"e1ba9c")
	add_setting("Ground radius","radius",18,44,1,180)
	add_setting("Aura opacity","aura_opacity",0,0.65,0.01,246)
	add_setting("Entry shards","shard_count",0,24,1,312)
	add_setting("Revival streaks","rising_count",0,18,1,378)
	for i in range(3):
		var key:String=["blood","aura","ring"][i]
		var check:=CheckBox.new(); check.text=key.capitalize(); check.position=Vector2(850+i*120,444); check.button_pressed=true; add_child(check); toggles[key]=check
		check.toggled.connect(func(value:bool):
			for fx in all_fx(): fx.set_layer_enabled(key,value))
	pause_button=button("Pause",Vector2(855,491),func(): paused=not paused; pause_button.text="Resume" if paused else "Pause")
	button("Replay",Vector2(966,491),replay)
	button("Clear",Vector2(1077,491),clear_all)
	button("Hold",Vector2(855,537),func(): automatic_outcome=false; replay(false))
	button("Resolve",Vector2(966,537),func(): success_fx.revive(); failure_fx.exhaust())
	button("BG",Vector2(1077,537),func(): light_background=not light_background; queue_redraw())
	phase=text("",Vector2(855,592),13,"d59a7c")
	text("Hold waits for an explicit host outcome.\nResolve previews success left, failure right.\nBlood is optional and entry-only.",Vector2(855,628),12,"8996a2")
	timeline=HSlider.new(); timeline.position=Vector2(38,662); timeline.size=Vector2(750,20); timeline.min_value=0; timeline.max_value=5.3; timeline.step=1.0/60.0; add_child(timeline)
	timeline.value_changed.connect(func(value:float):
		if updating:return
		paused=true; pause_button.text="Resume"; automatic_outcome=true; sample_at(value))
	text("This is a visual preview. It does not decide death, healing, revival or resource exhaustion.",Vector2(38,694),12,"73808c")
	replay()

func all_fx() -> Array:
	return [success_fx,failure_fx]+samples

func make_fx(pos:Vector2,zoom:float):
	var holder:=Node2D.new(); holder.position=pos; holder.scale=Vector2.ONE*zoom; add_child(holder)
	var fx=Effect.new(); holder.add_child(fx); fx.enter(Vector2.ZERO,profile)
	var fixture=Fixture.new(); fixture.z_index=10; holder.add_child(fixture)
	return fx

func text(value:String,pos:Vector2,size:int,color:String) -> Label:
	var l:=Label.new(); l.text=value; l.position=pos; l.add_theme_font_size_override("font_size",size); l.add_theme_color_override("font_color",Color(color)); add_child(l); return l

func button(value:String,pos:Vector2,action:Callable) -> Button:
	var b:=Button.new(); b.text=value; b.position=pos; b.size=Vector2(102,34); b.pressed.connect(action); add_child(b); return b

func add_setting(title:String,key:String,low:float,high:float,step:float,y:float) -> void:
	var l=text("%s  %s"%[title,str(profile.get(key))],Vector2(855,y),14,"b9c0c5")
	var s:=HSlider.new(); s.position=Vector2(855,y+28); s.size=Vector2(320,20); s.min_value=low; s.max_value=high; s.step=step; s.value=profile.get(key); add_child(s)
	s.value_changed.connect(func(value:float): profile.set(key,value); l.text="%s  %s"%[title,str(value)]; rebuild())

func replay(reset_mode:bool=true) -> void:
	if reset_mode: automatic_outcome=true
	cleared=false; paused=false; pause_button.text="Pause"; elapsed=0.0; rebuild()

func rebuild() -> void:
	if cleared: return
	for fx in all_fx():
		fx.enter(Vector2.ZERO,profile)
		for key in toggles: fx.set_layer_enabled(key,toggles[key].button_pressed)
	for i in range(samples.size()):
		if i>=2: samples[i].seek(OUTCOME_TIME); samples[i].revive() if i==2 else samples[i].exhaust()
		samples[i].seek([0.2,1.4,3.25,3.25][i])
	fit_views(); sample_at(elapsed)

func sample_at(seconds:float) -> void:
	if cleared: return
	elapsed=seconds
	for fx in [success_fx,failure_fx]: fx.enter(Vector2.ZERO,profile)
	if automatic_outcome and elapsed>=OUTCOME_TIME:
		success_fx.seek(OUTCOME_TIME); failure_fx.seek(OUTCOME_TIME); success_fx.revive(); failure_fx.exhaust()
	success_fx.seek(elapsed); failure_fx.seek(elapsed); update_text()

func update_text() -> void:
	phase.text="%.2f s  ·  %s / %s"%[elapsed,success_fx.get_phase(),failure_fx.get_phase()]
	updating=true; timeline.value=minf(elapsed,5.3); updating=false

func _process(delta:float) -> void:
	if capture:
		sample_at(float(capture_frame)/60.0)
		if capture_frame in [0, 7, 14, 24, 39, 84, 168, 183, 195, 210, 231, 258]: await snapshot(capture_frame)
		capture_frame+=1
		if capture_frame>390: get_tree().quit()
	elif not paused and not cleared:
		elapsed+=delta
		if automatic_outcome:
			if elapsed>6.0: elapsed=0.0
			sample_at(elapsed)
		else:
			success_fx.advance(delta); failure_fx.advance(delta); update_text()

func _draw() -> void:
	draw_rect(Rect2(0,0,1280,720),Color("10151c"))
	var bg:=Color("495157") if light_background else Color("21272e")
	for rect in [Rect2(38,122,366,327),Rect2(422,122,366,327),Rect2(38,465,750,178),Rect2(826,122,414,569)]:
		draw_rect(rect,bg if rect.position.x<800 else Color("171e26")); draw_rect(rect,Color("35404b"),false,1)
	for y in range(200,407,18):
		for x in range(57,775,18):
			if x>404 and x<422:continue
			if posmod(x*7+y*3,11)<4: draw_rect(Rect2(x,y,3,1),Color("333941") if not light_background else Color("555e63"))

func snapshot(frame:int) -> void:
	var out:=OS.get_environment("XINGTIAN_CAPTURE_DIR")
	if out.is_empty(): return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(out)
	var img:=get_viewport().get_texture().get_image()
	if img!=null: img.save_png(out.path_join("unyielding-%04d.png"%frame))

func clear_all() -> void:
	cleared=true; paused=true; pause_button.text="Resume"
	for fx in all_fx(): fx.clear()
	phase.text="CLEARED"

func fit_views() -> void:
	var zoom:float=3.0 if profile.radius<=36.0 and profile.perspective<=0.5 else 2.0
	for fx in [success_fx,failure_fx]: fx.get_parent().scale=Vector2.ONE*zoom
	for fx in samples: fx.get_parent().scale=Vector2.ONE*(2.0 if zoom==3.0 else 1.0)
	scale_label.text="%d× live branches above  /  isolated phase samples below"%int(zoom)
