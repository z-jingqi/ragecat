extends Node2D
const State=preload("res://effects/VFX-05_hit_flash/flash_state.gd")
const Fixture=preload("res://effects/VFX-05_hit_flash/hero_fixture.gd")
const FlashShader=preload("res://effects/VFX-05_hit_flash/flash.gdshader")
var state:=State.new()
var materials:Array[ShaderMaterial]=[]
var sprites:Array[Sprite2D]=[]
var data:Dictionary
var time:=0.0
var cycle:=0.0
var looping:=true
var sliders:={}
var labels:={}
var preset:OptionButton
var status:Label
var pause_button:Button
var auto_mode:=false
var capture_dir:=""
var capture_frame:=0
var section:=-1
var bg:=0
func label_at(text:String,p:Vector2,size:int=12)->Label:
 var l:=Label.new();l.text=text;l.position=p;l.add_theme_font_size_override("font_size",size);add_child(l);return l
func button(text:String,p:Vector2,w:float,fn:Callable)->Button:
 var b:=Button.new();b.text=text;b.position=p;b.size=Vector2(w,25);b.add_theme_font_size_override("font_size",11);b.pressed.connect(fn);add_child(b);return b
func _ready()->void:
 data=JSON.parse_string(FileAccess.get_file_as_string("res://effects/VFX-05_hit_flash/presets.json"))
 auto_mode="--flash-auto" in OS.get_cmdline_user_args()
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--flash-capture="): capture_dir=arg.trim_prefix("--flash-capture=");DirAccess.make_dir_recursive_absolute(capture_dir)
 label_at("05 / HOST HIT FLASH",Vector2(20,12),18)
 label_at("Body color flash. Alpha and silhouette stay intact.",Vector2(20,39),11)
 label_at("ACTUAL 1x / NORMAL SPEED",Vector2(20,78),11)
 label_at("3x NEAREST / SAME STATE",Vector2(20,172),11)
 for item in [[Vector2(78,129),1.0,false],[Vector2(206,129),1.0,true],[Vector2(78,253),3.0,false],[Vector2(206,253),3.0,true]]:
  var s:=Sprite2D.new();s.texture=Fixture.texture();s.position=item[0];s.scale=Vector2.ONE*item[1];s.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
  add_child(s);sprites.append(s)
  if item[2]:
   var m:=ShaderMaterial.new();m.shader=FlashShader;m.set_shader_parameter("amount",0.0);s.material=m;materials.append(m)
 label_at("Original",Vector2(54,147),10);label_at("Hit",Vector2(197,147),10)
 label_at("Original",Vector2(54,309),10);label_at("Hit",Vector2(197,309),10)
 pause_button=button("Pause",Vector2(350,15),60,toggle_pause)
 button("+ Frame",Vector2(416,15),70,step_once)
 button("Reset",Vector2(492,15),60,reset_all)
 button("Hit",Vector2(558,15),60,hit)
 label_at("FLASH PARAMETERS",Vector2(350,67),12)
 add_slider("peak",105,0.0,0.8,0.01,0.46)
 add_slider("duration",145,0.02,0.5,0.005,0.11)
 add_slider("hold",185,0,0.08,0.001,0.018)
 preset=OptionButton.new();preset.position=Vector2(350,230);preset.size=Vector2(175,28)
 for p in data.presets: preset.add_item(p.label)
 preset.item_selected.connect(apply_preset);add_child(preset)
 button("Repeat hit",Vector2(350,274),95,func():hit();get_tree().create_timer(0.035).timeout.connect(hit))
 button("Loop",Vector2(451,274),65,func():looping=not looping;cycle=0.0)
 button("BG",Vector2(522,274),40,func():bg=(bg+1)%3;queue_redraw())
 button("Alpha",Vector2(568,274),50,func():
  for s in sprites: s.modulate.a=0.5 if s.modulate.a>0.5 else 1.0)
 label_at("Peak is color mix, never opacity.",Vector2(350,317),11)
 status=label_at("",Vector2(20,338),10)
 reset_all()
func add_slider(key:String,y:float,lo:float,hi:float,step:float,v:float)->void:
 labels[key]=label_at("",Vector2(350,y),11)
 var s:=HSlider.new();s.position=Vector2(475,y);s.size=Vector2(143,18);s.min_value=lo;s.max_value=hi;s.step=step;s.value=v
 s.value_changed.connect(func(value):state.configure({key:value});refresh())
 add_child(s);sliders[key]=s
func apply_preset(i:int)->void:
 var values:Dictionary=data.defaults.duplicate();values.merge(data.presets[i].overrides,true);state.configure(values);preset.select(i);refresh()
func reset_all()->void:
 state.reset();looping=true;cycle=0;time=0;apply_preset(0)
 for s in sprites:s.modulate.a=1.0
 pause_button.text="Pause"
 hit()
func hit()->void:state.trigger();refresh()
func toggle_pause()->void:state.paused=not state.paused;pause_button.text="Resume" if state.paused else "Pause"
func step_once()->void:
 var p:=state.paused;state.paused=false;advance(1.0/60.0);state.paused=p;refresh()
func advance(dt:float)->void:
 if state.paused:return
 state.tick(dt);time+=dt;cycle+=dt
 if looping and cycle>=0.85:cycle=fmod(cycle,0.85);hit()
func refresh()->void:
 for k in sliders:
  sliders[k].set_value_no_signal(state.get(k));labels[k].text="%s  %.3f"%[k,state.get(k)]
 for m in materials:m.set_shader_parameter("amount",state.amount());m.set_shader_parameter("flash_color",state.tint)
 if status:status.text="%s | %.0f ms | mix %.2f | 1x and 3x use identical timing"%["HIT" if state.active else "READY",state.elapsed*1000,state.amount()]
func _process(dt:float)->void:
 if auto_mode:
  var next:=mini(4,int(time/2.0))
  if next!=section:
   section=next
   if section<4:apply_preset(section)
   else:
    apply_preset(0)
    for s in sprites:s.modulate.a=0.5
   cycle=0.0;hit()
  advance(1.0/60.0)
 else:advance(dt)
 refresh()
 if auto_mode and capture_dir!="":
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png(capture_dir+"/frame_%05d.png"%capture_frame)
  capture_frame+=1
 if auto_mode and time>=10.0:get_tree().quit()
func _draw()->void:
 var colors:=[Color("24282d"),Color("0f1318"),Color("9ea7ad")]
 draw_rect(Rect2(0,0,640,360),colors[bg])
 for r in [Rect2(20,99,294,60),Rect2(20,194,294,131)]:draw_rect(r,Color(0.05,0.07,0.09,0.25))
