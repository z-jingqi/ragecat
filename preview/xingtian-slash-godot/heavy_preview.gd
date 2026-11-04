extends Node2D
const Stage=preload("heavy_stage.gd")
const Heavy=preload("components/heavy_profile.gd")
const DEFAULT=preload("presets/heavy_pressure.tres")
const NAMES=["NORMAL / ACCEPTED CLEAVE", "HEAVY / SHORT GROUND PRESSURE", "HEAVY / SIX EXPLICIT CONTACTS"]
var profile=DEFAULT.duplicate()
var stage
var detail
var scenario:=1
var clock:=0.0
var speed:=1.0
var paused:=false
var updating:=false
var movie:=false
var movie_clock:=0.0
var movie_section:=-1
var capture_frame:=0
var sliders:={}
var labels:={}
var timeline:HSlider
var status:Label
var title_label:Label
var pause_button:Button
var speed_button:Button
var color_button:ColorPickerButton
var blood_button:CheckBox
var wave_button:CheckBox
func _ready()->void:
	get_window().content_scale_size=Vector2i(1280,800); get_window().content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	movie="--heavy-capture" in OS.get_cmdline_user_args()
	label("RAGECAT / HEAVY CONTACT STUDY",Vector2(24,16),13,Color("af9c84"))
	label("XING TIAN · COPPER HEAVY CLEAVE",Vector2(24,40),27,Color("f3dfc8"))
	label("Accepted blade language / original broken ground wave / all wave values are art parameters, not damage or collision",Vector2(26,81),13,Color("9fadb6"))
	label("01 / GAME SCALE 1x · 76px HERO",Vector2(36,115),14,Color("d7b698"))
	label("02 / SAME MOMENT 2x",Vector2(720,115),14,Color("d7b698"))
	stage=Stage.new(); stage.position=Vector2(24,140); add_child(stage)
	var box:=SubViewportContainer.new(); box.position=Vector2(704,140); box.size=Vector2(276,215); box.scale=Vector2.ONE*2; box.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST; add_child(box)
	var view:=SubViewport.new(); view.size=Vector2i(276,215); view.render_target_update_mode=SubViewport.UPDATE_ALWAYS; box.add_child(view)
	detail=Stage.new(); detail.hero_origin=Vector2(138,123); detail.arena_size=Vector2(276,215); view.add_child(detail)
	title_label=label("",Vector2(36,580),17,Color("f1c18f")); status=label("",Vector2(710,581),13,Color("a5b3bc"))
	for i in 3: button(["Normal","Heavy","6 targets"][i],Vector2(32+i*105,617),Vector2(96,30),func(): select_scenario(i))
	pause_button=button("Pause",Vector2(351,617),Vector2(85,30),func(): paused=not paused; pause_button.text="Resume" if paused else "Pause")
	button("Replay",Vector2(444,617),Vector2(85,30),replay); button("Clear",Vector2(537,617),Vector2(85,30),clear_all)
	button("Mirror",Vector2(630,617),Vector2(85,30),func(): stage.set_facing(not stage.facing_left); detail.set_facing(stage.facing_left))
	speed_button=button("1x speed",Vector2(723,617),Vector2(96,30),func(): set_speed(.25 if speed==1 else 1.0))
	blood_button=CheckBox.new(); blood_button.text="Blood"; blood_button.position=Vector2(830,616); blood_button.button_pressed=true; add_child(blood_button); blood_button.toggled.connect(func(v:bool): stage.set_blood(v); detail.set_blood(v))
	wave_button=CheckBox.new(); wave_button.text="Wave"; wave_button.position=Vector2(928,616); wave_button.button_pressed=true; add_child(wave_button); wave_button.toggled.connect(func(v:bool): stage.set_wave(v); detail.set_wave(v))
	button("Reset",Vector2(1030,617),Vector2(85,30),reset_settings)
	button("Hit preview",Vector2(1123,617),Vector2(126,30),func(): get_tree().change_scene_to_file("res://hit_preview.tscn"))
	control("pressure_radius","Wave radius / px",32,112,1,Vector2(32,662))
	control("pressure_duration","Wave duration / s",.12,.6,.01,Vector2(278,662))
	control("pressure_strength","Wave strength",0,1.5,.05,Vector2(524,662))
	label("Wave color / editable RGB",Vector2(770,662),12,Color("c6b6a4"))
	color_button=ColorPickerButton.new(); color_button.position=Vector2(770,685); color_button.size=Vector2(215,24); color_button.color=profile.pressure_color; color_button.edit_alpha=false; add_child(color_button)
	color_button.color_changed.connect(func(v:Color): if not updating: profile.pressure_color=v; rebuild())
	control("debris_count","Wave grit / count",0,16,1,Vector2(1016,662))
	control("pressure_thickness","Wave half-width / px",1,6,.25,Vector2(32,719))
	control("pressure_squash","Ground squash",.2,.7,.01,Vector2(278,719))
	control("thickness","Cleave weight / px",4,28,1,Vector2(524,719))
	control("blood_count","Blood amount",0,20,1,Vector2(770,719))
	label("Timeline / paused on scrub",Vector2(1016,719),12,Color("c6b6a4"))
	timeline=HSlider.new(); timeline.position=Vector2(1016,747); timeline.size=Vector2(215,15); timeline.max_value=2.8; timeline.step=1./120.; add_child(timeline)
	timeline.value_changed.connect(func(v:float): if not updating: paused=true; pause_button.text="Resume"; seek_all(v))
	label("Visual staging only · static approved portrait + geometric test enemies · no attack animation, damage, collision, knockback or camera shake",Vector2(32,780),11,Color("7c8d99"))
	select_scenario(1)
