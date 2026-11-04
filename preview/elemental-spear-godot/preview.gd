extends Node2D
const Profile=preload("components/spear_profile.gd")
const Effect=preload("components/elemental_spear.gd")
const Fixture=preload("fixture.gd")
@export var configuration:Resource
var profile:Resource
var effects:Array=[]
var fixtures:Array=[]
var paused:bool=false
var cleared:bool=false
var age:float=0
var timeline:HSlider
var status:Label
var sliders:Dictionary={}
var phase_buttons:Dictionary={}
var element_selector:OptionButton
var field_selector:OptionButton
var updating:bool=false
var capture_mode:bool=false
var capture_element:int=0
var capture_frame:int=0
var capture_total:int=0
var font=ThemeDB.fallback_font
func _ready() -> void:
	get_window().min_size=Vector2i(1280,800); get_window().size=Vector2i(1280,800)
	profile=(configuration if configuration is Profile else Profile.new()).sanitized()
	for i in 2:
		var viewport=SubViewport.new(); viewport.size=Vector2i(300,260); viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; add_child(viewport)
		var fixture=Fixture.new(); viewport.add_child(fixture); fixtures.append(fixture)
		var effect=Effect.new(); viewport.add_child(effect); effects.append(effect)
		var panel=TextureRect.new(); panel.texture=viewport.get_texture(); panel.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		panel.position=Vector2(167,245) if i==0 else Vector2(650,108); panel.size=Vector2(300,260)*(1 if i==0 else 2); add_child(panel)
	_label("ELEMENTAL SPEAR / MODULAR VFX",Vector2(26,18),28,Color("ecdfc8"))
	_label("01 / GAME SIZE 1x",Vector2(26,77),15,Color("879ba9"))
	_label("02 / SAME FRAME 2x NEAREST",Vector2(650,77),15,Color("879ba9"))
	_label("28px static figures are size guides only",Vector2(172,520),14,Color("879ba9"))
	_label("Midpoint → double tips → hover → fall → impact → field → dissolve",Vector2(26,54),15,Color("a1b0ba"))
	_button("Replay",Vector2(26,574),func(): replay())
	_button("Pause / Resume",Vector2(116,574),func(): paused=not paused)
	_button("Clear",Vector2(280,574),func(): clear_all())
	_button("Light / Dark",Vector2(365,574),func():
		for f in fixtures: f.light_background=not f.light_background; f.queue_redraw())
	element_selector=OptionButton.new(); element_selector.position=Vector2(26,124); element_selector.size=Vector2(150,32)
	for item in ["FIRE", "LIGHTNING", "ICE"]: element_selector.add_item(item)
	add_child(element_selector); element_selector.item_selected.connect(select_element)
	for i in [1,2]: element_selector.set_item_disabled(i,not ResourceLoader.exists(["","res://modules/lightning.gd","res://modules/ice.gd"][i]))
	field_selector=OptionButton.new(); field_selector.position=Vector2(200,124); field_selector.size=Vector2(195,32)
	for item in ["FIELD: FIRE","FIELD: LIGHTNING","FIELD: ICE"]: field_selector.add_item(item)
	for i in [1,2]: field_selector.set_item_disabled(i,not ResourceLoader.exists(["","res://modules/lightning.gd","res://modules/ice.gd"][i]))
	add_child(field_selector); field_selector.item_selected.connect(func(index): profile.field.element=index; profile.dissolve.element=index; rebuild())
	_button("Reset",Vector2(423,124),func(): select_element(element_selector.selected))
	for i in Profile.PHASES.size():
		var key=Profile.PHASES[i]; var check=CheckBox.new(); check.text=key.capitalize(); check.position=Vector2(22+i*86,171); check.button_pressed=true; add_child(check)
		check.toggled.connect(func(value): for e in effects: e.set_stage_enabled(key,value))
		phase_buttons[key]=check
	status=_label("",Vector2(26,215),16,Color("f7b96e"))
	timeline=HSlider.new(); timeline.position=Vector2(26,638); timeline.size=Vector2(1222,20); timeline.min_value=0; timeline.step=.001
	add_child(timeline); timeline.value_changed.connect(func(value):
		if not updating: paused=true; seek_all(value))
	_slider("Length","spear_length",28,100,70,Vector2(26,676))
	_slider("Width","spear_width",3,16,8,Vector2(266,676))
	_slider("Fall speed","fall_speed",80,900,540,Vector2(506,676))
	_slider("Field radius","field_radius",18,100,57,Vector2(746,676))
	_slider("Field seconds","field_duration",.3,8,2.4,Vector2(986,676))
	_label("Phase resources: duration, size, color, intensity + custom renderer. No gameplay, damage or collision.",Vector2(26,755),15,Color("879ba9"))
	capture_mode="--capture" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--element="): capture_element=clampi(int(arg.split("=")[1]),0,2)
	if capture_mode: select_element(capture_element)
	else:
		element_selector.selected=profile.form.element; field_selector.selected=profile.field.element
		updating=true
		for key in sliders: sliders[key].value=profile.field.duration if key=="field_duration" else profile.get(key)
		updating=false; rebuild()
	capture_total=int(ceil((profile.total_duration()+.5)*60))*2
