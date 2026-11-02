extends Node2D
const Effect=preload("res://effects/VFX-15_monster_death/death.gd")
const Host=preload("res://effects/VFX-15_monster_death/demo_host.gd")
var actual:Node2D
var enlarged:Node2D
var paused:=false
var looping:=true
var cycle:=0.0
var fired:=false
var clock_time:=0.0
var stage:=-1
var auto_demo:=false
var data:Dictionary
var sliders:Dictionary={}
var labels:Dictionary={}
var preset:OptionButton
var status:Label
var title:Label
var pause_button:Button
var background:=0
func _ready() -> void:
 data=JSON.parse_string(FileAccess.get_file_as_string("res://effects/VFX-15_monster_death/presets.json"))
 auto_demo="--death-auto" in OS.get_cmdline_user_args()
 actual=Effect.new();actual.position=Vector2(110,168);actual.set_host(Host.create_image());add_child(actual)
 enlarged=Effect.new();enlarged.position=Vector2(250,190);enlarged.scale=Vector2.ONE*3;enlarged.set_host(Host.create_image());add_child(enlarged)
 make_ui();apply_preset(0);replay()
func label_at(t:String,p:Vector2,size:int=11)->Label:
 var l:=Label.new();l.text=t;l.position=p;l.add_theme_font_size_override("font_size",size);add_child(l);return l
func button(t:String,p:Vector2,w:float,action:Callable)->Button:
 var b:=Button.new();b.text=t;b.position=p;b.size=Vector2(w,24);b.add_theme_font_size_override("font_size",11);b.pressed.connect(action);add_child(b);return b
func slider(key:String,y:float,lo:float,hi:float,step:float)->void:
 labels[key]=label_at("",Vector2(369,y))
 var s:=HSlider.new();s.position=Vector2(505,y+2);s.size=Vector2(115,18);s.min_value=lo;s.max_value=hi;s.step=step
 s.value_changed.connect(func(v):configure({key:v}));add_child(s);sliders[key]=s
func make_ui()->void:
 label_at("15 / MONSTER DEATH",Vector2(20,12),18)
 label_at("Host-aware dissolve + sparse ash. No spritesheet.",Vector2(20,39))
 title=label_at("",Vector2(20,73),13)
 label_at("1x / GAME SIZE",Vector2(59,111),10)
 label_at("3x / NEAREST DETAIL",Vector2(187,111),10)
 label_at("Body alpha preserved, including interior holes",Vector2(20,286),10)
 label_at("Independent burst can run without a host",Vector2(20,305),10)
 pause_button=button("Pause",Vector2(369,12),60,func():paused=not paused;pause_button.text="Play" if paused else "Pause")
 button("Frame",Vector2(434,12),55,func():paused=true;advance(1.0/60.0))
 button("Replay",Vector2(494,12),60,replay)
 button("Reset",Vector2(559,12),60,reset_all)
 slider("duration",81,0.12,1.0,0.01)
 slider("dissolve_seconds",114,0.06,1.0,0.01)
 slider("fragment_count",147,0,24,1)
 slider("spread",180,0,48,1)
 slider("drift",213,-40,60,1)
 slider("cluster_size",246,1,6,1)
 preset=OptionButton.new();preset.position=Vector2(369,280);preset.size=Vector2(250,25);preset.add_theme_font_size_override("font_size",11)
 for p in data.presets:preset.add_item(p.name)
 preset.item_selected.connect(apply_preset);add_child(preset)
 button("Flip",Vector2(369,314),60,func():configure({"flipped":not actual.flipped}))
 button("Cancel",Vector2(434,314),60,func():cancel())
 button("BG",Vector2(499,314),50,func():background=(background+1)%3;update_bg())
 button("Loop",Vector2(554,314),65,func():looping=not looping)
 status=label_at("",Vector2(20,337),10)
func configure(values:Dictionary)->void:
 actual.configure(values);enlarged.configure(values);update_ui();replay()
func apply_preset(i:int)->void:
 var v:Dictionary=data.defaults.duplicate();v.merge(data.presets[i].overrides,true);configure(v);preset.select(i);title.text=data.presets[i].name
func update_ui()->void:
 var names:={"duration":"Total / s","dissolve_seconds":"Dissolve / s","fragment_count":"Ash count","spread":"Spread / px/s","drift":"Lift / px/s","cluster_size":"Cluster / px"}
 for key in sliders:
  sliders[key].set_value_no_signal(actual.get(key));labels[key].text="%s: %s"%[names[key],str(snappedf(float(actual.get(key)),0.01))]
func replay()->void:
 cycle=0;fired=false;actual.reset();enlarged.reset()
func cancel()->void:
 looping=false;fired=true;actual.reset();enlarged.reset()
func reset_all()->void:
 paused=false;looping=true;background=0;update_bg();apply_preset(0)
func update_bg()->void:
 RenderingServer.set_default_clear_color([Color("20262b"),Color("080b10"),Color("e7e3d9")][background])
 for child in get_children():
  if child is Label:child.add_theme_color_override("font_color",Color("24313b") if background==2 else Color("d9e1e3"))
func _process(dt:float)->void:
 if not paused:advance(minf(dt,0.1))
 status.text="%.2f s | %s | particles %d | Space pause / R replay"%[actual.elapsed,"DONE" if actual.finished else "READY" if not actual.playing else "DISSOLVE",actual.live_fragments().size()]
func advance(dt:float)->void:
 clock_time+=dt
 if auto_demo:
  var next:=mini(3,int(clock_time/3.0))
  if next!=stage:
   stage=next;apply_preset([0,1,0,2][stage]);background=2 if stage==2 else 0;update_bg()
 cycle+=dt
 if cycle>=0.45 and not fired:
  fired=true;actual.play();enlarged.play()
 actual.advance(dt);enlarged.advance(dt)
 if looping and cycle>1.45:replay()
 if auto_demo and clock_time>=12.0:get_tree().quit()
func _unhandled_key_input(event:InputEvent)->void:
 if event.is_action_pressed("ui_accept"):paused=not paused
 if event is InputEventKey and event.pressed and event.keycode==KEY_R:replay()
