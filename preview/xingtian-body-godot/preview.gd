extends Node2D
const Body = preload("components/body_state.gd")
const Profile = preload("components/body_profile.gd")
var actor
var detail
var settings = Profile.new()
var age: float = 0.0
var automatic: bool = true
var paused: bool = false
var cleared: bool = false
var light_background: bool = false
var state_slider: HSlider
var timeline: HSlider
var amount_label: Label
var phase_label: Label
var time_label: Label
var pause_button: Button
var capture_mode: bool = false
var frames: int = 0
var panel_labels: Array[Label] = []
const LENGTH: float = 12.0

func _ready() -> void:
	get_viewport().size = Vector2i(1280,800)
	get_window().content_scale_size = Vector2i(1280,800)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	capture_mode = "--capture" in OS.get_cmdline_user_args()
	actor = Body.new(); actor.position = Vector2(312,394); actor.scale = Vector2.ONE*0.21875; add_child(actor)
	var inset = SubViewportContainer.new(); inset.position = Vector2(660,158); inset.size = Vector2(568,330); inset.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(inset)
	var view = SubViewport.new(); view.size = Vector2i(568,330); view.transparent_bg = true; view.render_target_update_mode = SubViewport.UPDATE_ALWAYS; inset.add_child(view)
	detail = Body.new(); detail.scale = Vector2.ONE*0.5; detail.position = Vector2(238,260); view.add_child(detail)
	_label("XING TIAN", Vector2(38,24), 30, Color("f2e7dc"))
	_label("BODY STUDY  /  MOMENTUM", Vector2(38,64), 14, Color("a9928e"))
	_label("01",Vector2(583,28),30,Color("c54a54"))
	_label("PORTRAIT / STATIC POSE",Vector2(40,103),12,Color("7f8c9e"))
	_label("ARMOR SEAMS + SHOULDER FLOW",Vector2(680,119),14,Color("e0b6b4"))
	_label("Original alpha kept. No floor aura. No attack animation.",Vector2(680,495),13,Color("8190a3"))
	phase_label = _label("NORMAL",Vector2(42,622),24,Color("edb4b1"))
	amount_label = _label("00%",Vector2(482,622),24,Color("edb4b1"))
	_label("DISPLAY AMOUNT",Vector2(44,662),11,Color("8390a3"))
	state_slider = _slider(Vector2(184,658),Vector2(385,22),0,1,0.01,0)
	state_slider.value_changed.connect(func(v):
		automatic=false
		if not cleared:
			_apply(v)
			time_label.text="Flow clock  %.2f s" % actor.elapsed
	)
	_button("Normal",Vector2(675,538),Vector2(100,34),func(): _manual(0.0))
	_button("Build",Vector2(785,538),Vector2(100,34),func(): _start_cycle(1.0))
	_button("Full",Vector2(895,538),Vector2(100,34),func(): _manual(1.0))
	_button("Decay",Vector2(1005,538),Vector2(100,34),func(): _start_cycle(7.0))
	_button("Clear",Vector2(1115,538),Vector2(100,34),_clear)
	_labeled_slider("Intensity",Vector2(675,589),0,1.5,0.05,1.0,func(v): settings.intensity=v; _configure())
	_labeled_slider("Local glow",Vector2(965,589),0,0.6,0.02,0.24,func(v): settings.local_glow=v; _configure())
	_labeled_slider("Flow speed",Vector2(675,634),0,3,0.1,0.7,func(v): settings.flow_speed=v; _configure())
	var flow = CheckButton.new(); flow.position=Vector2(965,626); flow.text="Shoulder flow"; flow.button_pressed=true; flow.toggled.connect(func(v): settings.flow_enabled=v; _configure()); add_child(flow)
	_button("Replay",Vector2(38,723),Vector2(100,36),func(): _start_cycle(0))
	pause_button = _button("Pause",Vector2(148,723),Vector2(100,36),func(): paused=not paused; pause_button.text="Resume" if paused else "Pause")
	timeline = _slider(Vector2(274,730),Vector2(633,22),0,LENGTH,0.01,0)
	timeline.value_changed.connect(func(v):
		age=v; paused=true; automatic=true; pause_button.text="Resume"
		if not cleared: _sample()
	)
	time_label = _label("0.00 / 12.00 s",Vector2(922,732),14,Color("a1adbd"))
	_button("BG",Vector2(1102,723),Vector2(58,36),_toggle_background)
	_button("Reset",Vector2(1170,723),Vector2(72,36),func(): get_tree().reload_current_scene())
	_configure(); _sample()

