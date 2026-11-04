extends Node2D
const Profile = preload("components/lava_profile.gd")
const Solar = preload("components/solar_lava.gd")
const Surface = preload("components/lava_surface.gd")
const Bubbles = preload("components/lava_bubbles.gd")
const Flames = preload("components/short_flames.gd")
const Smoke = preload("components/rising_smoke.gd")
const Sparks = preload("components/impact_sparks.gd")
@export var configuration: Resource = preload("presets/default.tres")
var profile=Profile.new()
var composed
var solos: Array=[]
var elapsed:=0.0
var paused:=false
var light_background:=false
var movie:=false
var movie_clock:=0.0
var capture_frame:=0
var phase_label: Label
var time_label: Label
var pause_button: Button
var sliders: Dictionary={}
var toggles: Dictionary={}
var timeline: HSlider
var _updating:=false

func _ready() -> void:
	profile=(configuration if configuration is Profile else Profile.new()).sanitized()
	movie=OS.has_feature("movie") or "--capture" in OS.get_cmdline_user_args()
	get_window().size=Vector2i(1280,800)
	get_window().content_scale_size=Vector2i(1280,800)
	label("RAGECAT   /   ORIGINAL VFX STUDY",Vector2(36,22),14,Color("ab9a89"))
	label("HOU YI  ·  SOLAR LAVA",Vector2(36,44),30,Color("f5dac0"))
	label("Ground fracture  /  slow molten flow  /  sparse bubbles",Vector2(36,84),15,Color("8b9aa8"))
	label("01   COMPOSED",Vector2(56,130),13,Color("b7aaa0"))
	phase_label=label("",Vector2(570,130),13,Color("edac68"))
	label("3× native pixel view  ·  character & warning stay above the ground layer",Vector2(56,451),13,Color("8b9aa8"))
	var container:=Node2D.new(); container.position=Vector2(425,290); container.scale=Vector2(3,3); add_child(container)
	composed=Solar.new(); container.add_child(composed)
	# Deliberately static silhouettes, not attack animations or gameplay actors.
	var fixture:=Node2D.new(); fixture.set_script(preload("readability_fixture.gd")); fixture.z_index=10; container.add_child(fixture)
	for i in range(5):
		label(["02   LAVA", "03   BUBBLES", "04   FLAMES", "05   SPARKS", "06   SMOKE"][i],Vector2(50+i*154,498),12,Color("c8b7a2"))
		var holder:=Node2D.new(); holder.position=Vector2(112+i*154,594); holder.scale=Vector2(2,2); add_child(holder)
		var node=[Surface,Bubbles,Flames,Sparks,Smoke][i].new(); holder.add_child(node); solos.append(node)
		label(["Flow + cooling crust","Rise / burst / ripple","Low heat vents","Only at impact", "Low-opacity rise"][i],Vector2(50+i*154,663),12,Color("84909c"))
	label("2× isolated components · fixed sample area",Vector2(50,697),10,Color("687888"))
	label("COMPONENTS",Vector2(865,130),13,Color("e6c29c"))
	for i in range(5):
		var key: String=["lava","bubbles","flames","sparks","smoke"][i]
		var toggle:=CheckBox.new(); toggle.text=["Lava surface","Bubbles","Short flames","Impact sparks","Rising smoke"][i]; toggle.button_pressed=true; toggle.position=Vector2(862+(i%2)*180,158+int(i/2)*28); add_child(toggle)
		toggle.toggled.connect(func(value: bool): composed.set_layer_enabled(key,value))
		toggles[key]=toggle
	label("VISUAL PARAMETERS",Vector2(865,245),13,Color("e6c29c"))
	add_slider("radius","Area radius",16,84,1,278)
	add_slider("flow_speed","Flow speed",0,1,0.01,333)
	add_slider("bubble_count","Bubble density",0,24,1,388)
	add_slider("flame_count","Flame density",0,16,1,443)
	add_slider("hold_time","Hold duration",0.5,12,0.1,498)
	pause_button=button("Pause",Vector2(865,579),Vector2(100,34),func(): paused=not paused; pause_button.text="Resume" if paused else "Pause")
	button("Replay",Vector2(976,579),Vector2(100,34),replay)
	button("Clear",Vector2(1087,579),Vector2(100,34),clear_all)
	button("Small",Vector2(865,624),Vector2(100,34),func(): set_radius(36.))
	button("Grown",Vector2(976,624),Vector2(100,34),func(): set_radius(84.))
	button("BG",Vector2(1087,624),Vector2(100,34),func(): light_background=not light_background; queue_redraw())
	label("Growth changes area and detail count.\nIt never raises brightness or flame height.",Vector2(865,684),13,Color("9ca7b2"))
	time_label=label("",Vector2(36,714),14,Color("c7b6a7"))
	timeline=HSlider.new(); timeline.position=Vector2(36,746); timeline.size=Vector2(770,20); timeline.min_value=0; timeline.max_value=profile.total_time(); timeline.step=1./60.; add_child(timeline)
	timeline.value_changed.connect(func(value:float): if not _updating: paused=true; pause_button.text="Resume"; elapsed=value; seek_all(value))
	label("Standalone visual study  ·  no attack animation, damage, collision or balance changes",Vector2(36,778),12,Color("6d7c8a"))
	replay()

