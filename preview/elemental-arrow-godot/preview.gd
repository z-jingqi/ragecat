extends Node2D
const Effect=preload("components/elemental_arrow.gd")
const Profile=preload("components/arrow_profile.gd")
const Fixture=preload("fixture.gd")
@export var configuration:Resource
var fx:Node2D
var profile:Resource
var fixture:Node2D
var time:float=0
var paused:bool=false
var cleared:bool=false
var path_mode:int=0
var speed:float=180
var frame:int=0
var capture:bool=false
var capture_mode:int=0
var names=["PLAIN","FIRE","LIGHTNING","ICE"]
var status:Label
var checks:Dictionary={}
var sliders:Dictionary={}
var slider_labels:Dictionary={}
var timeline:HSlider
var selector:OptionButton
var edit_selector:OptionButton
var color_button:ColorPickerButton
var lightning_selector:OptionButton
var path_selector:OptionButton
var updating:bool=false
var body_selector:OptionButton
var scale_label:Label
func _ready()->void:
	get_window().min_size=Vector2i(1280,800); get_window().size=Vector2i(1280,800)
	profile=configuration.sanitized() if configuration is Profile else Profile.new()
	var vp=SubViewport.new(); vp.size=Vector2i(380,242); vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS; add_child(vp)
	fixture=Fixture.new(); vp.add_child(fixture); fx=Effect.new(); vp.add_child(fx)
	for i in 2:
		var panel=TextureRect.new(); panel.texture=vp.get_texture(); panel.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		panel.position=Vector2(30,230) if i==0 else Vector2(490,145); panel.size=Vector2(380,242)*(1 if i==0 else 2); add_child(panel)
	_label("ARROW / ELEMENTAL ATTACHMENTS",Vector2(28,17),27,Color("ede0c9"))
	_label("Original pixel geometry • host-driven movement • independent layers",Vector2(29,55),15,Color("9aaeb9"))
	_label("01 / GAME SIZE 1x",Vector2(29,197),15,Color("8da5b1"))
	_label("02 / SAME FRAME 2x NEAREST",Vector2(490,116),15,Color("8da5b1"))
	scale_label=_label("Arrow / 30px static scale guides",Vector2(29,489),14,Color("8da5b1"))
	_label("No damage, collision, status or combat rules",Vector2(29,513),14,Color("6b8491"))
	selector=OptionButton.new(); selector.position=Vector2(28,101); selector.size=Vector2(160,33)
	for n in names: selector.add_item(n)
	for i in range(1,4): selector.set_item_disabled(i,not ResourceLoader.exists("res://modules/"+names[i].to_lower()+".gd"))
	add_child(selector); selector.item_selected.connect(select_preset)
	path_selector=OptionButton.new(); path_selector.position=Vector2(211,101); path_selector.size=Vector2(214,33)
	for n in ["RIGHT →", "← LEFT", "DIAGONAL", "CURVE / TURN", "STATIONARY"]: path_selector.add_item(n)
	add_child(path_selector); path_selector.item_selected.connect(func(v): path_mode=v; replay())
	body_selector=OptionButton.new(); body_selector.position=Vector2(440,74); body_selector.size=Vector2(300,33)
	body_selector.add_item("BODY: CLASSIC"); body_selector.add_item("BODY: REFERENCE")
	add_child(body_selector); body_selector.item_selected.connect(func(v): profile.body_style=v; fx.configure(profile); refresh())
	edit_selector=OptionButton.new(); edit_selector.position=Vector2(780,74); edit_selector.size=Vector2(218,32)
	for n in ["EDIT: BODY","EDIT: FIRE","EDIT: LIGHTNING","EDIT: ICE"]: edit_selector.add_item(n)
	add_child(edit_selector); edit_selector.item_selected.connect(func(_i): _sync_sliders())
	lightning_selector=OptionButton.new(); lightning_selector.position=Vector2(1012,74); lightning_selector.size=Vector2(238,32)
	lightning_selector.add_item("LIGHTNING: SPIRAL"); lightning_selector.add_item("LIGHTNING: CRACKLE"); lightning_selector.add_item("LIGHTNING: DOUBLE"); lightning_selector.add_item("LIGHTNING: REFERENCE")
	add_child(lightning_selector); lightning_selector.item_selected.connect(func(v): profile.lightning.lightning_mode=v; _sync_sliders(); fx.configure(profile); refresh())
	for i in 5:
		var k=["body","air","fire","lightning","ice"][i]; var b=CheckBox.new(); b.position=Vector2([24,110,190,272,384][i],149); b.text=k.capitalize(); b.button_pressed=true; add_child(b); checks[k]=b
		b.toggled.connect(func(on):
			if k in Effect.ELEMENTS: profile.get(k).enabled=on; fx.configure(profile)
			else: profile.set(k+"_enabled",on); fx.configure(profile))
	status=_label("",Vector2(29,551),15,Color("f3bd7b"))
	_button("Replay",Vector2(28,590),func(): replay())
	_button("Pause",Vector2(112,590),func(): paused=not paused)
	_button("Clear",Vector2(196,590),func(): cleared=true; fx.clear())
	_button("Light / Dark",Vector2(280,590),func(): fixture.light_background=not fixture.light_background; fixture.queue_redraw())
	color_button=ColorPickerButton.new(); color_button.position=Vector2(399,590); color_button.size=Vector2(60,33); color_button.color=Color.WHITE; color_button.tooltip_text="Tint the selected preset element (or plain arrow body)"; add_child(color_button)
	color_button.color_changed.connect(func(col):
		if edit_selector.selected==0: profile.body_tint=col
		else: profile.get(names[edit_selector.selected].to_lower()).tint=col
		fx.configure(profile); refresh())
	timeline=HSlider.new(); timeline.position=Vector2(28,657); timeline.size=Vector2(1222,20); timeline.min_value=0; timeline.max_value=2; timeline.step=.001; add_child(timeline)
	timeline.value_changed.connect(func(v):
		if not updating: paused=true; time=v; refresh())
	_slider("Length","length",18,128,34,Vector2(28,696))
	_slider("Width","width",.6,2,1,Vector2(230,696))
	_slider("Travel rate","speed",60,300,180,Vector2(432,696))
	_slider("Element size","size",.3,2,1,Vector2(634,696))
	_slider("Intensity","intensity",0,2,1,Vector2(836,696))
	_slider("Wake length","trail_length",0,2,1,Vector2(1038,696))
	capture="--capture" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--element="): capture_mode=clampi(int(arg.split("=")[1]),0,3)
	if capture: select_preset(capture_mode)
	else:
		fx.configure(profile); _sync_checks(); _sync_sliders(); replay()
