extends Node2D
const Warning = preload("res://effects/VFX-17_boss_warning/warning.gd")
var fx:Node2D
var host:Node2D
var vp:SubViewport
var area:Dictionary=Warning.DEFAULT_AREA.duplicate()
var style:Dictionary=Warning.DEFAULT_STYLE.duplicate()
var paused:=false
var moving:=false
var follow:=false
var dark:=true
var timer:=0.0
var elapsed:=0.0
var loop:=true
var count:=0
var status:Label
var selector:OptionButton
var shape_index:=0
var sliders:Dictionary={}
var titles:Dictionary={}
var frame:=0
var capture_dir:=""
var auto_demo:=false
var stage:=-1
func label_at(t:String,p:Vector2,size:int=11)->Label:
	var n:=Label.new();n.text=t;n.position=p;n.add_theme_font_size_override("font_size",size);add_child(n);return n
func button(t:String,p:Vector2,fn:Callable)->Button:
	var b:=Button.new();b.text=t;b.position=p;b.size=Vector2(65,25);b.add_theme_font_size_override("font_size",10);b.pressed.connect(fn);add_child(b);return b
func slider(key:String,y:float,lo:float,hi:float,step:float)->void:
	var title:=label_at(key+": "+str(area[key]),Vector2(464,y))
	var s:=HSlider.new();s.position=Vector2(464,y+17);s.size=Vector2(156,15);s.min_value=lo;s.max_value=hi;s.step=step;s.value=area[key];s.value_changed.connect(func(v):area[key]=v;title.text=key+": "+str(v);trigger());add_child(s);sliders[key]=s;titles[key]=title
func _ready()->void:
	auto_demo="--warning-auto" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):capture_dir=arg.trim_prefix("--capture-dir=");DirAccess.make_dir_recursive_absolute(capture_dir)
	vp=SubViewport.new();vp.size=Vector2i(128,128);vp.transparent_bg=true;vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;vp.disable_3d=true;add_child(vp)
	fx=Warning.new();fx.automatic=false;vp.add_child(fx)
	host=Node2D.new();host.position=Vector2(64,64);vp.add_child(host)
	fx.activated.connect(func(_snapshot):count+=1)
	for item in [{"p":Vector2(24,112),"s":1},{"p":Vector2(184,72),"s":2}]:
		var v:=TextureRect.new();v.position=item.p;v.size=Vector2(128,128)*item.s;v.texture=vp.get_texture();v.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;add_child(v)
	label_at("17 / BOSS WARNING",Vector2(20,12),18)
	label_at("Authoritative range / directional fill / one activation event",Vector2(20,40))
	label_at("ACTUAL / 1x",Vector2(24,88));label_at("2x NEAREST",Vector2(184,55))
	selector=OptionButton.new();selector.position=Vector2(464,58);selector.size=Vector2(156,25)
	for v in ["Circle","Ring","Sector","Rectangle"]:selector.add_item(v)
	selector.item_selected.connect(set_shape);add_child(selector)
	slider("radius",91,12,54,1);slider("countdown",134,0.2,3,0.1);slider("orientation_deg",177,-180,180,5);slider("angle_deg",220,15,180,5)
	button("Pause",Vector2(20,280),func():paused=not paused)
	button("+Frame",Vector2(90,280),func():paused=true;advance(1.0/60))
	button("Replay",Vector2(20,311),trigger)
	button("Cancel",Vector2(90,311),func():fx.cancel();loop=false)
	button("Reset",Vector2(184,331),reset_all)
	button("BG",Vector2(254,331),func():dark=not dark;set_bg())
	button("Move",Vector2(324,331),func():moving=not moving)
	button("Follow",Vector2(394,331),func():follow=not follow;trigger())
	status=label_at("",Vector2(464,274),11)
	trigger();set_bg()
func set_bg()->void:
	RenderingServer.set_default_clear_color(Color("20262b") if dark else Color("e5e6dd"))
	for n in get_children():
		if n is Label:n.add_theme_color_override("font_color",Color("d9e3e3") if dark else Color("283443"))
func set_shape(i:int)->void:
	shape_index=i;selector.select(i);area.shape=["circle","ring","sector","rectangle"][i];trigger()
func reset_all()->void:
	paused=false;moving=false;follow=false;dark=true;count=0;area=Warning.DEFAULT_AREA.duplicate();style=Warning.DEFAULT_STYLE.duplicate();set_shape(0);set_bg()
	for key in sliders:
		sliders[key].set_value_no_signal(area[key]);titles[key].text=key+": "+str(area[key])
func trigger()->void:
	timer=0;loop=true;fx.play(host.position,area,style,host,follow)
func advance(dt:float)->void:
	timer+=dt
	host.position=Vector2(64+sin(elapsed*2)*8,64).round() if moving else Vector2(64,64)
	fx.tick(dt)
	if loop and timer>=fx.duration+0.4:trigger()
func _process(dt:float)->void:
	elapsed+=dt
	if auto_demo:
		var next:=mini(3,int(elapsed/3.5))
		if next!=stage:
			stage=next;dark=stage!=3;area.orientation_deg=-25 if stage==2 else (25 if stage==3 else 0);set_shape(stage);set_bg()
			for key in sliders:
				sliders[key].set_value_no_signal(area[key]);titles[key].text=key+": "+str(area[key])
	if not paused:advance(dt)
	status.text="%s\n%.2f s remaining\nactivation #%d\n%s"%[("READY" if fx.fired else "WARNING") if fx.active else "CLEAR",maxf(area.countdown-fx.elapsed,0) if fx.active else 0.0,count,"FOLLOW" if follow else "LOCKED"]
	if capture_dir!="":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(capture_dir.path_join("frame_%05d.png"%frame));frame+=1
	if auto_demo and elapsed>=14 and "--warning-quit" in OS.get_cmdline_user_args():get_tree().quit()