func label(text_value:String,pos:Vector2,font_size:int,color:Color) -> Label:
	var item:=Label.new(); item.text=text_value; item.position=pos; item.add_theme_font_size_override("font_size",font_size); item.add_theme_color_override("font_color",color); add_child(item); return item

func button(text_value:String,pos:Vector2,size_value:Vector2,action:Callable) -> Button:
	var item:=Button.new(); item.text=text_value; item.position=pos; item.size=size_value; item.add_theme_font_size_override("font_size",14); item.pressed.connect(action); add_child(item); return item

func add_slider(key:String,title:String,low:float,high:float,step_value:float,y:float) -> void:
	var readout=label("",Vector2(865,y),14,Color("a8b3bd"))
	var slider:=HSlider.new(); slider.position=Vector2(865,y+25); slider.size=Vector2(320,16); slider.min_value=low; slider.max_value=high; slider.step=step_value; slider.value=profile.get(key); add_child(slider); sliders[key]=slider
	readout.text="%s    %s" % [title,str(slider.value)]
	slider.value_changed.connect(func(value:float): profile.set(key,value); readout.text="%s    %s"%[title,str(value)]; rebuild())

func rebuild() -> void:
	composed.play(Vector2.ZERO,profile)
	for key in toggles: composed.set_layer_enabled(key,toggles[key].button_pressed)
	var isolated_profile=profile.duplicate(); isolated_profile.radius=34.0
	for node in solos: node.play(Vector2.ZERO,isolated_profile)
	seek_all(minf(elapsed,profile.total_time()))

func set_radius(value:float) -> void:
	sliders.radius.value=value
	replay()

func replay() -> void:
	elapsed=0.; paused=false; pause_button.text="Pause"; rebuild()

func clear_all() -> void:
	paused=true; pause_button.text="Resume"; composed.clear()
	for node in solos: node.clear()
	phase_label.text="CLEARED"; time_label.text="All components cleared. Replay to restart."

func seek_all(value:float) -> void:
	composed.seek(value)
	for node in solos: node.seek(value)
	var phase: String="IMPACT / OPENING" if value<profile.opening_time else ("SLOW FLOW" if value<profile.opening_time+profile.hold_time else ("COOLING" if value<profile.total_time()-profile.fade_time else "FADING"))
	phase_label.text=phase
	time_label.text="%05.2f s / %.2f s   ·   drag to inspect any frame" % [value,profile.total_time()]
	_updating=true; timeline.max_value=profile.total_time(); timeline.value=value; _updating=false

func _process(delta:float) -> void:
	if movie:
		movie_clock+=delta
		if movie_clock>7.2 and profile.radius<80: set_radius(84.)
		capture_frame+=1
		if capture_frame in [18,90,275,335,520,740]:
			_save_frame.call_deferred(capture_frame)
		if movie_clock>=14.: get_tree().quit()
	if not paused:
		elapsed+=delta
		if elapsed>profile.total_time()+0.6: elapsed=0.
		seek_all(elapsed)

func _save_frame(frame:int) -> void:
	await RenderingServer.frame_post_draw
	var destination:=OS.get_environment("SOLAR_CAPTURE_DIR")
	if destination.is_empty(): return
	get_viewport().get_texture().get_image().save_png(destination.path_join("solar-%04d.png"%frame))

func _draw() -> void:
	draw_rect(Rect2(0,0,1280,800),Color("10151d"))
	var bg:=Color("39434a") if light_background else Color("1a222b")
	for rect in [Rect2(36,116,770,355),Rect2(36,484,770,210),Rect2(842,116,402,620)]:
		draw_rect(rect,bg if rect.position.x<800 else Color("151d26")); draw_rect(rect,Color("303a45"),false,1.)
	for y in range(176,420,20):
		for x in range(56,790,20):
			var h:=posmod(x*13+y*7,41)
			draw_rect(Rect2(x,y,2,1),Color("37404a") if h<9 else Color("242e39"))
	for x in [190,344,498,652]: draw_line(Vector2(x,530),Vector2(x,647),Color("2e3743"),1.)
