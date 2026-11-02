extends Node2D
const Bolt = preload("res://effects/VFX-08_lightning/lightning.gd")
var fx: Node2D
var viewport: SubViewport
var data: Dictionary
var config := {}
var paused := false
var timer := 0.0
var elapsed := 0.0
var angle := 90.0
var length := 88.0
var rate := 1.0
var loops := true
var dark := true
var preset: OptionButton
var sliders := {}
var readouts := {}
var status: Label
var pause_button: Button
var capture_dir := ""
var frame := 0
var auto_demo := false
var stage := -1
func label_at(text: String,p: Vector2,size: int=11) -> Label:
	var n:=Label.new();n.text=text;n.position=p;n.add_theme_font_size_override("font_size",size);add_child(n);return n
func button_at(text: String,x: float,y: float,w: float,action: Callable) -> Button:
	var b:=Button.new();b.text=text;b.position=Vector2(x,y);b.size=Vector2(w,26);b.add_theme_font_size_override("font_size",11);b.pressed.connect(action);add_child(b);return b
func slider_at(key: String,y: float,low: float,high: float,step: float,value: float) -> void:
	readouts[key]=label_at("",Vector2(465,y))
	var s:=HSlider.new();s.position=Vector2(465,y+17);s.size=Vector2(152,14);s.min_value=low;s.max_value=high;s.step=step;s.value=value
	s.value_changed.connect(func(v:float):
		if key=="angle":angle=v
		elif key=="length":length=v
		else:config[key]=v
		trigger();refresh())
	add_child(s);sliders[key]=s
func _ready() -> void:
	data=JSON.parse_string(FileAccess.get_file_as_string("res://effects/VFX-08_lightning/presets.json"))
	auto_demo="--lightning-auto" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):capture_dir=arg.trim_prefix("--capture-dir=");DirAccess.make_dir_recursive_absolute(capture_dir)
	viewport=SubViewport.new();viewport.size=Vector2i(128,128);viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;viewport.disable_3d=true;add_child(viewport)
	fx=Bolt.new();fx.automatic=false;viewport.add_child(fx)
	for item in [{"p":Vector2(24,108),"s":1},{"p":Vector2(184,70),"s":2}]:
		var view:=TextureRect.new();view.position=item.p;view.size=Vector2(128,128)*item.s;view.texture=viewport.get_texture();view.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;add_child(view)
	label_at("08 / SINGLE LIGHTNING STRIKE",Vector2(20,12),18)
	label_at("Branched strike / ground flare / sparks / cooling smoke.",Vector2(20,40))
	label_at("ACTUAL / 1x",Vector2(24,84));label_at("2x NEAREST",Vector2(184,55))
	slider_at("angle",63,0,360,5,90)
	slider_at("length",105,20,100,1,88)
	slider_at("width",147,1,6,0.25,1.5)
	slider_at("jitter",189,0,20,1,10)
	slider_at("branches",231,0,4,1,3)
	preset=OptionButton.new();preset.position=Vector2(465,278);preset.size=Vector2(152,26);preset.add_theme_font_size_override("font_size",11)
	for p in data.presets:preset.add_item(p.label)
	preset.item_selected.connect(apply_preset);add_child(preset)
	pause_button=button_at("Pause",20,281,60,toggle_pause)
	button_at("+Frame",86,281,64,step_frame)
	button_at("Replay",20,313,60,trigger)
	button_at("Clear",86,313,64,func():fx.clear();loops=false)
	button_at("Seed +1",184,331,67,func():config.seed=int(config.seed)+1;trigger())
	button_at("Reset",257,331,54,reset_all)
	button_at("BG",317,331,42,func():dark=not dark;set_bg())
	button_at("Slow",365,331,60,func():rate=0.25 if rate==1 else 1)
	status=label_at("",Vector2(465,316),10)
	apply_preset(0);set_bg()
func set_bg() -> void:
	RenderingServer.set_default_clear_color(Color("20262b") if dark else Color("e5e6dd"))
	for child in get_children():
		if child is Label:child.add_theme_color_override("font_color",Color("d9e3e3") if dark else Color("283443"))
func refresh() -> void:
	for key in sliders:
		var v:float=angle if key=="angle" else (length if key=="length" else config[key])
		sliders[key].set_value_no_signal(v);readouts[key].text="%s: %s"%[key,str(snappedf(v,0.01))]
func apply_preset(i:int) -> void:
	config=data.defaults.duplicate(true);config.merge(data.presets[i].overrides,true);preset.select(i);refresh();trigger()
func trigger() -> void:
	var axis:=Vector2.from_angle(deg_to_rad(angle))
	fx.play(Vector2(64,64)-axis*length*0.5,Vector2(64,64)+axis*length*0.5,config);timer=0;loops=true
func reset_all() -> void:
	paused=false;pause_button.text="Pause";angle=90;length=88;rate=1;dark=true;set_bg();apply_preset(0)
func toggle_pause() -> void:
	paused=not paused;pause_button.text="Play" if paused else "Pause"
func step_frame() -> void:
	paused=true;pause_button.text="Play";advance(1.0/60)
func advance(dt:float) -> void:
	timer+=dt;fx.tick(dt)
	if loops and timer>=1.2:trigger()
func _process(delta:float) -> void:
	elapsed+=delta
	if auto_demo:
		var next:=mini(4,int(elapsed/2.4))
		if next!=stage:
			stage=next;apply_preset(0 if stage<2 else (1 if stage==2 else 2));angle=[90,25,170,115,90][stage];length=[88,96,90,84,88][stage];dark=stage!=4;set_bg();refresh();trigger()
	if not paused:advance(delta*rate)
	if status:status.text="%.0f ms / %s\nseed %d | %.2fx"%[fx.duration*1000,"PAUSED" if paused else ("STRIKE" if fx.active else "CLEAR"),int(config.seed),rate]
	if capture_dir!="":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(capture_dir.path_join("frame_%05d.png"%frame));frame+=1
	if auto_demo and elapsed>=12 and "--lightning-quit" in OS.get_cmdline_user_args():get_tree().quit()
