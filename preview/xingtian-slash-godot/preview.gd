extends Node2D
const Profile=preload("components/slash_profile.gd")
const Slash=preload("components/xingtian_slash.gd")
const Arc=preload("components/copper_arc.gd")
const Particles=preload("components/hit_particles.gd")
const Fixture=preload("fixture.gd")
@export var configuration:Resource=preload("presets/default.tres")
var profile=Profile.new()
var composed=Slash.new()
var native=Slash.new()
var arc_only=Arc.new()
var sparks_only=Particles.new()
var blood_only=Particles.new()
var fixture=Fixture.new()
var holder:Node2D
var elapsed:=0.0
var paused:=false
var loop:=true
var speed:=1.0
var hit_shown:=false
var light_background:=false
var cleared:=false
var updating:=false
var movie:=false
var movie_clock:=0.0
var movie_stage:=-1
var capture_frame:=0
var sliders:Dictionary={}
var toggles:Dictionary={}
var timeline:HSlider
var phase_label:Label
var time_label:Label
var scale_label:Label
var pause_button:Button
var speed_button:Button

func _ready() -> void:
	profile=(configuration if configuration is Profile else Profile.new()).sanitized()
	movie="--capture" in OS.get_cmdline_user_args()
	label("RAGECAT   /   SLASH REFERENCE STUDY",Vector2(36,20),13,Color("a98f7a"))
	label("XING TIAN  ·  COPPER CLEAVE",Vector2(36,43),30,Color("f1d4b7"))
	label("SpriteFusion-inspired sweep + echo + thread  /  copper palette  /  optional hit blood",Vector2(36,86),14,Color("92a0ac"))
	label("01   COMPOSED",Vector2(56,133),13,Color("c0a88e"))
	phase_label=label("",Vector2(534,133),13,Color("e7a67b"))
	holder=Node2D.new(); holder.position=Vector2(334,321); add_child(holder)
	holder.add_child(fixture); holder.add_child(composed)
	scale_label=label("3x art-pixel view",Vector2(56,462),12,Color("91a0ac"))
	label("Static neutral fixtures. The character does not swing.",Vector2(286,462),12,Color("71808e"))
	for i in range(4):
		label(["02   ARC ONLY / 1x","03   SPARKS ONLY","04   BLOOD ONLY","05   NATIVE 1x"][i],Vector2(52+i*191,530),12,Color("c0a88e"))
		var node:Node2D=[arc_only,sparks_only,blood_only,native][i]
		node.position=Vector2(99+i*191,626); node.scale=Vector2.ONE*(2.0 if i<3 else 1.0); add_child(node)
	blood_only.blood=true
	arc_only.position=Vector2(130,626); arc_only.scale=Vector2.ONE
	sparks_only.position=Vector2(328,626)
	blood_only.position=Vector2(520,626)
	native.position=Vector2(700,626)
	label("Isolated layers use the same settings and clock. No particles on a missed swing.",Vector2(56,710),12,Color("7b8996"))
	label("LAYERS",Vector2(866,132),13,Color("dfba98"))
	for i in range(3):
		var key:String=["arc","sparks","blood"][i]
		var toggle:=CheckBox.new(); toggle.text=["Copper arc","Dark sparks","Blood drops"][i]; toggle.position=Vector2(861,158+i*28); toggle.button_pressed=true; add_child(toggle); toggles[key]=toggle
		toggle.toggled.connect(func(value:bool): composed.set_layer_enabled(key,value); native.set_layer_enabled(key,value); [arc_only,sparks_only,blood_only][i].set_enabled(value))
	add_slider("radius","Visual range",20,88,1,257)
	add_slider("thickness","Arc thickness",4,28,1,311)
	add_slider("duration","Duration / s",0.12,0.6,0.01,365)
	add_slider("intensity","Intensity",0,1.5,0.05,419)
	add_slider("blood_count","Blood amount",0,20,1,473)
	pause_button=button("Pause",Vector2(866,545),Vector2(102,34),func(): paused=not paused; pause_button.text="Resume" if paused else "Pause")
	button("Replay",Vector2(976,545),Vector2(102,34),replay)
	button("Clear",Vector2(1086,545),Vector2(102,34),clear_all)
	speed_button=button("1x speed",Vector2(866,590),Vector2(102,34),func(): set_speed(0.25 if speed==1.0 else 1.0))
	button("Mirror",Vector2(976,590),Vector2(102,34),func(): profile.facing_left=not profile.facing_left; replay())
	button("BG",Vector2(1086,590),Vector2(102,34),func(): light_background=not light_background; queue_redraw())
	button("Default",Vector2(866,635),Vector2(157,34),func(): apply_preset("default"))
	button("Heavy",Vector2(1031,635),Vector2(157,34),func(): apply_preset("heavy"))
	label("Colors, roughness, seed, hit lifetime and\ndirection are editable in the profile Resource.",Vector2(866,693),13,Color("83919e"))
	time_label=label("",Vector2(36,740),13,Color("b9a898"))
	timeline=HSlider.new(); timeline.position=Vector2(340,744); timeline.size=Vector2(466,18); timeline.max_value=profile.preview_duration(); timeline.step=1./120.; add_child(timeline)
	timeline.value_changed.connect(func(value:float): if not updating: paused=true; pause_button.text="Resume"; seek_all(value))
	label("Visual prototype only  ·  no attack animation, damage, collision, camera shake or game integration",Vector2(36,779),12,Color("677785"))
	replay()

