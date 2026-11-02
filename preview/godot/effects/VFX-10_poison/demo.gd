extends Node2D
var world:Node2D
var viewport:SubViewport
var paused:=false
var auto_demo:=false
var clock:=0.0
var stage:=-1
var status:Label
var values:Dictionary={}
var sliders:Dictionary={}
var light:=false
func label(t:String,p:Vector2,size:int=12)->Label:
 var l:=Label.new();l.text=t;l.position=p;l.add_theme_font_size_override("font_size",size);add_child(l);return l
func button(t:String,p:Vector2,cb:Callable)->Button:
 var b:=Button.new();b.text=t;b.position=p;b.size=Vector2(80,24);b.add_theme_font_size_override("font_size",11);b.pressed.connect(cb);add_child(b);return b
func _ready()->void:
 auto_demo="--poison-auto" in OS.get_cmdline_user_args();RenderingServer.set_default_clear_color(Color("20262e"))
 viewport=SubViewport.new();viewport.size=Vector2i(200,116);viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(viewport)
 world=load("res://effects/VFX-10_poison/world.gd").new();viewport.add_child(world)
 for entry in [[Vector2(14,104),1],[Vector2(226,64),2]]:
  var view:=TextureRect.new();view.position=entry[0];view.texture=viewport.get_texture();view.size=Vector2(200,116)*entry[1];view.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;add_child(view)
 label("10 / POISON CLOUD",Vector2(14,12),19)
 label("1x / actual",Vector2(14,76));label("2x / nearest",Vector2(226,40))
 label("World area / rolling gas / bubbles",Vector2(14,236),11)
 status=label("",Vector2(14,337),11)
 button("Restart",Vector2(14,45),replay)
 button("Pause",Vector2(100,45),func():paused=not paused)
 button("Stop",Vector2(14,270),func():world.field.stop())
 button("Move",Vector2(100,270),func():world.moving=not world.moving)
 button("Palette",Vector2(186,306),palette)
 button("BG",Vector2(274,306),background)
 button("Reset",Vector2(362,306),reset_all)
 slider("radius","Radius",Vector2(14,306),16,50,1,40)
 slider("density","Clouds",Vector2(460,306),0,24,1,16)
 replay()
func slider(key:String,title:String,p:Vector2,lo:float,hi:float,step:float,value:float)->void:
 label(title,p,10)
 var s:=HSlider.new();s.position=p+Vector2(45,0);s.size=Vector2(110,20);s.min_value=lo;s.max_value=hi;s.step=step;s.value=value
 s.value_changed.connect(func(v):values[key]=v;replay());add_child(s);sliders[key]=s
func replay()->void:
 world.hits=0;world.flashes.clear();world.field.play(Vector2(100,76),values)
func reset_all()->void:
 values={};paused=false;world.moving=true;world.time=0;clock=0;stage=-1;
 if light:background()
 sliders.radius.set_value_no_signal(40);sliders.density.set_value_no_signal(16);replay()
func palette()->void:
 if values.get("body","")=="9560a0":values={}
 else:values.merge({"deep":"332b46","shade":"5c3b6b","body":"9560a0","rim":"c58bb5","light":"ead0ca"},true)
 replay()
func background()->void:
 light=not light;RenderingServer.set_default_clear_color(Color("c1c6c8") if light else Color("20262e"))
 for c in get_children():
  if c is Label:c.add_theme_color_override("font_color",Color("273340") if light else Color("e8e9ec"))
func _process(dt:float)->void:
 if not paused:advance(dt)
 status.text="Inside %d | flow %.2f | %.2f / %.1fs | %s"%[world.hits,world.field.config.flow,world.field.age,world.field.config.duration,"ACTIVE" if world.field.active else ("DRAIN / NO HITS" if world.field.draining else "CLEAR")]
func advance(dt:float)->void:
 clock+=dt
 if auto_demo:
  var new_stage:=int(clock/3.8)
  if new_stage!=stage:
   stage=new_stage
   if stage==1:values={"radius":30,"density":9,"flow":1.4,"deep":"332b46","shade":"5c3b6b","body":"9560a0","rim":"c58bb5","light":"ead0ca"}
   if stage==2:values={"radius":47,"density":18,"flow":0.75};background()
   if stage<3:replay()
  if clock>=11.4 and "--poison-quit" in OS.get_cmdline_user_args():get_tree().quit()
 world.advance(dt)
