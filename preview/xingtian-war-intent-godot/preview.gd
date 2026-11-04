extends Node2D
const Effect = preload("components/battle_intent.gd")
const Profile = preload("components/intent_profile.gd")
const Fixture = preload("fixture.gd")
@export var configuration: Resource = preload("presets/default.tres")
var profile
var main_fx
var samples: Array = []
var elapsed: float = 0.0
var paused: bool = false
var cleared: bool = false
var automated: bool = true
var light_background: bool = false
var scale_label: Label
var phase: Label
var value_label: Label
var pause_button: Button
var momentum_slider: HSlider
var timeline: HSlider
var updating: bool = false
var capture: bool = false
var capture_frame: int = 0

func _ready() -> void:
	profile = (configuration if configuration is Profile else Profile.new()).sanitized()
	capture = "--capture" in OS.get_cmdline_user_args()
	text("RAGECAT  /  XING TIAN", Vector2(38,22), 14, "b3978c")
	text("BATTLE INTENT", Vector2(38,46), 31, "e7ccba")
	text("Low ground fractures gather, hold, then quietly recede.", Vector2(38,91), 15, "8f9ca9")
	scale_label = text("01  FULL SEQUENCE  ·  4× NATIVE PIXELS", Vector2(58,139), 13, "b5a396")
	phase = text("", Vector2(435,139), 14, "d7856e")
	main_fx = make_fx(Vector2(400,345), 4.0, true)
	text("Static figure is only a scale reference. Ground light never covers the body.",Vector2(58,419),12,"8e98a2")
	for i in range(3):
		var node = make_fx(Vector2(165+i*242,585), 2.0, true)
		samples.append(node)
		text(["02   LOW / 25%", "03   MID / 60%", "04   FULL / 100%"][i],Vector2(60+i*242,482),13,"a8998e")
	text("VISUAL INPUTS",Vector2(855,138),14,"e1ba9c")
	value_label = text("Host momentum  0%",Vector2(855,178),14,"b9c0c5")
	momentum_slider = slider(Vector2(855,210),0,1,0.01,0)
	momentum_slider.value_changed.connect(func(value: float):
		if updating: return
		automated = false
		main_fx.set_momentum(value)
		update_text())
	add_setting("Ground radius", "radius", 18, 50, 1, 250)
	add_setting("Ground perspective", "perspective", 0.25, 0.65, 0.01, 316)
	add_setting("Brightness", "opacity", 0.1, 1.0, 0.01, 382)
	for i in range(2):
		var key: String = ["ring", "cracks"][i]
		var check := CheckBox.new(); check.text=key.capitalize(); check.button_pressed=true; check.position=Vector2(850+i*150,451); add_child(check)
		check.toggled.connect(func(value:bool): main_fx.set_layer_enabled(key,value))
	pause_button = button("Pause",Vector2(855,507),func(): paused=not paused; pause_button.text="Resume" if paused else "Pause")
	button("Replay",Vector2(966,507),replay)
	button("Clear",Vector2(1077,507),clear_all)
	button("Background",Vector2(855,554),func(): light_background=not light_background; queue_redraw())
	text("Pure visual input only.\nNo attack, stack, damage or decay rules.\nTwo layers can be switched separately.",Vector2(855,607),13,"8996a2")
	timeline=slider(Vector2(38,662),0,8,1.0/60.0,0); timeline.size.x=750
	timeline.value_changed.connect(func(value:float):
		if updating: return
		paused=true; automated=true; pause_button.text="Resume"; elapsed=value; sample_sequence())
	text("0 → gathering → sustained intent → decay → empty",Vector2(38,694),12,"73808c")
	replay()

func make_fx(pos: Vector2, zoom: float, actor: bool):
	var holder:=Node2D.new(); holder.position=pos; holder.scale=Vector2.ONE*zoom; add_child(holder)
	var node=Effect.new(); holder.add_child(node); node.play(Vector2.ZERO,profile)
	if actor:
		var fixture=Fixture.new(); fixture.z_index=10; holder.add_child(fixture)
	return node

func text(value:String,pos:Vector2,size:int,color:String) -> Label:
	var label:=Label.new(); label.text=value; label.position=pos; label.add_theme_font_size_override("font_size",size); label.add_theme_color_override("font_color",Color(color)); add_child(label); return label