func label(value:String,at:Vector2,size_value:int,color:Color)->Label:
	var item:=Label.new(); item.text=value; item.position=at; item.add_theme_font_size_override("font_size",size_value); item.add_theme_color_override("font_color",color); add_child(item); return item

func button(value:String,at:Vector2,size_value:Vector2,action:Callable)->Button:
	var item:=Button.new(); item.text=value; item.position=at; item.size=size_value; item.add_theme_font_size_override("font_size",14); item.pressed.connect(action); add_child(item); return item

func add_slider(key:String,title:String,low:float,high:float,step_value:float,y:float)->void:
	var readout=label("%s   %s"%[title,str(profile.get(key))],Vector2(866,y),14,Color("a8b1ba"))
	var slider:=HSlider.new(); slider.position=Vector2(866,y+25); slider.size=Vector2(322,16); slider.min_value=low; slider.max_value=high; slider.step=step_value; slider.value=profile.get(key); add_child(slider); sliders[key]=slider
	slider.value_changed.connect(func(value:float): readout.text="%s   %s"%[title,str(value)]; if not updating: profile.set(key,value); rebuild(); seek_all(elapsed))

func set_speed(value:float)->void:
	speed=value; speed_button.text="%.2fx slow"%speed if speed<1 else "1x speed"

func apply_preset(name_value:String)->void:
	profile=load("res://presets/%s.tres"%name_value).sanitized()
	updating=true
	for key in sliders: sliders[key].value=profile.get(key)
	updating=false
	replay()

func rebuild()->void:
	var was_cleared:=cleared
	profile=profile.sanitized()
	updating=true
	for key in sliders: sliders[key].value=profile.get(key)
	updating=false
	composed.play(Vector2.ZERO,profile); native.play(Vector2.ZERO,profile)
	arc_only.play(arc_only.position,profile)
	sparks_only.play(sparks_only.position,profile); blood_only.play(blood_only.position,profile)
	for key in toggles:
		composed.set_layer_enabled(key,toggles[key].button_pressed)
		native.set_layer_enabled(key,toggles[key].button_pressed)
	fixture.target=profile.hit_position(); fixture.queue_redraw()
	# Integer zoom backs off for large/rotated arcs; no stretched art pixels.
	var zoom:=3 if profile.radius<=55 else 2
	holder.scale=Vector2.ONE*zoom; scale_label.text="%dx art-pixel view"%zoom
	blood_only.scale=Vector2.ONE*(2.0 if profile.blood_speed*profile.blood_duration<=50.0 else 1.0)
	hit_shown=false; cleared=false
	if was_cleared: clear_all()

