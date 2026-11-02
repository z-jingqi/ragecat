extends Node2D
const State=preload("res://effects/VFX-21_xp_pickup/xp_state.gd")
const View=preload("res://effects/VFX-21_xp_pickup/xp_view.gd")
var state:=State.new()
var actual:Node2D
var detail:Node2D
var paused:=false
var moving:=false
var time:=0.0
var cycle:=0.0
var auto_demo:=false
var attracted:=false
var stage:=-1
var target:=Vector2(128,5)
var sliders:Dictionary={}
var labels:Dictionary={}
var status:Label
var pause_button:Button
var move_button:Button
var phase_label:Label
var bg:=0
func label(text:String,x:float,y:float,size:int=11)->Label:
 var l:=Label.new();l.text=text;l.position=Vector2(x,y);l.add_theme_font_size_override("font_size",size);add_child(l);return l
func button(text:String,x:float,y:float,w:float,action:Callable)->Button:
 var b:=Button.new();b.text=text;b.position=Vector2(x,y);b.size=Vector2(w,25);b.add_theme_font_size_override("font_size",11);b.pressed.connect(action);add_child(b);return b
func slider(key:String,name:String,y:float,lo:float,hi:float,step:float)->void:
 labels[key]=label(name,408,y)
 var s:=HSlider.new();s.position=Vector2(520,y);s.size=Vector2(100,18);s.min_value=lo;s.max_value=hi;s.step=step;s.value=state.config[key]
 s.value_changed.connect(func(v):state.configure({key:v});update_labels());add_child(s);sliders[key]=s
func _ready()->void:
 auto_demo="--xp-auto" in OS.get_cmdline_user_args()
 RenderingServer.set_default_clear_color(Color("20282d"))
 label("21 / XP PICKUP",20,12,18)
 label("Drop / settle / follow / arrive. No baked path.",20,40)
 label("ACTUAL SIZE / 1x",20,76)
 label("DETAIL / 2x NEAREST",20,213)
 actual=View.new();actual.state=state;actual.origin=Vector2(180,151);add_child(actual)
 var clip:=Control.new();clip.position=Vector2(20,235);clip.size=Vector2(368,90);clip.clip_contents=true;clip.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(clip)
 detail=View.new();detail.state=state;detail.zoom=2;detail.origin=Vector2(180,48);clip.add_child(detail)
 pause_button=button("Pause",408,14,62,func():paused=not paused;pause_button.text="Play" if paused else "Pause")
 button("Frame",477,14,62,func():paused=true;pause_button.text="Play";simulate(1.0/60.0))
 button("Reset",546,14,74,reset_all)
 slider("count","Count",68,1,32,1)
 slider("radius","Radius / px",96,2,8,1)
 slider("scatter","Spread / px",124,0,90,1)
 slider("attract_speed","Speed / px/s",152,30,600,10)
 slider("acceleration","Accel / px/s2",180,60,2000,20)
 slider("trail_length","Tail / px",208,0,40,1)
 button("Drop",408,243,62,replay)
 button("Attract",477,243,62,func():state.attract(target);attracted=true)
 move_button=button("Move target",546,243,74,func():moving=not moving;move_button.text="Target still" if moving else "Move target")
 button("Lose target",408,276,100,func():state.invalidate_target();attracted=true)
 button("Palette",515,276,65,cycle_palette)
 button("BG",586,276,34,cycle_background)
 phase_label=label("",20,193,10)
 status=label("",20,338,10)
 label("Controls apply live; count/spread: next drop.",408,314,10)
 reset_all()
func update_labels()->void:
 var names:={"count":"Count","radius":"Radius","scatter":"Spread","attract_speed":"Speed","acceleration":"Accel","trail_length":"Tail"}
 for k in labels:labels[k].text="%s  %s"%[names[k],str(state.config[k])];sliders[k].set_value_no_signal(state.config[k])
func replay()->void:
 state.reset();cycle=0;attracted=false;state.spawn(Vector2(-68,4));state.target=target
func reset_all()->void:
 state.config=JSON.parse_string(FileAccess.get_file_as_string("res://effects/VFX-21_xp_pickup/default.json"))
 paused=false;moving=false;target=Vector2(128,5);pause_button.text="Pause";move_button.text="Move target";bg=0;RenderingServer.set_default_clear_color(Color("20282d"));update_labels();replay()
 for child in get_children():
  if child is Label:child.add_theme_color_override("font_color",Color("e0e8e8"))
func cycle_palette()->void:
 if state.config.color_body=="48d99b":state.configure({"color_dark":"7451a4","color_body":"b28aff","color_light":"fff0ff"})
 else:state.configure({"color_dark":"238477","color_body":"48d99b","color_light":"d6ffd0"})
func cycle_background()->void:
 bg=(bg+1)%3;RenderingServer.set_default_clear_color([Color("20282d"),Color("080c11"),Color("c8cecf")][bg])
 for child in get_children():
  if child is Label:child.add_theme_color_override("font_color",Color("25363b") if bg==2 else Color("e0e8e8"))
func _process(dt:float)->void:
 if not paused:simulate(minf(dt,0.1))
 sync_views()
func simulate(dt:float)->void:
 time+=dt;cycle+=dt
 if auto_demo:
  var next:=mini(int(time/3.2),3)
  if next!=stage:
   stage=next;moving=stage in [1,2];replay()
   if stage==2:cycle_palette();state.configure({"attract_speed":190,"count":14});update_labels();replay()
   if stage==3:state.configure({"count":1,"radius":6});moving=false;update_labels();replay()
  if cycle>=1.0 and not attracted:state.attract(target);attracted=true
  if time>=12.8 and "--xp-quit" in OS.get_cmdline_user_args():get_tree().quit()
 if moving:target=Vector2(115+sin(time*2.0)*30,sin(time*3.2)*24)
 state.tick(dt,target,state.target_valid)
 sync_views()
func sync_views()->void:
 actual.queue_redraw();detail.queue_redraw()
 var center:=Vector2(-40,0)
 if not state.gems.is_empty():
  center=Vector2.ZERO
  for g in state.gems:center+=g.pos
  center/=state.gems.size()
 detail.camera=center
 status.text="Active %d / 32 | Arrivals %d | target %s | %s"%[state.gems.size(),state.arrived_count,"moving" if moving else "still","PAUSED" if paused else "LIVE"]
 var phases:={0:"DROP",1:"IDLE",2:"ATTRACT",3:"ARRIVE"}
 phase_label.text="%s | %s"%[phases[state.gems[0].phase] if not state.gems.is_empty() else "CLEAR","TARGET LOST" if not state.target_valid else "Target is read every tick"]