func _label(txt:String,at:Vector2,sz:int,color:Color)->Label:
	var n=Label.new(); n.text=txt; n.position=at; n.add_theme_font_size_override("font_size",sz); n.modulate=color; add_child(n); return n
func _button(txt:String,at:Vector2,cb:Callable)->void:
	var n=Button.new(); n.text=txt; n.position=at; n.size=Vector2(76,33); add_child(n); n.pressed.connect(cb)
func _slider(title:String,key:String,lo:float,hi:float,initial:float,at:Vector2)->void:
	var cap=_label(title+" "+str(initial),at,14,Color("a0b3bc")); var s=HSlider.new(); s.position=at+Vector2(0,26); s.size=Vector2(180,22); s.min_value=lo; s.max_value=hi; s.step=.05; s.value=initial; add_child(s); sliders[key]=s; slider_labels[key]=cap
	s.value_changed.connect(func(v):
		cap.text=(("Arc visibility" if profile.lightning.lightning_mode>=2 else "Arc density") if key=="trail_length" and edit_selector.selected==2 else "Arc amplitude" if key=="size" and edit_selector.selected==2 else title)+" "+str(snappedf(v,.01))
		if updating: return
		if key=="speed": speed=v
		elif key in ["length","width"]: profile.set(key,v)
		else:
			if edit_selector.selected>0: profile.get(names[edit_selector.selected].to_lower()).set("arc_density" if key=="trail_length" and edit_selector.selected==2 else key,v)
		fx.configure(profile); refresh())
func select_preset(index:int)->void:
	var file="res://presets/"+("plain" if index==0 else names[index].to_lower())+".tres"
	profile=load(file).sanitized() if ResourceLoader.exists(file) else Profile.new()
	selector.selected=index; edit_selector.selected=index
	_sync_checks(); _sync_sliders()
	fx.configure(profile); refresh()
