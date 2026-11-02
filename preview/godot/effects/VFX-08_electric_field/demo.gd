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
 auto_demo="--field-auto" in OS.get_cmdline_user_args();RenderingServer.set_default_clear_color(Color("20262e"))
 viewport=SubViewport.new();viewport.size=Vector2i(200,116);viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(viewport)
 world=load("res://effects/VFX-08_electric_field/world.gd").new();viewport.add_child(world)
 for entry in [[Vector2(14,104),1],[Vector2(226,64),2]]:
  var view:=TextureRect.new();view.position=entry[0];view.texture=viewport.get_texture();view.size=Vector2(200,116)*entry[1];view.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;add_child(view)
 label("08 / SUSTAINED ELECTRIC FIELD",Vector2(14,12),19)
 label("1x / actual",Vector2(14,76));label("2x / nearest",Vector2(226,40))
 label("Targets: inside / outside / crossing",Vector2(14,236),11)
 status=label("",Vector2(14,337),11)
 button("Restart",Vector2(14,45),replay)
 button("Pause",Vector2(100,45),func():paused=not paused)
 button("Stop",Vector2(14,270),func():world.field.stop())
 button("Move",Vector2(100,270),func():world.moving=not world.moving)
 button("Palette",Vector2(186,306),palette)
 button("BG",Vector2(274,306),background)
 button("Reset",Vector2(362,306),reset_all)
 slider("radius","Radius",Vector2(14,306),16,50,1,42)
 slider("density","Arcs",Vector2(460,306),1,5,1,3)
 replay()
func slider(key:String,title:String,p:Vector2,lo:float,hi:float,step:float,value:float)->void:
 label(title,p,10)
 var s:=HSlider.new();s.position=p+Vector2(45,0);s.size=Vector2(110,20);s.min_value=lo;s.max_value=hi;s.step=step;s.value=value
 s.value_changed.connect(func(v):values[key]=v;replay());add_child(s);sliders[key]=s
func replay()->void:
 world.hits=0;world.flashes.clear();world.field.play(Vector2(100,58),world.enemies,values)
func reset_all()->void:
 values={};paused=false;world.moving=true;world.time=0;clock=0;stage=-1;
 if light:background()
 sliders.radius.set_value_no_signal(42);sliders.density.set_value_no_signal(3);replay()
func palette()->void:
 if values.get("body","")=="9dd4ee":values.merge({"core":"f4f0e5","body":"c1b8ef","edge":"6a6098"},true)
 else:values.merge({"core":"e8f6ee","body":"9dd4ee","edge":"547aa9"},true)
 replay()
func background()->void:
 light=not light;RenderingServer.set_default_clear_color(Color("c1c6c8") if light else Color("20262e"))
 for c in get_children():
  if c is Label:c.add_theme_color_override("font_color",Color("273340") if light else Color("e8e9ec"))
func _process(dt:float)->void:
 if not paused:advance(dt)
 status.text="Hits %d | tick %.2fs | %.2f / %.1fs | %s"%[world.hits,world.field.config.tick_interval,world.field.age,world.field.config.duration,"ACTIVE" if world.field.active else ("DRAIN / NO HITS" if world.field.draining else "CLEAR")]
func advance(dt:float)->void:
 clock+=dt
 if auto_demo:
  var new_stage:=int(clock/3.8)
  if new_stage!=stage:
   stage=new_stage
   if stage==1:values={"radius":30,"density":2,"tick_interval":0.3,"core":"e8f6ee","body":"9dd4ee","edge":"547aa9"}
   if stage==2:values={"radius":47,"density":4,"tick_interval":0.6};background()
   if stage<3:replay()
  if clock>=11.4 and "--field-quit" in OS.get_cmdline_user_args():get_tree().quit()
 world.advance(dt)
