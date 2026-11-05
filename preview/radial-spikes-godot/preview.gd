extends Node2D
const FX=preload("components/radial_spikes.gd")
const Profile=preload("components/spike_profile.gd")
const Floor=preload("fixture.gd")
const Character=preload("character.gd")
const NAMES=["EARTH", "ICE", "LIGHTNING"]
var profile:Resource
var fx:Node2D
var floor_node:Node2D
var stage:Node2D
var viewport:SubViewport
var time:float=0
var paused:bool=false
var cleared:bool=false
var updating:bool=false
var seed_value:int=17
var capture:bool=false
var capture_frame:int=0
var selector:OptionButton
var title:Label
var status:Label
var timeline:HSlider
var sliders:Dictionary={}
var colors:Array[ColorPickerButton]=[]
var speed_selector:OptionButton
var playback_speed:float=1.0
var phase_status:Label
var pause_button:Button
func _ready()->void:
	get_window().size=Vector2i(1280,850); get_window().min_size=Vector2i(1280,850)
	profile=load("res://presets/earth.tres").duplicate(true)
	viewport=SubViewport.new(); viewport.size=Vector2i(360,240); viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; add_child(viewport)
	floor_node=Floor.new(); floor_node.z_index=-100; viewport.add_child(floor_node)
	stage=Node2D.new(); stage.y_sort_enabled=true; viewport.add_child(stage)
	fx=FX.new(); stage.add_child(fx)
	var hero:Node2D=Character.new(); hero.position=Vector2(180,139); stage.add_child(hero)
	_label("R A D I A L   E R U P T I O N S",Vector2(28,19),26,Color("e4e4d0"))
	_label("CODE-BUILT PIXEL VFX   /   CAST-CENTERED EXPANSION",Vector2(29,58),13,Color("829b9c"))
	_label("01 / GAME SCALE · 1×",Vector2(28,165),13,Color("8daba8"))
	_label("02 / SAME FRAME · 2× NEAREST",Vector2(477,109),13,Color("8daba8"))
	for i in 2:
		var panel:TextureRect=TextureRect.new(); panel.texture=viewport.get_texture(); panel.position=Vector2(28,194) if i==0 else Vector2(477,139); panel.size=Vector2(360,240)*(1 if i==0 else 2); panel.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST; add_child(panel)
	title=_label("EARTH / FRACTURED STONE",Vector2(29,453),21,Color("dfb077"))
	_label("30px neutral character · 360 × 240 logical field",Vector2(29,490),13,Color("94a6a3"))
	_label("One ring fades while the next ring grows",Vector2(29,514),13,Color("94a6a3"))
	_label("Visual prototype only. No combat rules.",Vector2(29,538),13,Color("6f8888"))
	selector=OptionButton.new(); selector.position=Vector2(28,106); selector.size=Vector2(177,34)
	for n in NAMES:
		selector.add_item(n)
		selector.set_item_disabled(selector.item_count-1,not ResourceLoader.exists("res://presets/"+n.to_lower()+".tres"))
	add_child(selector); selector.item_selected.connect(select_element)
	_button("Replay",Vector2(218,106),func(): replay())
	_button("New seed",Vector2(307,106),func(): seed_value+=1; replay())
	pause_button=_button("Pause",Vector2(29,578),func(): paused=not paused; pause_button.text="Resume" if paused else "Pause")
	_button("Clear",Vector2(116,578),func(): cleared=true; fx.clear(); refresh())
	_button("Light / Dark",Vector2(203,578),func(): floor_node.light_background=not floor_node.light_background; floor_node.queue_redraw(),107)
	_button("Reset",Vector2(322,578),func(): select_element(selector.selected),67)
	status=_label("",Vector2(478,630),13,Color("9fb6af"))
	phase_status=_label("",Vector2(478,651),11,Color("94a6a3"))
	speed_selector=OptionButton.new(); speed_selector.position=Vector2(298,649); speed_selector.size=Vector2(100,29); speed_selector.add_item("Speed 1×"); speed_selector.add_item("Speed 0.35×"); add_child(speed_selector)
	speed_selector.item_selected.connect(func(i:int): playback_speed=1.0 if i==0 else .35)
	_label("PRIMARY     LIT EDGE    SHADOW",Vector2(28,630),11,Color("799690"))
	for i in 3:
		var picker:ColorPickerButton=ColorPickerButton.new(); picker.position=Vector2(29+i*87,652); picker.size=Vector2(72,23); add_child(picker); colors.append(picker)
		var key:String=["primary","highlight","shadow"][i]
		picker.color_changed.connect(func(c:Color): profile.set(key,c); fx.configure(profile); refresh())
	timeline=HSlider.new(); timeline.position=Vector2(478,684); timeline.size=Vector2(719,18); timeline.min_value=0; timeline.step=.001; add_child(timeline)
	timeline.value_changed.connect(func(v:float):
		if not updating: paused=true; pause_button.text="Resume"; time=v; refresh())
	var specs:Array=[
		["Layers","layers",1,6,1],["Outer radius","radius",36,150,1],["Layer delay","layer_delay",0,.5,.01],["Density","density",.3,1.6,.05],["Spike size","spike_size",.5,1.5,.05],
		["Rise time","rise_time",.06,.35,.01],["Hold time","hold_time",0,1.5,.05],["Fade time","fade_time",.1,1,.05],["Irregularity","irregularity",0,1,.05],["Fade overlap","layer_overlap",0,.4,.01]]
	for i in specs.size():
		var spec:Array=specs[i]; var at:Vector2=Vector2(28+(i%5)*244,710+(i/5)*66)
		var caption:Label=_label(spec[0],at,12,Color("8eaaa5"))
		var slider:HSlider=HSlider.new(); slider.position=at+Vector2(0,25); slider.size=Vector2(215,18); slider.min_value=spec[2]; slider.max_value=spec[3]; slider.step=spec[4]; add_child(slider)
		var key:String=spec[1]; sliders[key]={"slider":slider,"label":caption,"title":spec[0]}
		slider.value_changed.connect(func(v:float):
			if updating: return
			profile.set(key,int(v) if key=="layers" else v); profile=profile.clean(); fx.configure(profile); _sync(); replay())
	capture="--capture" in OS.get_cmdline_user_args()
	var element:int=0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--element="): element=clampi(int(arg.split("=")[1]),0,2)
	select_element(element)
