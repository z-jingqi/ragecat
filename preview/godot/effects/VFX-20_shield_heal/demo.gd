extends Node2D
const Aura = preload("res://effects/VFX-20_shield_heal/support.gd")
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
var color_pickers := {}
var detail_view:TextureRect
var detail_label:Label
var status: Label
var pause_button: Button
var capture_dir := ""
var frame := 0
var host:Node2D
var moving:=false
var did_hit=false
var did_break=false
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
	data=JSON.parse_string(FileAccess.get_file_as_string("res://effects/VFX-20_shield_heal/presets.json"))
	auto_demo="--aura-auto" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):capture_dir=arg.trim_prefix("--capture-dir=");DirAccess.make_dir_recursive_absolute(capture_dir)
	viewport=SubViewport.new();viewport.size=Vector2i(128,128);viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;viewport.disable_3d=true;add_child(viewport)
	fx=Aura.new();fx.automatic=false;viewport.add_child(fx)
	host=Node2D.new();host.position=Vector2(64,102);host.z_index=1;viewport.add_child(host)
	var image:=Image.create(24,36,false,Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for y in range(4,31):
		for x in range(5,19):
			if y<12 and (x<7 or x>16):continue
			if y>26 and x>10 and x<14:continue
			var c:=Color("84939c") if y<12 else Color("536879")
			if x<8:c=Color("a8b5b9")
			if y==10:c=Color("28353f")
			image.set_pixel(x,y,c)
	var sprite:=Sprite2D.new();sprite.texture=ImageTexture.create_from_image(image);sprite.position=Vector2(0,-15);host.add_child(sprite)
	for item in [{"p":Vector2(24,108),"s":1},{"p":Vector2(184,70),"s":2}]:
		var view:=TextureRect.new();view.position=item.p;view.size=Vector2(128,128)*item.s;view.texture=viewport.get_texture();view.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;add_child(view)
		if item.s==2:detail_view=view
	label_at("20 / SHIELD + HEAL",Vector2(20,12),18)
	label_at("Shield form / hit / break. Independent rising healing motes.",Vector2(20,40))
	label_at("ACTUAL / 1x",Vector2(24,84));detail_label=label_at("2x NEAREST",Vector2(184,55))
	slider_at("radius",63,8,34,1,23)
	slider_at("height",105,12,38,1,29)
	slider_at("sustain",147,.1,8,.1,2.4)
	slider_at("particles",189,0,32,1,14)
	slider_at("intensity",231,0,1,.05,.6)
	preset=OptionButton.new();preset.position=Vector2(465,278);preset.size=Vector2(152,26);preset.add_theme_font_size_override("font_size",11)
	for p in data.presets:preset.add_item(p.label)
	preset.item_selected.connect(apply_preset);add_child(preset)
	for index in range(4):
		var key=["body","core","edge","plus"][index]
		var picker=ColorPickerButton.new();picker.position=Vector2(20+index*34,249);picker.size=Vector2(30,24);picker.edit_alpha=false;picker.tooltip_text=key+" color"
		picker.color_changed.connect(func(c:Color):set_palette_color(key,c))
		color_pickers[key]=picker;add_child(picker)
		var panel=picker.get_picker();panel.sliders_visible=false;panel.color_modes_visible=false;panel.presets_visible=false;panel.sampler_visible=false
	pause_button=button_at("Pause",20,281,60,toggle_pause)
	button_at("+Frame",86,281,64,step_frame)
	button_at("Replay",20,313,60,trigger)
	button_at("Stop",86,313,64,func():fx.stop();loops=false)
	button_at("Seed +1",184,331,67,func():config.seed=int(config.seed)+1;trigger())
	button_at("Reset",257,331,54,reset_all)
	button_at("BG",317,331,42,func():dark=not dark;set_bg())
	button_at("Move",365,331,60,func():moving=not moving)
	button_at("Hit",184,301,60,func():fx.hit(Vector2(1,-.4)))
	button_at("Break",250,301,60,func():fx.break_shield();loops=false)
	status=label_at("",Vector2(465,316),10)
	apply_preset(0);set_bg()
func set_bg() -> void:
	RenderingServer.set_default_clear_color(Color("20262b") if dark else Color("e5e6dd"))
	for child in get_children():
		if child is Label:child.add_theme_color_override("font_color",Color("d9e3e3") if dark else Color("283443"))
func set_palette_color(key:String,c:Color)->void:
	config[key]=c.to_html(false);trigger();refresh()
func refresh() -> void:
	for key in color_pickers:color_pickers[key].color=Color(config[key])
	for key in sliders:
		var v:float=angle if key=="angle" else (length if key=="length" else config[key])
		sliders[key].set_value_no_signal(v);readouts[key].text="%s: %s"%[key,str(snappedf(v,0.01))]
func apply_preset(i:int) -> void:
	config=Aura.DEFAULTS.duplicate(true);config.merge(data.presets[i].overrides,true);preset.select(i)
	if config.mode=="heal":
		var atlas=AtlasTexture.new();atlas.atlas=viewport.get_texture();atlas.region=Rect2(32,40,64,64);detail_view.texture=atlas;detail_label.text="PLUS DETAIL / 4x NEAREST"
	else:detail_view.texture=viewport.get_texture();detail_label.text="2x NEAREST"
	refresh();trigger()
func trigger() -> void:
	fx.play(host.position,config,host);timer=0;loops=true;did_hit=false;did_break=false
func reset_all() -> void:
	paused=false;moving=false;pause_button.text="Pause";angle=90;length=88;rate=1;dark=true;set_bg();apply_preset(0)
func toggle_pause() -> void:
	paused=not paused;pause_button.text="Play" if paused else "Pause"
func step_frame() -> void:
	paused=true;pause_button.text="Play";advance(1.0/60)
func advance(dt:float) -> void:
	timer+=dt
	if moving:host.position=Vector2(64+sin(timer*2)*16,102+sin(timer*1.4)*3).round()
	else:host.position=Vector2(64,102)
	fx.tick(dt)
	if config.mode=="shield" and timer>.75 and not did_hit:fx.hit(Vector2(1,-.4));did_hit=true
	if auto_demo and stage==1 and timer>1.6 and not did_break:fx.break_shield();did_break=true;loops=false
	if loops and timer>=fx.duration+0.45:trigger()
func _process(delta:float) -> void:
	elapsed+=delta
	if auto_demo:
		var next:=mini(3,int(elapsed/4.0))
		if next!=stage:
			stage=next;apply_preset(stage);moving=stage==2;dark=stage!=3;set_bg();refresh();trigger()
	if not paused:advance(delta*rate)
	if status:status.text="%.0f ms / %s\nseed %d | %.2fx"%[fx.duration*1000,"PAUSED" if paused else (str(config.mode).to_upper() if fx.active else "CLEAR"),int(config.seed),rate]
	if capture_dir!="":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(capture_dir.path_join("frame_%05d.png"%frame));frame+=1
	if auto_demo and elapsed>=16 and "--aura-quit" in OS.get_cmdline_user_args():get_tree().quit()
