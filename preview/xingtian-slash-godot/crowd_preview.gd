extends Node2D
const Stage=preload("crowd_stage.gd")
const NAMES=["3 CONTACTS / SAME FRAME","6 CONTACTS / 35ms STAGGER","6 CONTACTS / RAPID REPEATS"]
var stage
var detail
var scenario:=0
var clock:=0.0
var speed:=1.0
var paused:=false
var updating:=false
var movie:=false
var movie_clock:=0.0
var movie_section:=-1
var capture_frame:=0
var timeline:HSlider
var status:Label
var title_label:Label
var time_label:Label
var pause_button:Button
var speed_button:Button
var blood_button:CheckBox

func _ready()->void:
	get_window().content_scale_size=Vector2i(1280,800); get_window().content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	movie="--crowd-capture" in OS.get_cmdline_user_args()
	label("RAGECAT / MULTI-TARGET CONTACT STUDY",Vector2(28,18),13,Color("af9c84"))
	label("XING TIAN · CROWD READABILITY",Vector2(28,42),28,Color("f3dfc8"))
	label("Unchanged copper cleave + independent impact instances / approved portrait / geometric test enemies",Vector2(30,84),14,Color("9fadb6"))
	label("01 / GAME SCALE 1x",Vector2(40,126),15,Color("d7b698"))
	label("02 / SAME MOMENT 2x",Vector2(850,126),15,Color("d7b698"))
	stage=Stage.new(); stage.position=Vector2(28,158); add_child(stage)
	var container:=SubViewportContainer.new(); container.position=Vector2(834,158); container.size=Vector2(210,245); container.scale=Vector2.ONE*2; container.stretch=false; container.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST; add_child(container)
	var view:=SubViewport.new(); view.size=Vector2i(210,245); view.render_target_update_mode=SubViewport.UPDATE_ALWAYS; container.add_child(view)
	detail=Stage.new(); detail.hero_origin=Vector2(94,147); detail.arena_size=Vector2(210,245); view.add_child(detail)
	label("76px Xing Tian · 32px test enemies · no camera zoom",Vector2(40,659),13,Color("a5b3bc"))
	label("Same settings, timing and contact positions",Vector2(850,659),12,Color("a5b3bc"))
	title_label=label("",Vector2(40,690),17,Color("f1c18f"))
	status=label("",Vector2(700,690),14,Color("c2cdd4"))
	for i in 3: button(["3 simultaneous","6 staggered","6 dense"][i],Vector2(40+i*152,729),Vector2(143,32),func(): select_scenario(i))
	pause_button=button("Pause",Vector2(504,729),Vector2(89,32),func(): paused=not paused; pause_button.text="Resume" if paused else "Pause")
	button("Replay",Vector2(601,729),Vector2(89,32),replay)
	button("Clear",Vector2(698,729),Vector2(89,32),clear_all)
	speed_button=button("1x speed",Vector2(795,729),Vector2(98,32),func(): set_speed(.25 if speed==1 else 1.0))
	button("Mirror",Vector2(901,729),Vector2(89,32),func(): stage.set_facing(not stage.facing_left); detail.set_facing(stage.facing_left); seek_all(clock))
	blood_button=CheckBox.new(); blood_button.text="Blood"; blood_button.position=Vector2(1000,728); blood_button.button_pressed=true; add_child(blood_button); blood_button.toggled.connect(func(value:bool): stage.set_blood(value); detail.set_blood(value); seek_all(clock))
	button("Single hit",Vector2(1100,729),Vector2(130,32),func(): get_tree().change_scene_to_file("res://hit_preview.tscn"))
	time_label=label("",Vector2(40,773),12,Color("99a7b1"))
	timeline=HSlider.new(); timeline.position=Vector2(185,776); timeline.size=Vector2(260,14); timeline.max_value=3.6; timeline.step=1./120.; add_child(timeline)
	timeline.value_changed.connect(func(value:float): if not updating: paused=true; pause_button.text="Resume"; seek_all(value))
	label("Visual staging only. Scripted contacts, no combat integration, damage, knockback or attack animation.",Vector2(474,775),12,Color("7c8d99"))
	select_scenario(0)

func label(text_value:String,at:Vector2,size_value:int,color:Color)->Label:
	var node:=Label.new(); node.text=text_value; node.position=at; node.add_theme_font_size_override("font_size",size_value); node.add_theme_color_override("font_color",color); add_child(node); return node
func button(text_value:String,at:Vector2,size_value:Vector2,action:Callable)->Button:
	var node:=Button.new(); node.text=text_value; node.position=at; node.size=size_value; node.add_theme_font_size_override("font_size",13); node.pressed.connect(action); add_child(node); return node
func select_scenario(value:int)->void:
	scenario=clampi(value,0,2); stage.configure(scenario); detail.configure(scenario); replay()
func set_speed(value:float)->void:
	speed=value; speed_button.text="0.25x slow" if speed<1 else "1x speed"
func replay()->void:
	clock=0; paused=false; pause_button.text="Pause"; stage.restart(); detail.restart(); seek_all(0)
func clear_all()->void:
	paused=true; stage.clear(); detail.clear(); pause_button.text="Resume"; status.text="CLEARED · Replay to start"
func seek_all(value:float)->void:
	if stage.cleared: return
	clock=maxf(0,value); stage.seek(clock); detail.seek(clock)
	title_label.text=NAMES[scenario]
	status.text="%d active contact instances · %.2fx"%[stage.live_contacts(),speed]
	time_label.text="%.3f / 3.600s"%clock
	updating=true; timeline.value=minf(clock,3.6); updating=false
func _process(delta:float)->void:
	if movie:
		movie_clock+=delta; capture_frame+=1
		var section:=int(movie_clock/4.0)
		if section!=movie_section:
			movie_section=section
			select_scenario(mini(section,2)); set_speed(.25 if section==3 else 1.0)
		if capture_frame in [38,40,45,290,296,303,530,532,536,540,860,866,880,925]: capture.call_deferred(capture_frame)
		if capture_frame>=960: get_tree().quit()
	if not paused and not stage.cleared:
		var next:=clock+delta*speed
		if next>3.6: replay(); next=0
		seek_all(next)
func capture(frame:int)->void:
	await RenderingServer.frame_post_draw
	var folder:=OS.get_environment("XINGTIAN_CROWD_CAPTURE_DIR")
	if not folder.is_empty(): get_viewport().get_texture().get_image().save_png(folder.path_join("crowd-%04d.png"%frame))
func _draw()->void:
	draw_rect(Rect2(0,0,1280,800),Color("11171f"))
	for rect in [Rect2(28,117,760,558),Rect2(834,117,420,558)]: draw_rect(rect,Color("19232d")); draw_rect(rect,Color("35454f"),false)
