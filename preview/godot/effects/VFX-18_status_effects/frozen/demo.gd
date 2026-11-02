extends Node2D
const Frozen=preload("res://effects/VFX-18_status_effects/frozen/frozen.gd")
const Knight=preload("res://effects/VFX-18_status_effects/frozen/knight_fixture.gd")
const Fixture=preload("res://effects/VFX-18_status_effects/burning/fixture.gd")
var effects:Array=[]
var hosts:Array=[]
var age:=0.0
var paused:=false
var animate:=true
var light:=false
var slider:HSlider
var info:Label
var auto_mode:=false
var capture:=""
var frame:=0
var section:=-1
func label_at(text:String,p:Vector2,size:int=12)->Label:
 var l:=Label.new();l.text=text;l.position=p;l.add_theme_font_size_override("font_size",size);add_child(l);return l
func button(text:String,p:Vector2,fn:Callable)->void:
 var c:=Button.new();c.text=text;c.position=p;c.size=Vector2(75,25);c.add_theme_font_size_override("font_size",11);c.pressed.connect(fn);add_child(c)
func _ready()->void:
 get_window().content_scale_size=Vector2i(960,540)
 for a in OS.get_cmdline_user_args():
  if a=="--frozen-auto":auto_mode=true
  if a.begins_with("--frozen-capture="):capture=a.trim_prefix("--frozen-capture=");DirAccess.make_dir_recursive_absolute(capture)
 label_at("FROZEN / ATTACHED TO THE SPRITE",Vector2(16,12),18)
 label_at("Growing frost crust / uneven edge crystals / cracks and thaw",Vector2(16,39),11)
 label_at("NATIVE 1x / NORMAL SPEED / ANIMATED HOSTS",Vector2(16,59),11)
 label_at("2x NEAREST / SAME FRAMES",Vector2(16,249),11)
 label_at("ORIGINAL",Vector2(42,79),10)
 label_at("ENCASING ICE / SAME ORIGINAL SPRITE",Vector2(174,79),10)
 label_at("MASK TEST",Vector2(650,79),10)
 for row in range(2):
  var original:=Sprite2D.new();original.texture=Knight.texture();original.hframes=2;original.position=Vector2(75,150 if row==0 else 345);original.scale=Vector2.ONE*(row+1);original.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;add_child(original)
  for i in range(4):
   var h:=Sprite2D.new();h.texture=Knight.texture() if i<3 else Fixture.texture();h.hframes=2;h.position=Vector2([220,380,540,675][i],150 if row==0 else 345);h.scale=Vector2.ONE*(row+1);h.z_index=10;h.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;add_child(h);hosts.append(h)
   var f:=Frozen.new();add_child(f);f.bind_host(h);f.configure({"seed":18+i*31});effects.append(f)
 button("Replay",Vector2(738,75),replay)
 button("Pause",Vector2(824,75),func():paused=not paused)
 button("+ Frame",Vector2(738,110),func():tick(1.0/60))
 button("Cancel",Vector2(824,110),func():
  for f in effects:f.cancel())
 button("Clear",Vector2(738,145),func():
  for f in effects:f.clear())
 button("Animate",Vector2(824,145),func():animate=not animate)
 label_at("Ice intensity / 0 disables visuals",Vector2(738,192),10)
 slider=HSlider.new();slider.position=Vector2(738,218);slider.size=Vector2(162,20);slider.min_value=0;slider.max_value=0.7;slider.step=0.01;slider.value=0.4;add_child(slider)
 slider.value_changed.connect(func(v):
  for f in effects:f.configure({"intensity":v}))
 button("BG",Vector2(738,257),func():light=not light;queue_redraw())
 button("Refresh",Vector2(824,257),func():
  for f in effects:f.play(1.8))
 info=label_at("",Vector2(16,515),10);replay()
func replay()->void:
 for f in effects:f.clear();f.play(1.8)
func tick(dt:float)->void:
 age+=dt
 for i in range(hosts.size()):
  hosts[i].frame=int(age*3)%2 if animate else 0
  effects[i].tick(dt)
func _process(dt:float)->void:
 if auto_mode:
  var next:=int(age/4)
  if next!=section:
   section=next;replay()
   if next==1:light=true;queue_redraw()
   if next==2:
    light=false;slider.value=0.22;queue_redraw()
    for e in effects:e.configure({"ice_color":"9b85ba","facet_color":"c1b3d5","edge_color":"d2c4e0","crack_color":"53496e","mist_color":"776b90","body_color":"b7a3cd"})
  tick(1.0/60)
 elif not paused:tick(dt)
 info.text="Frozen / %s / strength %.2f / host animation remains controlled by the game"%[effects[0].phase,effects[0].strength]
 if capture!="":
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png(capture+"/frame_%05d.png"%frame);frame+=1
 if auto_mode and age>=12:get_tree().quit()
func _draw()->void:
 draw_rect(Rect2(0,0,960,540),Color("acb1b5") if light else Color("20242c"))