func replay()->void:
	elapsed=0.0; paused=false; cleared=false; pause_button.text="Pause"; rebuild(); seek_all(0)

func clear_all()->void:
	paused=true; cleared=true; pause_button.text="Resume"
	for node in [composed,native,arc_only,sparks_only,blood_only]: node.clear()
	phase_label.text="CLEARED"; time_label.text="Clear. Replay to start again."

func seek_all(value:float)->void:
	if cleared: return
	elapsed=maxf(value,0)
	composed.arc.seek(elapsed); native.arc.seek(elapsed); arc_only.seek(elapsed)
	var hit_age:float=elapsed-profile.onset
	if hit_age>0:
		if not hit_shown:
			composed.play_hit(profile.hit_position(),profile); native.play_hit(profile.hit_position(),profile)
			sparks_only.play(sparks_only.position,profile); blood_only.play(blood_only.position,profile); hit_shown=true
		for node in [composed.impact,composed.sparks,composed.blood,native.impact,native.sparks,native.blood,sparks_only,blood_only]: node.seek(hit_age)
	else:
		for node in [composed.impact,composed.sparks,composed.blood,native.impact,native.sparks,native.blood,sparks_only,blood_only]: node.clear()
		hit_shown=false
	phase_label.text="CUT" if elapsed<profile.onset else ("HIT / FOLLOW-THROUGH" if elapsed<profile.duration else ("THREAD / DROPS SETTLE" if elapsed<profile.preview_duration() else "CLEAR"))
	time_label.text="%.3f s / %.3f s   ·   %.2fx"%[elapsed,profile.preview_duration(),speed]
	updating=true; timeline.max_value=profile.preview_duration(); timeline.value=minf(elapsed,timeline.max_value); updating=false

func _process(delta:float)->void:
	if movie:
		movie_clock+=delta; capture_frame+=1
		var stage:=int(movie_clock/3.0)
		if stage!=movie_stage:
			movie_stage=stage
			match stage:
				0: set_speed(1.0); replay()
				1: set_speed(0.25); replay()
				2: toggles.blood.button_pressed=false; set_speed(1.0); replay()
				3: toggles.blood.button_pressed=true; apply_preset("heavy"); set_speed(0.5)
		if capture_frame in [3,6,10,18,29,193,202,214,230,380,554,560,572,599]: save_frame.call_deferred(capture_frame)
		if movie_clock>=12.0: get_tree().quit()
	if not paused and not cleared:
		var next:=elapsed+delta*speed
		if loop and next>profile.preview_duration()+0.48: replay(); next=0.0
		seek_all(next)

func save_frame(frame:int)->void:
	await RenderingServer.frame_post_draw
	var folder:=OS.get_environment("XINGTIAN_CAPTURE_DIR")
	if not folder.is_empty(): get_viewport().get_texture().get_image().save_png(folder.path_join("slash-%04d.png"%frame))

func _draw()->void:
	draw_rect(Rect2(0,0,1280,800),Color("11171f"))
	var bg:=Color("38414b") if light_background else Color("1b252f")
	for rect in [Rect2(36,120,770,377),Rect2(36,515,770,215),Rect2(842,120,402,617)]:
		draw_rect(rect,bg if rect.position.x<800 else Color("171f29")); draw_rect(rect,Color("33404b"),false)
	for x in range(56,790,24):
		for y in range(178,452,24): draw_rect(Rect2(x,y,2,1),Color("2d3944"))
	for x in [227,418,609]: draw_line(Vector2(x,560),Vector2(x,690),Color("323b46"))
