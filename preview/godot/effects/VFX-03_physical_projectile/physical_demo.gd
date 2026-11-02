extends Node2D
const History = preload("res://effects/VFX-03_physical_projectile/path_history.gd")
const View = preload("res://effects/VFX-03_physical_projectile/physical_view.gd")
const STEP := 1.0/120.0
var history := History.new()
var actual: Node2D
var detail: Node2D
var data: Dictionary
var sliders := {}
var labels := {}
var speed := 180.0
var heading := 0.0
var world := Vector2.ZERO
var paused := false
var tracking := false
var turning := false
var stopped := false
var looping := true
var show_trail := true
var accumulator := 0.0
var cycle_time := 0.0
var demo_time := 0.0
var auto_demo := false
var stage := -1
var background := 0
var status: Label
var scene_label: Label
var pause_button: Button
var track_button: Button
var turn_button: Button
var loop_button: Button
var trail_button: Button
var preset: OptionButton

func _ready() -> void:
	data=JSON.parse_string(FileAccess.get_file_as_string("res://effects/VFX-03_physical_projectile/presets.json"))
	auto_demo="--physical-auto" in OS.get_cmdline_user_args()
	actual=View.new(); actual.state=history; actual.anchor=Vector2(170,140)
	add_view(actual,Rect2(20,106,310,77))
	detail=View.new(); detail.state=history; detail.anchor=Vector2(258,273); detail.display_scale=3.0
	add_view(detail,Rect2(20,216,310,111))
	make_ui()
	reset_all()
func add_view(view: Node2D, rect: Rect2) -> void:
	var clip := Control.new()
	clip.position=rect.position; clip.size=rect.size; clip.clip_contents=true; clip.mouse_filter=Control.MOUSE_FILTER_IGNORE
	view.anchor-=rect.position
	add_child(clip); clip.add_child(view)
func label_at(text: String,p: Vector2,size: int=11,color: Color=Color("dce3e7")) -> Label:
	var n:=Label.new();n.text=text;n.position=p;n.add_theme_font_size_override("font_size",size);n.add_theme_color_override("font_color",color);n.set_meta("color",color);add_child(n);return n
func button_at(text: String,x: float,y: float,w: float,action: Callable) -> Button:
	var b:=Button.new();b.text=text;b.position=Vector2(x,y);b.size=Vector2(w,25);b.add_theme_font_size_override("font_size",11);b.pressed.connect(action);add_child(b);return b
func slider_at(key: String,y: float,low: float,high: float,step: float,value: float) -> void:
	labels[key]=label_at("",Vector2(350,y))
	var slider:=HSlider.new();slider.position=Vector2(485,y+1);slider.size=Vector2(133,18);slider.min_value=low;slider.max_value=high;slider.step=step;slider.value=value
	slider.value_changed.connect(func(v: float):
		if key=="speed": speed=v
		else: history.configure({key:v})
		update_labels())
	add_child(slider);sliders[key]=slider
func make_ui() -> void:
	label_at("03B / PHYSICAL PROJECTILE",Vector2(20,12),17,Color("e2ebed"))
	label_at("Arrow + throwing knife. Independent path trail.",Vector2(20,39),11,Color("9aadb8"))
	scene_label=label_at("",Vector2(20,78),11,Color("9aadb8"))
	label_at("TRACKING CAMERA / 3x NEAREST",Vector2(20,196),11,Color("9aadb8"))
	label_at("TRAIL PARAMETERS",Vector2(350,65),12)
	pause_button=button_at("Pause",350,14,60,toggle_pause)
	button_at("+ Frame",416,14,70,step_frame)
	button_at("Reset",492,14,60,reset_all)
	button_at("Replay",558,14,62,restart)
	slider_at("speed",94,0,360,10,180)
	slider_at("trail_width",120,0.5,6,0.1,2.4)
	slider_at("length_max",146,8,64,1,34)
	slider_at("history_seconds",172,0.02,0.6,0.01,0.2)
	slider_at("taper",198,0.25,3,0.05,0.75)
	slider_at("speed_response",224,0.01,0.3,0.005,0.05)
	slider_at("body_scale",250,0.5,2,0.1,1)
	track_button=button_at("Track",350,280,60,func():tracking=not tracking)
	turn_button=button_at("Turn",416,280,60,func():turning=not turning)
	button_at("Stop",482,280,60,func():stopped=true;history.stop())
	button_at("Teleport",548,280,72,teleport)
	preset=OptionButton.new();preset.position=Vector2(350,311);preset.size=Vector2(135,26);preset.add_theme_font_size_override("font_size",10)
	for item in data.presets: preset.add_item(item.label)
	preset.item_selected.connect(func(i):apply_preset(i);restart())
	add_child(preset)
	button_at("BG",491,311,32,cycle_background)
	trail_button=button_at("Trail on",529,311,52,func():show_trail=not show_trail)
	loop_button=button_at("Loop",587,311,34,func():looping=not looping)
	status=label_at("",Vector2(20,335),10,Color("9aadb8"))