func _process(delta: float) -> void:
	if capture_mode: delta=1.0/60.0
	if not paused and not cleared:
		if automatic:
			age=minf(age+delta,LENGTH)
			_sample()
		else:
			actor.advance(delta); detail.seek(actor.elapsed)
			time_label.text="Flow clock  %.2f s" % actor.elapsed
	if capture_mode:
		frames+=1
		if frames>=780: get_tree().quit()

func _sample() -> void:
	if cleared: return
	_apply(sample_amount(age))
	actor.seek(age); detail.seek(age)
	timeline.set_value_no_signal(age)
	time_label.text="%.2f / 12.00 s" % age
	phase_label.text = "NORMAL" if age<1.0 or age>=11.0 else "ACCUMULATING" if age<5.0 else "FULL MOMENTUM" if age<7.0 else "DECAYING"

static func sample_amount(t: float) -> float:
	if not is_finite(t) or t<=1.0 or t>=11.0: return 0.0
	if t<5.0: return smoothstep(0.0,1.0,(t-1.0)/4.0)
	if t<7.0: return 1.0
	return 1.0-smoothstep(0.0,1.0,(t-7.0)/4.0)

func _apply(v: float) -> void:
	actor.set_amount(v); detail.set_amount(v)
	state_slider.set_value_no_signal(v)
	amount_label.text="%02d%%" % roundi(v*100.0)
	if not automatic: phase_label.text="NORMAL" if v<=0 else "FULL MOMENTUM" if v>=1 else "MANUAL AMOUNT"

func _manual(v: float) -> void:
	cleared=false; automatic=false; paused=false; age=0.0; timeline.set_value_no_signal(0); pause_button.text="Pause"
	actor.start(v); detail.start(v); _apply(v); time_label.text="Flow clock  0.00 s"

func _start_cycle(t: float) -> void:
	cleared=false; automatic=true; paused=false; age=t; pause_button.text="Pause"
	actor.start(); detail.start(); _sample()

func _clear() -> void:
	cleared=true; actor.clear(); detail.clear(); amount_label.text="00%"; phase_label.text="CLEARED"; state_slider.set_value_no_signal(0); time_label.text="Cleared / Replay"

func _configure() -> void:
	actor.configure(settings); detail.configure(settings)

func _label(text_value: String, at: Vector2, font_size: int, color: Color) -> Label:
	var label=Label.new(); label.text=text_value; label.position=at; label.add_theme_font_size_override("font_size",font_size); label.add_theme_color_override("font_color",color); add_child(label)
	if (at.x<626 and at.y>94 and at.y<699) or (at.x>650 and at.y>106 and at.y<523):
		label.set_meta("dark_color",color); panel_labels.append(label)
	return label

func _toggle_background() -> void:
	light_background=not light_background
	for label in panel_labels:
		label.add_theme_color_override("font_color",Color("313b4b") if light_background else label.get_meta("dark_color"))
	queue_redraw()

func _button(text_value: String, at: Vector2, dimensions: Vector2, callback: Callable) -> Button:
	var button=Button.new(); button.text=text_value; button.position=at; button.size=dimensions; button.pressed.connect(callback); add_child(button); return button

func _slider(at: Vector2, dimensions: Vector2, lo: float, hi: float, step_value: float, current: float) -> HSlider:
	var slider=HSlider.new(); slider.position=at; slider.size=dimensions; slider.min_value=lo; slider.max_value=hi; slider.step=step_value; slider.value=current; add_child(slider); return slider

func _labeled_slider(text_value: String, at: Vector2, lo: float, hi: float, step_value: float, current: float, callback: Callable) -> void:
	_label(text_value,at,13,Color("b8bec9"))
	var slider=_slider(at+Vector2(104,0),Vector2(140,22),lo,hi,step_value,current)
	slider.value_changed.connect(callback)

func _draw() -> void:
	var field=Color("bdc2c6") if light_background else Color("0f1520")
	draw_rect(Rect2(24,94,602,605),field)
	draw_rect(Rect2(650,106,588,417),field)
	draw_rect(Rect2(24,94,602,605),Color("303847"),false)
	draw_rect(Rect2(650,106,588,417),Color("303847"),false)
	draw_line(Vector2(24,710),Vector2(1250,710),Color("38404b"))