func _label(text_value:String,at:Vector2,size_value:int,color:Color)->Label:
	var node=Label.new(); node.text=text_value; node.position=at; node.add_theme_font_size_override("font_size",size_value); node.modulate=color; add_child(node); return node
func _button(text_value:String,at:Vector2,callback:Callable)->void:
	var node=Button.new(); node.text=text_value; node.position=at; node.size=Vector2(78,32); add_child(node); node.pressed.connect(callback)
func _slider(title:String,key:String,low:float,high:float,initial:float,at:Vector2)->void:
	var caption=_label(title+"  "+str(snappedf(initial,.01)),at,14,Color("a1b0ba")); var node=HSlider.new(); node.position=at+Vector2(0,27); node.size=Vector2(205,22); node.min_value=low; node.max_value=high; node.step=.01 if key=="field_duration" else 1; node.value=initial; add_child(node); sliders[key]=node
	node.value_changed.connect(func(value):
		caption.text=title+"  "+str(snappedf(value,.01))
		if updating: return
		if key=="field_duration": profile.field.duration=value
		else: profile.set(key,value)
		rebuild())
func select_element(index:int)->void:
	var preset_path=["res://presets/fire.tres","res://presets/lightning.tres","res://presets/ice.tres"][index]
	profile=load(preset_path).sanitized() if ResourceLoader.exists(preset_path) else Profile.new()
	for key in Profile.PHASES: profile.phase(key).element=index
	element_selector.selected=index; field_selector.selected=index
	updating=true
	for key in sliders: sliders[key].value=profile.field.duration if key=="field_duration" else profile.get(key)
	updating=false
	rebuild()
func rebuild()->void:
	var was_cleared=cleared
	for e in effects:
		e.play(Vector2(150,218),profile)
		for key in phase_buttons: e.set_stage_enabled(key,phase_buttons[key].button_pressed)
		e.seek(age)
		if was_cleared: e.clear()
	timeline.max_value=profile.total_duration()
func replay()->void:
	cleared=false; age=0; rebuild(); paused=false
func clear_all()->void:
	cleared=true
	for e in effects: e.clear()
func seek_all(value:float)->void:
	age=maxf(0,value)
	for e in effects: e.seek(age)
func _process(delta:float)->void:
	if capture_mode:
		var cycle=int(ceil((profile.total_duration()+.5)*60))
		if capture_frame==cycle:
			# Second cycle proves replacement: one different ground module if available.
			if "--mix" in OS.get_cmdline_user_args() and ResourceLoader.exists("res://modules/lightning.gd"):
				var replacement=(capture_element+1)%3
				if replacement==2 and not ResourceLoader.exists("res://modules/ice.gd"): replacement=0
				profile.field.element=replacement; profile.dissolve.element=profile.field.element; field_selector.selected=profile.field.element; rebuild()
		seek_all(float(capture_frame%cycle)/60.0); capture_frame+=1
		var folder=OS.get_environment("SPEAR_CAPTURE_DIR")
		if not folder.is_empty() and capture_frame in [10,20,31,38,44,50,72,122,180,205]:
			_save_capture(folder,capture_frame)
		if capture_frame>=capture_total: get_tree().quit()
	elif not paused and not cleared:
		seek_all(age+delta)
		if age>profile.total_duration()+.8: replay()
	updating=true; timeline.value=age; updating=false
	var active=[]
	for key in Profile.PHASES:
		if effects[0].layers[key].sample().active: active.append(key)
	status.text=("CLEARED" if cleared else " + ".join(active).to_upper())+"   %.2f / %.2f s"%[age,profile.total_duration()]

func _save_capture(folder:String,frame_number:int)->void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(folder.path_join("element-%d-frame-%03d.png"%[capture_element,frame_number]))
