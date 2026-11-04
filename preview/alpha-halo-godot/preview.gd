extends Node2D
const Halo=preload("components/alpha_halo.gd")
const Profile=preload("components/halo_profile.gd")
const XING=preload("assets/xing_tian.png")
const HOU=preload("assets/hou_yi.png")
const LENGTH: float=12.0
var settings=Profile.new()
var age: float=0.0
var paused: bool=false
var automatic: bool=true
var cleared: bool=false
var light_background: bool=false
var capture_mode: bool=false
var frames: int=0
var actors: Array=[]
var baselines: Array=[]
var swap_actor
var swap_index: int=-1
var phase_label: Label
var amount_label: Label
var time_label: Label
var state_slider: HSlider
var timeline: HSlider
var pause_button: Button
var movement: bool=true
var crops: Array[Rect2]=[]
var panel_labels: Array[Label]=[]

func _ready() -> void:
	get_window().content_scale_size=Vector2i(1280,800)
	get_window().content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	capture_mode="--capture" in OS.get_cmdline_user_args()
	# Used once for this fixture's visual framing, never for the glow algorithm.
	# Production animation hosts retain a stable frame rectangle/anchor instead.
	crops=[Rect2(XING.get_image().get_used_rect()),Rect2(HOU.get_image().get_used_rect())]
	_label("ADAPTIVE ALPHA HALO",Vector2(28,22),28,Color("f3e8dd"))
	_label("Soft exterior light / no floor effect / no image-specific markings",Vector2(30,62),14,Color("a9b6bd"))
	_label("02",Vector2(1190,24),30,Color("e39380"))
	for i in 2:
		var x: float=24+i*410
		_label(("XING TIAN" if i==0 else "HOU YI")+"   /   4x DETAIL",Vector2(x+16,108),14,Color("e2c5b7"),true)
		var box=SubViewportContainer.new(); box.position=Vector2(x,142); box.size=Vector2(96,104); box.scale=Vector2.ONE*4; box.mouse_filter=Control.MOUSE_FILTER_IGNORE; box.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST; add_child(box)
		var display_material=CanvasItemMaterial.new(); display_material.blend_mode=CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA; box.material=display_material
		var view=SubViewport.new(); view.size=Vector2i(96,104); view.transparent_bg=true; view.render_target_update_mode=SubViewport.UPDATE_ALWAYS; box.add_child(view)
		var actor=Halo.new(); actor.position=Vector2(48,52); view.add_child(actor); _frame(actor,i); actors.append(actor)
	_label("ACTUAL GAME SIZE / 76 px",Vector2(866,108),14,Color("e2c5b7"),true)
	_label("NORMAL",Vector2(888,160),12,Color("9aaebb"),true)
	_label("BUFF",Vector2(1116,160),12,Color("e8a694"),true)
	for i in 2:
		var y: float=239+i*123
		var base=Halo.new(); base.position=Vector2(918,y); add_child(base); _frame(base,i); base.start(0); baselines.append(base)
		var actor=Halo.new(); actor.position=Vector2(1148,y); add_child(actor); _frame(actor,i); actor.set_meta("home",actor.position); actors.append(actor)
	_label("Xing Tian",Vector2(876,287),12,Color("aebac5"),true)
	_label("Hou Yi",Vector2(884,410),12,Color("aebac5"),true)
	_label("SAME INSTANCE / FRAME SWAP",Vector2(866,447),12,Color("aebac5"),true)
	swap_actor=Halo.new(); swap_actor.position=Vector2(1050,508); add_child(swap_actor); _frame(swap_actor,0); actors.append(swap_actor)
	phase_label=_label("NORMAL",Vector2(32,593),21,Color("efb39c"))
	amount_label=_label("00%",Vector2(365,593),21,Color("efb39c"))
	_label("AMOUNT",Vector2(34,639),12,Color("96a7b3"))
	state_slider=_slider(Vector2(106,635),Vector2(285,24),0,1,0.01,0)
	state_slider.value_changed.connect(func(v): automatic=false; _apply(v))
	_button("Normal",Vector2(456,592),Vector2(92,32),func(): _manual(0))
	_button("Build",Vector2(556,592),Vector2(92,32),func(): _cycle(1))
	_button("Full",Vector2(656,592),Vector2(92,32),func(): _manual(1))
	_button("Decay",Vector2(756,592),Vector2(92,32),func(): _cycle(7))
	_button("Clear",Vector2(856,592),Vector2(92,32),_clear)
	_label("COLOR",Vector2(981,600),12,Color("96a7b3"))
	var color=ColorPickerButton.new(); color.position=Vector2(1042,592); color.size=Vector2(74,32); color.color=settings.color; color.edit_alpha=false; color.color_changed.connect(func(v): settings.color=v; _configure()); add_child(color)
	_button("BG",Vector2(1131,592),Vector2(62,32),func(): light_background=not light_background; _theme(); queue_redraw())
	_labeled_slider("Intensity",Vector2(456,642),0,1,0.02,settings.intensity,func(v): settings.intensity=v; _configure())
	_labeled_slider("Width / px",Vector2(734,642),0.5,8,0.1,settings.width,func(v): settings.width=v; _configure())
	var move=CheckButton.new(); move.position=Vector2(1022,635); move.text="Follow / flip"; move.button_pressed=true; move.toggled.connect(func(v): movement=v; _motion()); add_child(move)
	_button("Replay",Vector2(30,724),Vector2(100,36),func(): _cycle(0))
	pause_button=_button("Pause",Vector2(142,724),Vector2(100,36),func(): paused=not paused; pause_button.text="Resume" if paused else "Pause")
	timeline=_slider(Vector2(270,731),Vector2(660,22),0,LENGTH,0.01,0)
	timeline.value_changed.connect(func(v): age=v; paused=true; automatic=true; pause_button.text="Resume"; _sample())
	time_label=_label("0.00 / 12.00 s",Vector2(958,731),14,Color("b7c1cb"))
	_button("Reset",Vector2(1158,724),Vector2(84,36),func(): get_tree().reload_current_scene())
	_label("Same shader on both portraits. Texture alpha drives the light; source art stays unchanged.",Vector2(30,684),13,Color("7f94a4"))
	_configure(); _sample()

