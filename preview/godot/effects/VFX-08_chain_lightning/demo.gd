extends Node2D
const Chain=preload("res://effects/VFX-08_chain_lightning/chain.gd")
const Enemy=preload("res://effects/VFX-08_chain_lightning/enemy.gd")
var fx:Node2D
var viewport:SubViewport
var enemies:Array=[]
var config:=Chain.DEFAULTS.duplicate(true)
var paused:=false
var moving:=false
var loops:=true
var dark:=true
var timer:=0.0
var elapsed:=0.0
var motion:=0.0
var hit_count:=0
var frame:=0
var capture_dir:=""
var auto_demo:=false
var stage:=-1
var status:Label
var pause_button:Button
var sliders:Dictionary={}
var labels:Dictionary={}
func label(text:String,p:Vector2,size:int=11)->Label:
	var n:=Label.new();n.text=text;n.position=p;n.add_theme_font_size_override("font_size",size);add_child(n);return n
func button(text:String,x:float,y:float,w:float,callback:Callable)->Button:
	var n:=Button.new();n.text=text;n.position=Vector2(x,y);n.size=Vector2(w,25);n.add_theme_font_size_override("font_size",11);n.pressed.connect(callback);add_child(n);return n
func slider(key:String,x:float,lo:float,hi:float,step:float)->void:
	labels[key]=label(key,Vector2(x,285),10)
	var s:=HSlider.new();s.position=Vector2(x,307);s.size=Vector2(130,14);s.min_value=lo;s.max_value=hi;s.step=step;s.value=config[key];s.value_changed.connect(func(v):config[key]=v;refresh();trigger());add_child(s);sliders[key]=s
func _ready()->void:
	auto_demo="--chain-auto" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):capture_dir=arg.trim_prefix("--capture-dir=");DirAccess.make_dir_recursive_absolute(capture_dir)
	viewport=SubViewport.new();viewport.size=Vector2i(190,96);viewport.transparent_bg=true;viewport.disable_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(viewport)
	for p in [Vector2(43,61),Vector2(76,29),Vector2(100,70),Vector2(132,35),Vector2(164,63),Vector2(176,15)]:
		var e:=Enemy.new();e.position=p;e.base=p;viewport.add_child(e);enemies.append(e)
	fx=Chain.new();fx.automatic=false;viewport.add_child(fx);fx.target_hit.connect(func(target,index):hit_count+=1;target.flash=0.13;target.order=index;target.queue_redraw())
	for item in [{"p":Vector2(15,123),"s":1},{"p":Vector2(240,74),"s":2}]:
		var t:=TextureRect.new();t.texture=viewport.get_texture();t.position=item.p;t.size=Vector2(190,96)*item.s;t.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;add_child(t)
	label("08 / CHAIN LIGHTNING",Vector2(18,10),18);label("Nearest unvisited target / moving anchors / one hit per jump",Vector2(18,38))
	label("ACTUAL / 1x",Vector2(15,101));label("2x NEAREST",Vector2(240,52))
	pause_button=button("Pause",15,238,55,func():paused=not paused;pause_button.text="Play" if paused else "Pause")
	button("Replay",76,238,58,trigger);button("Reset",140,238,55,reset_all)
	button("Move",15,269,55,func():moving=not moving)
	button("Remove",76,269,58,func():enemies[2].live=false;trigger())
	button("Clear",140,269,55,func():fx.clear();loops=false)
	slider("max_targets",220,1,6,1);slider("jump_range",360,20,100,1);slider("jump_interval",500,0.04,0.3,0.01)
	button("BG",15,317,45,func():dark=not dark;set_bg())
	button("+Frame",66,317,65,func():paused=true;pause_button.text="Play";advance(1.0/60))
	button("Seed+",137,317,58,func():config.seed+=1;trigger())
	status=label("",Vector2(220,334),10);set_bg();refresh();trigger()
func set_bg()->void:
	RenderingServer.set_default_clear_color(Color("202b35") if dark else Color("e1e5dd"))
	for n in get_children():
		if n is Label:n.add_theme_color_override("font_color",Color("e0e7e8") if dark else Color("26323a"))
func refresh()->void:
	for key in sliders:sliders[key].set_value_no_signal(config[key]);labels[key].text="%s: %s"%[key,str(snappedf(config[key],0.01))]
func trigger()->void:
	var targets:Array=[]
	for e in enemies:
		e.order=-1;e.flash=0;e.queue_redraw()
		if e.live:targets.append(e)
	hit_count=0;fx.play(Vector2(10,65),targets,config);timer=0;loops=true
func reset_all()->void:
	config=Chain.DEFAULTS.duplicate(true);paused=false;moving=false;motion=0;pause_button.text="Pause"
	for e in enemies:e.live=true;e.position=e.base
	refresh();trigger()
func advance(dt:float)->void:
	motion+=dt;timer+=dt
	for i in range(enemies.size()):
		var e=enemies[i];e.position=e.base+(Vector2(0,sin(motion*3+i)*6) if moving else Vector2.ZERO);e.flash=maxf(0,e.flash-dt);e.queue_redraw()
	fx.tick(dt)
	if loops and timer>=1.6:trigger()
func _process(dt:float)->void:
	elapsed+=dt
	if auto_demo:
		var next:=mini(4,int(elapsed/2.4))
		if next!=stage:
			stage=next;reset_all();moving=stage==1;config.max_targets=3 if stage==2 else 5;config.jump_interval=0.15 if stage==2 else 0.09
			if stage==3:config.body="d8b4ef";config.edge="795995";enemies[2].live=false
			dark=stage!=4;set_bg();refresh();trigger()
	if not paused:advance(dt)
	status.text="%d links | %d hit targets | %s"%[fx.links.size(),hit_count,"moving" if moving else "static"]
	if capture_dir!="":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(capture_dir.path_join("frame_%05d.png"%frame));frame+=1
	if auto_demo and elapsed>=12 and "--chain-quit" in OS.get_cmdline_user_args():get_tree().quit()