func slider(pos:Vector2,low:float,high:float,step:float,value:float) -> HSlider:
	var s:=HSlider.new(); s.position=pos; s.size=Vector2(320,20); s.min_value=low; s.max_value=high; s.step=step; s.value=value; add_child(s); return s

func button(value:String,pos:Vector2,action:Callable) -> Button:
	var b:=Button.new(); b.text=value; b.position=pos; b.size=Vector2(102,34); b.pressed.connect(action); add_child(b); return b

func add_setting(title:String,key:String,low:float,high:float,step:float,y:float) -> void:
	var label=text("%s  %s"%[title,str(profile.get(key))],Vector2(855,y),14,"b9c0c5")
	var s=slider(Vector2(855,y+28),low,high,step,profile.get(key))
	s.value_changed.connect(func(value:float):
		profile.set(key,value); label.text="%s  %s"%[title,str(value)]
		if cleared: return
		var level:float=main_fx.momentum
		main_fx.play(Vector2.ZERO,profile); main_fx.set_momentum(level); main_fx.seek(elapsed)
		for node in samples: node.play(Vector2.ZERO,profile)
		fit_views(); update_samples())

func replay() -> void:
	cleared=false; elapsed=0.0; paused=false; automated=true; pause_button.text="Pause"
	main_fx.play(Vector2.ZERO,profile)
	for node in samples: node.play(Vector2.ZERO,profile)
	fit_views(); sample_sequence()

static func level_at(t:float) -> float:
	if t < 0.6: return 0.0
	if t < 3.6: return smoothstep(0.6,3.6,t)
	if t < 5.0: return 1.0
	return 1.0-smoothstep(5.0,7.4,t)

func sample_sequence() -> void:
	if cleared: return
	main_fx.seek(elapsed); main_fx.set_momentum(level_at(elapsed))
	update_samples(); update_text()

func update_samples() -> void:
	for i in range(samples.size()): samples[i].seek(elapsed); samples[i].set_momentum([0.25,0.6,1.0][i])

func update_text() -> void:
	value_label.text="Host momentum  %d%%"%roundi(main_fx.momentum*100)
	phase.text="EMPTY" if elapsed<0.6 or elapsed>=7.4 else ("GATHERING" if elapsed<3.6 else ("HELD" if elapsed<5.0 else "DECAYING"))
	if not automated: phase.text="MANUAL INPUT"
	updating=true; momentum_slider.value=main_fx.momentum; timeline.value=elapsed; updating=false

func _process(delta:float) -> void:
	if capture:
		elapsed=float(capture_frame)/60.0; sample_sequence()
		if capture_frame in [0, 60, 120, 180, 216, 270, 330, 400, 470]: await snapshot(capture_frame)
		capture_frame+=1
		if capture_frame>480: get_tree().quit()
	elif not paused and not cleared:
		elapsed+=delta
		if automated:
			if elapsed>8.8: elapsed=0.0
			sample_sequence()
		else: main_fx.seek(elapsed); update_samples()

func _draw() -> void:
	draw_rect(Rect2(0,0,1280,720),Color("10151c"))
	var bg:=Color("495157") if light_background else Color("21272e")
	for rect in [Rect2(38,122,750,327),Rect2(38,465,750,178),Rect2(826,122,414,569)]:
		draw_rect(rect,bg if rect.position.x<800 else Color("171e26")); draw_rect(rect,Color("35404b"),false,1)
	for y in range(180,407,18):
		for x in range(57,775,18):
			if posmod(x*7+y*3,11)<4: draw_rect(Rect2(x,y,3,1),Color("333941") if not light_background else Color("555e63"))

func snapshot(frame:int) -> void:
	var out:=OS.get_environment("XINGTIAN_CAPTURE_DIR")
	if out.is_empty(): return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(out)
	var img:=get_viewport().get_texture().get_image()
	if img!=null: img.save_png(out.path_join("war-intent-%04d.png"%frame))

func clear_all() -> void:
	cleared=true; paused=true; pause_button.text="Resume"
	main_fx.clear()
	for fx in samples: fx.clear()
	phase.text="CLEARED"

func fit_views() -> void:
	var zoom:float=4.0 if profile.radius<=36.0 and profile.perspective<=0.5 else 2.0
	main_fx.get_parent().scale=Vector2.ONE*zoom
	scale_label.text="01  FULL SEQUENCE  ·  %d× NATIVE PIXELS"%int(zoom)
	for fx in samples: fx.get_parent().scale=Vector2.ONE*(2.0 if zoom==4.0 else 1.0)