func _label(txt:String,at:Vector2,sz:int,col:Color)->Label:
	var n:Label=Label.new(); n.text=txt; n.position=at; n.add_theme_font_size_override("font_size",sz); n.modulate=col; add_child(n); return n
func _button(txt:String,at:Vector2,callback:Callable,width:float=78)->Button:
	var n:Button=Button.new(); n.text=txt; n.position=at; n.size=Vector2(width,31); add_child(n); n.pressed.connect(callback); return n
func select_element(index:int)->void:
	var path:String="res://presets/"+NAMES[index].to_lower()+".tres"
	if not ResourceLoader.exists(path): index=0; path="res://presets/earth.tres"
	profile=load(path).duplicate(true); selector.select(index)
	title.text=["EARTH / FRACTURED STONE","ICE / CRYSTAL BLOOM","LIGHTNING / ARC CASCADE"][index]; title.modulate=profile.highlight
	fx.configure(profile); _sync(); replay()
func _sync()->void:
	updating=true
	for key in sliders:
		var entry:Dictionary=sliders[key]
		if key=="layer_overlap": entry.slider.max_value=minf(profile.fade_time,profile.layer_span()*.49)
		entry.slider.value=profile.get(key); entry.label.text=("Bolt size" if key=="spike_size" and profile.element==2 else entry.title)+"  "+str(snappedf(profile.get(key),.01))
	for i in 3: colors[i].color=profile.get(["primary","highlight","shadow"][i])
	timeline.max_value=profile.lifetime()+.25
	updating=false
func replay()->void:
	time=0; paused=false; cleared=false; pause_button.text="Pause"; fx.play(Vector2(180,139),seed_value); refresh()
func refresh()->void:
	if not cleared: fx.seek(time)
	updating=true; timeline.value=time; updating=false
	var active:Array[int]=fx.active_layers()
	status.text="t = %.2fs   /   visible layers %d / %d   /   seed %d   /   %.2f×"%[time,active.size(),profile.layers,seed_value,playback_speed]
	var phases:Array[String]=[]
	for layer in profile.layers:
		phases.append("L%d %s"%[layer+1,_layer_phase(layer)])
	phase_status.text="  ·  ".join(phases) if not cleared else "Cleared"
func _layer_phase(layer:int)->String:
	var states:Array[String]=[]
	for site in fx.spikes:
		if site.layer!=layer: continue
		var local:float=time-site.spawn
		var phase:String="waiting" if local<0 else "growing" if local<profile.rise_time else "holding" if local<profile.rise_time+profile.hold_time else "fading" if local<profile.rise_time+profile.hold_time+profile.fade_time else "gone"
		if not states.has(phase): states.append(phase)
	for phase in ["growing","holding","fading"]:
		if states.has(phase): return phase
	return "waiting" if states.has("waiting") else "gone"
func _process(delta:float)->void:
	if capture:
		capture_frame+=1
		playback_speed=1.0 if capture_frame<360 else .35
		speed_selector.select(0 if capture_frame<360 else 1)
		if capture_frame==360: time=0; fx.play(Vector2(180,139),seed_value)
		floor_node.light_background=capture_frame>=720; floor_node.queue_redraw()
		if capture_frame>=960: get_tree().quit(); return
	if not paused and not cleared:
		time+=(1.0/60 if capture else delta)*playback_speed
		if time>profile.lifetime()+.65: time=0; fx.play(Vector2(180,139),seed_value)
		refresh()
func _unhandled_key_input(event:InputEvent)->void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_SPACE: paused=not paused; pause_button.text="Resume" if paused else "Pause"
		elif event.keycode==KEY_R: replay()
		elif event.keycode==KEY_ESCAPE: get_tree().quit()
