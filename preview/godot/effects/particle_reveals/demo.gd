extends Node2D
const Effect=preload("res://effects/particle_reveals/particle_reveals.gd")
const Host=preload("res://effects/particle_reveals/demo_host.gd")
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
 data=JSON.parse_string(FileAccess.get_file_as_string("res://effects/particle_reveals/presets.json"))
 auto_demo="--reveals-auto" in OS.get_cmdline_user_args()
 actual=Effect.new();actual.position=Vector2(140,134);actual.set_host(Host.create_image());add_view(actual,Rect2(20,94,320,76))
 enlarged=Effect.new();enlarged.position=Vector2(140,270);enlarged.scale=Vector2.ONE*2;enlarged.set_host(Host.create_image());add_view(enlarged,Rect2(20,190,320,136))
 make_ui();apply_preset(0);replay()
func add_view(view:Node2D,rect:Rect2)->void:
 var clip:=Control.new();clip.position=rect.position;clip.size=rect.size;clip.clip_contents=true;clip.mouse_filter=Control.MOUSE_FILTER_IGNORE;view.position-=rect.position;add_child(clip);clip.add_child(view)
func label_at(t:String,p:Vector2,size:int=11)->Label:
 var l:=Label.new();l.text=t;l.position=p;l.add_theme_font_size_override("font_size",size);add_child(l);return l
func button(t:String,p:Vector2,w:float,action:Callable)->Button:
 var b:=Button.new();b.text=t;b.position=p;b.size=Vector2(w,24);b.add_theme_font_size_override("font_size",11);b.pressed.connect(action);add_child(b);return b
func slider(key:String,y:float,lo:float,hi:float,step:float)->void:
 labels[key]=label_at("",Vector2(369,y))
 var s:=HSlider.new();s.position=Vector2(505,y+2);s.size=Vector2(115,18);s.min_value=lo;s.max_value=hi;s.step=step
 s.value_changed.connect(func(v):configure({key:v}));add_child(s);sliders[key]=s
func make_ui()->void:
 label_at("PARTICLE REVEALS",Vector2(20,12),18)
 label_at("Disintegrate / materialize from the same source pixels.",Vector2(20,39))
 title=label_at("",Vector2(20,63),13)
 label_at("1x / GAME SIZE",Vector2(20,82),10)
 label_at("2x / NEAREST DETAIL",Vector2(20,182),10)
 pause_button=button("Pause",Vector2(369,12),60,func():paused=not paused;pause_button.text="Play" if paused else "Pause")
 button("Frame",Vector2(434,12),55,func():paused=true;advance(1.0/60.0))
 button("Replay",Vector2(494,12),60,replay)
 button("Reset",Vector2(559,12),60,reset_all)
 slider("release_seconds",81,0.08,1.5,0.01)
 slider("dust_seconds",114,0.1,2.0,0.01)
 slider("wind_speed",147,0,100,1)
 slider("wind_degrees",180,-180,180,5)
 slider("turbulence",213,0,8,0.1)
 slider("density",246,0,1,0.05)
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
 var v:Dictionary=data.defaults.duplicate();v.merge(data.presets[i].overrides,true)
 var image:Image=Host.create_item() if data.presets[i].item else Host.create_image()
 actual.set_host(image);enlarged.set_host(image);configure(v);preset.select(i);title.text=data.presets[i].name
func update_ui()->void:
 var names:={"release_seconds":"Release / s","dust_seconds":"Dust life / s","wind_speed":"Wind / px/s","wind_degrees":"Direction / deg","turbulence":"Curl / px","density":"Dust density"}
 for key in sliders:
  sliders[key].set_value_no_signal(actual.get(key));labels[key].text="%s: %s"%[names[key],str(snappedf(float(actual.get(key)),0.01))]
func replay()->void:
 cycle=0;fired=false;actual.reset();enlarged.reset()
func cancel()->void:
 looping=false;fired=true;actual.cancel();enlarged.cancel()
func reset_all()->void:
 paused=false;looping=true;background=0;update_bg();apply_preset(0)
func update_bg()->void:
 RenderingServer.set_default_clear_color([Color("20262b"),Color("080b10"),Color("e7e3d9")][background])
 for child in get_children():
  if child is Label:child.add_theme_color_override("font_color",Color("24313b") if background==2 else Color("d9e1e3"))
func _process(dt:float)->void:
 if not paused:advance(minf(dt,0.1))
 status.text="%.2f s | %s | source pixels %d | Space pause"%[actual.elapsed,"DONE" if actual.finished else "READY" if not actual.active else actual.mode.to_upper(),actual.source_pixels.size()]
func advance(dt:float)->void:
 clock_time+=dt
 if auto_demo:
  var next:=mini(3,int(clock_time/3.0))
  if next!=stage:
   stage=next;apply_preset(stage);background=2 if stage==1 else 0;update_bg()
 cycle+=dt
 if cycle>=0.45 and not fired:
  fired=true;actual.play();enlarged.play()
 actual.advance(dt);enlarged.advance(dt)
 if looping and cycle>maxf(1.45,actual.total_lifetime()+0.9):replay()
 if auto_demo and clock_time>=12.0:get_tree().quit()
func _unhandled_key_input(event:InputEvent)->void:
 if event.is_action_pressed("ui_accept"):paused=not paused
 if event is InputEventKey and event.pressed and event.keycode==KEY_R:replay()
