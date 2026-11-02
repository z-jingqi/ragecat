extends Node2D
const Spawn = preload("res://effects/VFX-13_monster_spawn/spawn.gd")
var effects: Array[Node2D]=[]
var hosts: Array[Sprite2D]=[]
var paused:=false
var cycle:=0.0
var elapsed:=0.0
var frame:=0
var stage:=-1
var looping:=true
var palette_index:=0
var capture_dir:=""
var status:Label
var sliders:Dictionary={}
var labels:Dictionary={}
var pause_button:Button
var preset_button:Button
var auto_demo:=false
func host_texture() -> ImageTexture:
	var image:=Image.create(28,40,false,Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for entry in [[Rect2i(6,9,16,12),"45596a"],[Rect2i(8,7,12,3),"8096a1"],[Rect2i(3,5,4,8),"a8b5b5"],[Rect2i(21,5,4,8),"a8b5b5"],[Rect2i(8,14,12,7),"d5c6ac"],[Rect2i(8,14,4,2),"252c35"],[Rect2i(16,14,4,2),"252c35"],[Rect2i(7,21,14,11),"577680"],[Rect2i(10,22,8,7),"88a8a7"],[Rect2i(3,23,4,8),"45596a"],[Rect2i(21,23,4,8),"45596a"],[Rect2i(8,32,5,7),"35434e"],[Rect2i(15,32,5,7),"35434e"],[Rect2i(6,38,7,2),"74878d"],[Rect2i(15,38,7,2),"74878d"]]:
		image.fill_rect(entry[0],Color(entry[1]))
	return ImageTexture.create_from_image(image)
func _ready()->void:
	RenderingServer.set_default_clear_color(Color("20262b"))
	auto_demo="--spawn-auto" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):capture_dir=arg.trim_prefix("--capture-dir=");DirAccess.make_dir_recursive_absolute(capture_dir)
	for i in range(2):
		var group:=Node2D.new();group.position=Vector2(160,136) if i==0 else Vector2(160,290);group.scale=Vector2.ONE*(1 if i==0 else 2);add_child(group)
		var fx:=Spawn.new();group.add_child(fx);effects.append(fx)
		var body:=Sprite2D.new();body.texture=host_texture();body.position=Vector2(0,-20);body.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;body.visible=false;group.add_child(body);hosts.append(body);fx.host=body
	make_ui();replay()
func label_at(text:String,pos:Vector2,size:int=11)->Label:
	var l:=Label.new();l.text=text;l.position=pos;l.add_theme_font_size_override("font_size",size);add_child(l);return l
func button(text:String,x:float,y:float,width:float,fn:Callable)->Button:
	var b:=Button.new();b.text=text;b.position=Vector2(x,y);b.size=Vector2(width,26);b.add_theme_font_size_override("font_size",11);b.pressed.connect(fn);add_child(b);return b
func slider(key:String,y:float,lo:float,hi:float,step:float,value:float)->void:
	labels[key]=label_at(key,Vector2(350,y))
	var s:=HSlider.new();s.position=Vector2(486,y);s.size=Vector2(132,20);s.min_value=lo;s.max_value=hi;s.step=step;s.value=value
	s.value_changed.connect(func(v):labels[key].text="%s: %s"%[key,str(v)])
	add_child(s);sliders[key]=s;labels[key].text="%s: %s"%[key,str(value)]
func make_ui()->void:
	label_at("13 / MONSTER SPAWN",Vector2(20,12),18)
	label_at("Ground anchor > gather > reveal > clear",Vector2(20,40))
	label_at("ACTUAL SIZE / 1x",Vector2(20,76))
	label_at("DETAIL / 2x NEAREST",Vector2(20,178))
	pause_button=button("Pause",350,15,65,toggle_pause)
	button("+ Frame",420,15,65,step_frame)
	button("Replay",490,15,60,replay)
	button("Reset",555,15,65,reset_all)
	slider("duration",83,0.18,1.0,0.01,0.55)
	slider("radius",119,10,56,1,29)
	slider("particle_count",155,0,32,1,12)
	slider("ring_width",191,1,3,1,1)
	slider("reveal_at",227,0.1,0.7,0.05,0.35)
	button("Cancel",350,269,75,cancel)
	preset_button=button("Mint",433,269,85,palette_toggle)
	button("Seed +1",526,269,92,change_seed)
	button("Apply + replay",350,306,125,replay)
	button("Loop on/off",483,306,135,func():looping=not looping)
	status=label_at("",Vector2(20,336),10)
func toggle_pause()->void:paused=not paused;pause_button.text="Play" if paused else "Pause"
func step_frame()->void:paused=true;pause_button.text="Play";advance(1.0/60.0)
func config()->Dictionary:
	var out:={}
	for key in sliders:out[key]=sliders[key].value
	out.palette=["4c7b89","84d6c1","e2f6cf"] if palette_index==0 else ["765487","c08dde","f0dcb6"]
	return out
func replay()->void:
	cycle=0
	for i in range(2):
		effects[i].cancel();hosts[i].visible=false;effects[i].configure(config());effects[i].play()
func cancel()->void:
	looping=false
	for fx in effects:fx.cancel()
func palette_toggle()->void:palette_index=1-palette_index;preset_button.text="Mint" if palette_index==0 else "Arcane";replay()
func change_seed()->void:
	for fx in effects:fx.cancel();fx.seed_value+=1
	replay()
func reset_all()->void:
	paused=false;looping=true;palette_index=0;preset_button.text="Mint";pause_button.text="Pause"
	var defaults:={"duration":0.55,"radius":29,"particle_count":12,"ring_width":1,"reveal_at":0.35}
	for key in defaults:sliders[key].value=defaults[key]
	for fx in effects:fx.seed_value=13
	replay()
func advance(dt:float)->void:
	cycle+=dt;elapsed+=dt
	for fx in effects:fx.tick(dt)
	if auto_demo:
		var next:=int(elapsed/2.0)
		if next!=stage:
			stage=next
			if stage==2:palette_toggle()
			if stage==3:sliders.radius.value=43;sliders.particle_count.value=18;replay()
			if stage==4:sliders.duration.value=0.32;sliders.radius.value=23;replay()
			if stage==5:reset_all()
		if stage==5 and cycle>0.15 and cycle<0.2:cancel()
		if elapsed>=11.0 and "--spawn-quit" in OS.get_cmdline_user_args():get_tree().quit()
	if looping and cycle>effects[0].duration+0.65:replay()
func _process(delta:float)->void:
	if not paused:advance(1.0/60.0 if auto_demo else minf(delta,0.1))
	status.text="%.2f s | %s | parameters apply on Replay"%[effects[0].age,"CANCELLED" if not looping and not effects[0].active else ("APPEARED" if effects[0].did_appear else "GATHERING")]
	if capture_dir!="":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(capture_dir+"/frame_%05d.png"%frame);frame+=1