func update_labels() -> void:
	var names:={"speed":"Speed / px/s","trail_width":"Width / px","length_max":"Max length / px","history_seconds":"History / s","taper":"Taper","speed_response":"Response / s","body_scale":"Body scale"}
	for key in sliders:
		var value:float=speed if key=="speed" else history.get(key)
		labels[key].text="%s  %s"%[names[key],str(snappedf(value,0.005))]
		sliders[key].set_value_no_signal(value)
func apply_preset(i:int) -> void:
	var values:Dictionary=data.defaults.duplicate();values.merge(data.presets[i].overrides,true)
	history.configure(values);update_labels();preset.select(i)
func restart() -> void:
	world=Vector2(-118,0);heading=0.0;cycle_time=0.0;stopped=false
	history.reset(world,Vector2(speed,0));history.paused=paused
	sync_views()
func reset_all() -> void:
	paused=false;tracking=false;turning=false;stopped=false;looping=true;show_trail=true;speed=180;accumulator=0.0
	background=0;set_background();pause_button.text="Pause";apply_preset(0);restart()
func toggle_pause() -> void:
	paused=not paused;history.paused=paused;pause_button.text="Play" if paused else "Pause"
func step_frame() -> void:
	paused=true;history.paused=false
	for i in range(2): simulate(STEP)
	history.paused=true;pause_button.text="Play";sync_views()
func teleport() -> void:
	world+=Vector2(130,-12);history.tick(STEP,world,Vector2.from_angle(heading)*speed);sync_views()
func cycle_background() -> void:
	background=(background+1)%3;set_background()
func set_background() -> void:
	RenderingServer.set_default_clear_color([Color("20262b"),Color("080c11"),Color("eeeeec")][background])
	for child in get_children():
		if child is Label: child.add_theme_color_override("font_color",Color("273840") if background==2 else child.get_meta("color",Color.WHITE))
func _process(delta:float) -> void:
	if not paused:
		accumulator+=minf(delta,0.1)
		while accumulator>=STEP:
			accumulator-=STEP;simulate(STEP)
	sync_views()
func simulate(dt:float) -> void:
	demo_time+=dt
	if auto_demo:update_auto()
	cycle_time+=dt
	if history.emitting and not stopped:
		var target:=sin(cycle_time*3.5)*0.38 if turning else 0.0
		heading=rotate_toward(heading,target,1.2*dt)
		world+=Vector2.from_angle(heading)*speed*dt
	history.tick(dt,world,Vector2.from_angle(heading)*speed)
	if not history.active and looping and not stopped and cycle_time>history.lifetime+history.history_seconds+0.05:restart()
func update_auto() -> void:
	var next:=mini(int(demo_time/2.0),6)
	if next!=stage:
		stage=next
		if stage==6:stopped=true;history.stop()
		else:
			apply_preset(1 if stage in [1,3] else 0)
			tracking=stage>=2;turning=stage in [2,3];speed=60.0 if stage==4 else (320.0 if stage==5 else 180.0)
			restart();update_labels()
	if demo_time>=12.7 and "--physical-quit" in OS.get_cmdline_user_args():get_tree().quit()
func sync_views() -> void:
	actual.camera=history.world_position if tracking else Vector2.ZERO
	detail.camera=history.world_position
	actual.show_trail=show_trail;detail.show_trail=show_trail
	actual.sync();detail.sync()
	if status!=null:
		var kind:="ARROW" if history.body_kind==0 else "KNIFE"
		var motion:="TURNING" if turning else ("TRACKED" if tracking else "AXIAL FLIGHT")
		scene_label.text="ACTUAL SIZE / 1x / %s / %s"%[kind,motion]
		status.text="%d px/s | path %.1f px | %s"%[int(history.velocity.length()),history.trail_length,"PAUSED" if paused else ("STOPPED" if stopped else "LIVE")]
		track_button.text="Untrack" if tracking else "Track"
		turn_button.text="Straight" if turning else "Turn"
		trail_button.text="Trail on" if show_trail else "Trail off"
		loop_button.text="Loop" if looping else "Once"