func _sync_sliders()->void:
	var index=edit_selector.selected
	lightning_selector.selected=profile.lightning.lightning_mode
	updating=true
	sliders.trail_length.max_value=1.0 if index==2 and profile.lightning.lightning_mode>=2 else 2.0
	for k in sliders:
		if k=="speed": sliders[k].value=speed
		elif k in ["length","width"]: sliders[k].value=profile.get(k)
		else:
			sliders[k].editable=index>0
			sliders[k].value=profile.get(names[index].to_lower()).get("arc_density" if k=="trail_length" and index==2 else k) if index>0 else 1.0
			if k in ["trail_length","size"]:
				slider_labels[k].text=(("Arc visibility" if profile.lightning.lightning_mode>=2 else "Arc density") if k=="trail_length" and index==2 else "Wake length" if k=="trail_length" else "Arc amplitude" if index==2 else "Element size")+" "+str(snappedf(sliders[k].value,.01))
	if color_button!=null: color_button.color=profile.body_tint if index==0 else profile.get(names[index].to_lower()).tint
	updating=false
func _sync_checks()->void:
	body_selector.selected=profile.body_style
	checks.body.set_pressed_no_signal(profile.body_enabled); checks.air.set_pressed_no_signal(profile.air_enabled)
	for k in Effect.ELEMENTS:
		checks[k].disabled=not ResourceLoader.exists("res://modules/"+k+".gd")
		checks[k].set_pressed_no_signal(profile.get(k).enabled)
func travel_distance()->float:
	return maxf(60,336-profile.length) if profile.body_style==1 or profile.length>48 else 280.0
func trajectory(t:float)->Dictionary:
	var distance=travel_distance()
	var duration=distance/speed; var u=clampf(t/duration,0,1); var tip:Vector2; var velocity:Vector2
	match path_mode:
		1: tip=Vector2(330-280*u,118); velocity=Vector2(-speed,0)
		2: tip=Vector2(76+230*u,174-118*u); velocity=Vector2(230,-118)/duration
		3:
			tip=Vector2(64+255*u,126-62*sin(u*PI*1.65))
			velocity=Vector2(255,-62*PI*1.65*cos(u*PI*1.65))/duration
		4: tip=Vector2(218,118); velocity=Vector2.ZERO
		_: tip=Vector2(55+280*u,118); velocity=Vector2(speed,0)
	if profile.body_style==1 or profile.length>48:
		match path_mode:
			1: tip=Vector2(380-profile.length-22-distance*u,118); velocity=Vector2(-speed,0)
			2:
				var move=Vector2(260-profile.length*.8,-90)
				tip=Vector2(35+profile.length*.90,160-profile.length*.15)+move*u; velocity=move/duration
			3:
				tip=Vector2(profile.length+22+distance*u,126-45*sin(u*PI*1.65))
				velocity=Vector2(distance,-45*PI*1.65*cos(u*PI*1.65))/duration
			4: tip=Vector2(190+profile.length*.5,118); velocity=Vector2.ZERO
			_: tip=Vector2(profile.length+22+distance*u,118); velocity=Vector2(speed,0)
	return {"tip":tip,"velocity":Vector2.ZERO if t>duration else velocity,"axis":velocity.normalized() if velocity.length_squared()>0 else Vector2.RIGHT}
func replay()->void:
	time=0; cleared=false; paused=false; var s=trajectory(0); fx.play(s.tip,s.velocity,profile)
	refresh()
func refresh()->void:
	scale_label.text="%dpx arrow / 30px static scale guides"%profile.length
	timeline.max_value=travel_distance()/speed+.4
	if not fx.running and not cleared:
		var s=trajectory(0); fx.play(s.tip,s.velocity,profile)
	fx.seek(time,trajectory)
	fx.visible=time<=travel_distance()/speed+.1 or path_mode==4
func _process(delta:float)->void:
	if capture:
		var phase=int(frame/120)%5; path_mode=phase; path_selector.selected=phase
		if frame%120==0: replay()
		time=float(frame%120)/60.0; refresh(); frame+=1
		var dir=OS.get_environment("ARROW_CAPTURE_DIR")
		if not dir.is_empty() and frame in [30,60,150,180,270,300,390,420,510,540]: _capture(dir,frame)
		if frame>=600: get_tree().quit()
	elif not paused and not cleared:
		time+=delta; refresh()
		if time>travel_distance()/speed+.6 and path_mode!=4: replay()
	updating=true; timeline.value=time; updating=false
	var active=[]
	for k in Effect.ELEMENTS:
		if profile.get(k).enabled: active.append(k.to_upper())
	status.text=("CLEARED" if cleared else ("PLAIN" if active.is_empty() else "+".join(active))+" / "+path_selector.get_item_text(path_mode))+"   %.2fs"%time
func _capture(dir:String,fr:int)->void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join("frame-%03d.png"%fr))
