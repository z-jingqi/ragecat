extends Node2D
const Burst=preload("res://effects/VFX-08_lightning_burst/burst.gd")
var fx:Node2D
var targets:Array=[]
var hits:=0
var timer:=0.0
var elapsed:=0.0
var paused:=false
var loops:=true
var config:Dictionary=Burst.DEFAULTS.duplicate()
var dark:=true
var status:Label
var sliders:Dictionary={}
var frame:=0
var capture_dir:=""
var auto:=false
var stage:=-1
var area:SubViewport
func label(text:String,p:Vector2,size:int=11)->Label:
 var n:=Label.new();n.text=text;n.position=p;n.add_theme_font_size_override("font_size",size);add_child(n);return n
func button(text:String,p:Vector2,fn:Callable)->Button:
 var n:=Button.new();n.text=text;n.position=p;n.size=Vector2(68,26);n.add_theme_font_size_override("font_size",11);n.pressed.connect(fn);add_child(n);return n
func _ready()->void:
 auto="--burst-auto" in OS.get_cmdline_user_args()
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--capture-dir="):capture_dir=arg.trim_prefix("--capture-dir=");DirAccess.make_dir_recursive_absolute(capture_dir)
 area=SubViewport.new();area.size=Vector2i(176,128);area.transparent_bg=true;area.disable_3d=true;area.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(area)
 for p in [Vector2(50,46),Vector2(91,46),Vector2(115,80),Vector2(37,83),Vector2(155,50)]:
  var target:=Node2D.new();target.position=p;area.add_child(target)
  var shape:=Polygon2D.new();shape.polygon=PackedVector2Array([Vector2(-4,-7),Vector2(3,-7),Vector2(5,-3),Vector2(4,3),Vector2(-4,3),Vector2(-5,-3)]);shape.color=Color("768b93");target.add_child(shape);targets.append(target)
 fx=Burst.new();fx.automatic=false;area.add_child(fx);fx.target_hit.connect(on_hit)
 for item in [{"p":Vector2(12,112),"s":1},{"p":Vector2(190,68),"s":2}]:
  var n:=TextureRect.new();n.texture=area.get_texture();n.position=item.p;n.size=Vector2(176,128)*item.s;n.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;add_child(n)
 label("08 / ELECTRIC ORB - AREA HIT",Vector2(16,10),18)
 label("Central light orb + surrounding arcs. One hit per target.",Vector2(16,37))
 label("ACTUAL 1x",Vector2(16,88));label("2x NEAREST",Vector2(190,50))
 var y:=72.0
 for item in [["radius",8,65,1],["duration",0.12,0.8,0.02],["arcs",3,16,1],["orb_radius",3,16,1]]:
  var key:String=item[0];label(key,Vector2(548,y))
  var s:=HSlider.new();s.position=Vector2(548,y+18);s.size=Vector2(80,16);s.min_value=item[1];s.max_value=item[2];s.step=item[3];s.value=config[key];add_child(s);sliders[key]=s
  s.value_changed.connect(func(v:float):config[key]=v;trigger());y+=48
 button("Replay",Vector2(16,280),trigger);button("Pause",Vector2(90,280),func():paused=not paused)
 button("+Frame",Vector2(16,312),func():paused=true;advance(1.0/60))
 button("Clear",Vector2(90,312),func():fx.clear();loops=false)
 button("Reset",Vector2(548,279),reset)
 button("BG",Vector2(548,311),func():dark=not dark;set_bg())
 status=label("",Vector2(195,330),10);set_bg();trigger()
func set_bg()->void:
 RenderingServer.set_default_clear_color(Color("20262b") if dark else Color("dedfd6"))
 for child in get_children():
  if child is Label:child.add_theme_color_override("font_color",Color("e6eded") if dark else Color("273441"))
func on_hit(target:Node2D)->void:
 hits+=1;target.get_child(0).color=Color("f7ca76")
func trigger()->void:
 hits=0;timer=0;loops=true
 for target in targets:target.get_child(0).color=Color("768b93")
 fx.play(Vector2(82,65),targets,config)
func reset()->void:
 config=Burst.DEFAULTS.duplicate();paused=false;dark=true;set_bg()
 for k in sliders:sliders[k].set_value_no_signal(config[k])
 trigger()
func advance(dt:float)->void:
 timer+=dt;fx.tick(dt)
 if loops and timer>=1.5:trigger()
func _process(dt:float)->void:
 elapsed+=dt
 if auto:
  var next:=mini(4,int(elapsed/2.4))
  if next!=stage:
   stage=next;config=Burst.DEFAULTS.duplicate();config.radius=[42,24,56,42,42][stage]
   if stage==3:config.core="fff0ff";config.body="d99aff";config.edge="9563da"
   dark=stage!=4;set_bg()
   for k in sliders:sliders[k].set_value_no_signal(config[k])
   trigger()
 if not paused:advance(dt)
 status.text="Hit: %d / %d   Radius: %.0f   %.0f ms   %s"%[hits,targets.size(),float(config.radius),float(config.duration)*1000,"PAUSED" if paused else ("BURST" if fx.active else "CLEAR")]
 if capture_dir!="":
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png(capture_dir.path_join("frame_%05d.png"%frame));frame+=1
 if auto and elapsed>=12 and "--burst-quit" in OS.get_cmdline_user_args():get_tree().quit()