func _frame(actor, index: int) -> void:
	var crop: Rect2=crops[index]
	actor.set_frame(XING if index==0 else HOU,crop,Vector2(crop.size.x/crop.size.y*76.0,76))

func _process(delta: float) -> void:
	if capture_mode: delta=1.0/60.0
	if not paused and not cleared:
		age=minf(age+delta,LENGTH) if automatic else age+delta
		if automatic: _sample()
		else:
			for actor in actors: actor.seek(age)
			_motion()
			time_label.text="Clock %.2f s"%age
	if capture_mode:
		frames+=1
		if frames>=780: get_tree().quit()

func _sample() -> void:
	if cleared: return
	_apply(sample_amount(age))
	for actor in actors: actor.seek(age)
	timeline.set_value_no_signal(age); time_label.text="%.2f / 12.00 s"%age
	phase_label.text="NORMAL" if age<1 or age>=11 else "ACCUMULATING" if age<5 else "FULL MOMENTUM" if age<7 else "DECAYING"
	_motion()
static func sample_amount(t: float) -> float:
	if not is_finite(t) or t<=1 or t>=11: return 0
	if t<5: return smoothstep(0,1,(t-1)/4)
	if t<7: return 1
	return 1-smoothstep(0,1,(t-7)/4)
func _motion() -> void:
	for actor in actors:
		if actor.has_meta("home"):
			actor.position=actor.get_meta("home")+Vector2(sin(age*0.9)*14,0) if movement else actor.get_meta("home")
			actor.set_flip(movement and sin(age*0.9)<-0.6)
	var index: int=int(age/2.0)%2
	if index!=swap_index: _frame(swap_actor,index); swap_index=index
func _apply(value: float) -> void:
	if cleared: return
	for actor in actors: actor.set_amount(value)
	state_slider.set_value_no_signal(value); amount_label.text="%02d%%"%roundi(value*100)
	if not automatic: phase_label.text="NORMAL" if value<=0 else "FULL MOMENTUM" if value>=1 else "MANUAL AMOUNT"
func _manual(value: float) -> void:
	cleared=false; automatic=false; paused=false; age=0; pause_button.text="Pause"; timeline.set_value_no_signal(0)
	for actor in actors: actor.start(value)
	_apply(value); _motion()
func _cycle(t: float) -> void:
	cleared=false; automatic=true; paused=false; age=t; pause_button.text="Pause"
	for actor in actors: actor.start()
	_sample()
func _clear() -> void:
	cleared=true
	for actor in actors: actor.clear()
	amount_label.text="00%"; phase_label.text="CLEARED"; state_slider.set_value_no_signal(0); time_label.text="Cleared / Replay"
func _configure() -> void:
	for actor in actors: actor.configure(settings)
func _label(value: String, at: Vector2, font_size: int, color: Color, panel: bool=false) -> Label:
	var label=Label.new(); label.text=value; label.position=at; label.add_theme_font_size_override("font_size",font_size); label.add_theme_color_override("font_color",color); add_child(label)
	if panel: label.set_meta("dark_color",color); panel_labels.append(label)
	return label
func _theme() -> void:
	for label in panel_labels: label.add_theme_color_override("font_color",Color("263d44") if light_background else label.get_meta("dark_color"))
func _button(value: String, at: Vector2, dimensions: Vector2, callback: Callable) -> Button:
	var button=Button.new(); button.text=value; button.position=at; button.size=dimensions; button.pressed.connect(callback); add_child(button); return button
func _slider(at: Vector2, dimensions: Vector2, lo: float, hi: float, step_value: float, current: float) -> HSlider:
	var slider=HSlider.new(); slider.position=at; slider.size=dimensions; slider.min_value=lo; slider.max_value=hi; slider.step=step_value; slider.value=current; add_child(slider); return slider
func _labeled_slider(value: String, at: Vector2, lo: float, hi: float, step_value: float, current: float, callback: Callable) -> void:
	_label(value,at,13,Color("b4c0c9")); var slider=_slider(at+Vector2(92,0),Vector2(150,22),lo,hi,step_value,current); slider.value_changed.connect(callback)
func _draw() -> void:
	var field=Color("b8c9cc") if light_background else Color("102936")
	for rect in [Rect2(24,96,384,475),Rect2(434,96,384,475),Rect2(844,96,412,475)]:
		draw_rect(rect,field); draw_rect(rect,Color("37616b"),false)
		for x in range(int(rect.position.x)+24,int(rect.end.x),48): draw_line(Vector2(x,rect.position.y+48),Vector2(x,rect.end.y),Color(0.2,0.4,0.45,0.14))
		for y in range(int(rect.position.y)+48,int(rect.end.y),48): draw_line(Vector2(rect.position.x,y),Vector2(rect.end.x,y),Color(0.2,0.4,0.45,0.14))
	draw_line(Vector2(24,710),Vector2(1256,710),Color("384650"))