func label(value:String,at:Vector2,size_value:int,color:Color)->Label:
	var n:=Label.new(); n.text=value; n.position=at; n.add_theme_font_size_override("font_size",size_value); n.add_theme_color_override("font_color",color); add_child(n); return n
func button(value:String,at:Vector2,size_value:Vector2,action:Callable)->Button:
	var n:=Button.new(); n.text=value; n.position=at; n.size=size_value; n.add_theme_font_size_override("font_size",13); n.pressed.connect(action); add_child(n); return n
func control(key:String,title:String,lo:float,hi:float,step_value:float,at:Vector2)->void:
	labels[key]=label("",at,12,Color("c6b6a4")); labels[key].set_meta("title",title)
	var slider:=HSlider.new(); slider.position=at+Vector2(0,28); slider.size=Vector2(215,15); slider.min_value=lo; slider.max_value=hi; slider.step=step_value; slider.value=profile.get(key); add_child(slider); sliders[key]=slider
	slider.value_changed.connect(func(value:float): if not updating: profile.set(key,value); rebuild())
func sync_controls()->void:
	updating=true
	for key in sliders: sliders[key].value=profile.get(key); labels[key].text="%s  %.2f"%[labels[key].get_meta("title"),profile.get(key)]
	color_button.color=profile.pressure_color; updating=false
func rebuild()->void:
	var saved:=clock; var was_cleared:bool=stage.cleared
	profile=profile.sanitized(); sync_controls()
	stage.configure(profile,scenario); detail.configure(profile,scenario)
	if was_cleared: clear_all()
	else: seek_all(saved)
func reset_settings()->void: profile=DEFAULT.duplicate(); rebuild()
func select_scenario(value:int)->void:
	scenario=clampi(value,0,2); stage.configure(profile,scenario); detail.configure(profile,scenario); sync_controls(); replay()
func set_speed(value:float)->void: speed=value; speed_button.text="0.25x slow" if speed<1 else "1x speed"
func replay()->void: clock=0; paused=false; pause_button.text="Pause"; stage.restart(); detail.restart(); seek_all(0)
func clear_all()->void: paused=true; stage.clear(); detail.clear(); pause_button.text="Resume"; status.text="CLEARED · Replay to start"
func seek_all(value:float)->void:
	if stage.cleared: return
	clock=maxf(0,value); stage.seek(clock); detail.seek(clock); title_label.text=NAMES[scenario]
	status.text=("Normal baseline · controls below adjust Heavy only" if scenario==0 else "%.3fs · %.2fx · wave %dpx / %.2fs / %.2f"%[clock,speed,profile.pressure_radius,profile.pressure_duration,profile.pressure_strength])
	updating=true; timeline.value=minf(clock,2.8); updating=false
func _process(delta:float)->void:
	if movie:
		movie_clock+=delta; capture_frame+=1
		var section:=int(movie_clock/4.)
		if section!=movie_section:
			movie_section=section; profile=DEFAULT.duplicate()
			if section==4: profile.pressure_radius=104; profile.pressure_duration=.48; profile.pressure_strength=1.1; profile.pressure_color=Color("70becb")
			select_scenario(0 if section==0 else (1 if section==1 else 2)); set_speed(.25 if section==3 else 1.)
		if capture_frame in [37,40,278,282,287,294,304,318,522,527,536,552,864,870,890,938,1001,1008,1020,1032]: capture.call_deferred(capture_frame)
		if capture_frame>=1200: get_tree().quit()
	if not paused and not stage.cleared:
		var next:=clock+delta*speed
		if next>2.8: replay(); next=0
		seek_all(next)
func capture(frame:int)->void:
	await RenderingServer.frame_post_draw
	var folder:=OS.get_environment("XINGTIAN_HEAVY_CAPTURE_DIR")
	if not folder.is_empty(): get_viewport().get_texture().get_image().save_png(folder.path_join("heavy-%04d.png"%frame))
func _draw()->void:
	draw_rect(Rect2(0,0,1280,800),Color("11171f"))
	for rect in [Rect2(24,108,656,465),Rect2(704,108,552,465)]: draw_rect(rect,Color("19232d")); draw_rect(rect,Color("35454f"),false)
