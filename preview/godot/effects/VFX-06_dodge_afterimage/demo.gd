extends Node2D
const Trail=preload("res://effects/VFX-06_dodge_afterimage/afterimage.gd")
const Hero=preload("res://effects/VFX-06_dodge_afterimage/hero_fixture.gd")
var viewport:SubViewport
var host:Sprite2D
var trail:Node2D
var running:=true
var looping:=true
var time:=0.0
var cycle:=0.0
var mode:=0
var bg:=0
var frame_number:=0
var capture_dir:=""
var auto_mode:=false
var title:Label
var status:Label
var pause:Button
var section:=-1
var life_slider:HSlider
func label(text:String,p:Vector2,size:int=12)->Label:
 var l:=Label.new();l.text=text;l.position=p;l.add_theme_font_size_override("font_size",size);add_child(l);return l
func button(text:String,p:Vector2,w:float,action:Callable)->Button:
 var b:=Button.new();b.text=text;b.position=p;b.size=Vector2(w,24);b.add_theme_font_size_override("font_size",11);b.pressed.connect(action);add_child(b);return b
func _ready()->void:
 auto_mode="--dodge-auto" in OS.get_cmdline_user_args()
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--dodge-capture="):capture_dir=arg.trim_prefix("--dodge-capture=");DirAccess.make_dir_recursive_absolute(capture_dir)
 label("06 / DODGE AFTERIMAGE",Vector2(16,8),18)
 title=label("",Vector2(16,32),11)
 viewport=SubViewport.new();viewport.size=Vector2i(280,88);viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;viewport.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST;add_child(viewport)
 trail=Trail.new();viewport.add_child(trail)
 host=Sprite2D.new();host.texture=make_sheet();host.hframes=2;host.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;host.z_index=2;viewport.add_child(host)
 for info in [[Vector2(18,58),Vector2(280,88)],[Vector2(18,161),Vector2(560,176)]]:
  var v:=TextureRect.new();v.texture=viewport.get_texture();v.position=info[0];v.size=info[1];v.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;add_child(v)
 label("1x NORMAL SPEED",Vector2(18,46),10);label("2x NEAREST / SAME STATE",Vector2(18,148),10)
 pause=button("Pause",Vector2(320,55),66,func():running=not running;pause.text="Pause" if running else "Resume")
 button("+ Frame",Vector2(392,55),72,func():running=false;step(1.0/60.0))
 button("Replay",Vector2(470,55),66,replay)
 button("Clear",Vector2(542,55),65,func():trail.reset();running=false)
 button("Mode",Vector2(320,86),66,func():mode=(mode+1)%4;replay())
 button("Color",Vector2(392,86),72,func():trail.tint=Color("ef82c2") if trail.tint!=Color("ef82c2") else Color("7bdfeb"))
 button("BG",Vector2(470,86),66,func():bg=1-bg;queue_redraw())
 button("Reset",Vector2(542,86),65,reset_all)
 var slider:=HSlider.new();life_slider=slider;slider.min_value=0.08;slider.max_value=0.5;slider.step=0.01;slider.value=trail.lifetime;slider.position=Vector2(404,123);slider.size=Vector2(196,16);slider.value_changed.connect(func(v):trail.lifetime=v);add_child(slider)
 label("Life (sec)",Vector2(320,120),11)
 status=label("",Vector2(18,342),10)
 replay()
func make_sheet()->ImageTexture:
 var a:=Hero.texture().get_image();var b:=a.duplicate();b.fill_rect(Rect2i(3,15,3,9),Color.TRANSPARENT);b.fill_rect(Rect2i(1,13,5,3),Color("8cb1bd"));b.fill_rect(Rect2i(13,25,4,5),Color.TRANSPARENT);b.fill_rect(Rect2i(16,25,5,4),Color("87979e"))
 var sheet:=Image.create(48,32,false,Image.FORMAT_RGBA8);sheet.fill(Color.TRANSPARENT);sheet.blit_rect(a,Rect2i(0,0,24,32),Vector2i.ZERO);sheet.blit_rect(b,Rect2i(0,0,24,32),Vector2i(24,0));return ImageTexture.create_from_image(sheet)
func reset_all()->void:
 mode=0;trail.lifetime=0.22;life_slider.value=0.22;trail.tint=Color("7bdfeb");running=true;replay()
func replay()->void:
 cycle=0;host.position=Vector2(30,47);host.rotation=0;host.flip_h=mode==3;host.offset=Vector2(0,-2) if mode==3 else Vector2.ZERO;host.frame=0;trail.start(host);running=true;pause.text="Pause"
func step(dt:float)->void:
 cycle+=dt
 var u:=clampf(cycle/0.26,0,1)
 var x:=30+210*u
 var y:=47.0
 if mode==1:y=67-39*u
 if mode==2:y=48-22*sin(u*PI)
 if mode==3:x=240-210*u;host.frame=1 if u>0.45 else 0
 host.position=Vector2(x,y).round()
 if cycle>0.26:trail.stop()
 trail.advance(dt,host)
 if cycle>1.25 and looping:replay()
 title.text=["Straight dash / historical pose snapshots","Diagonal dash / world-position ghosts","Curved dash / no rotation required","Reverse + animation / flip and pivot captured"][mode]
 status.text="Ghosts %d / %d | %.2fs life | %.3fs interval | actual source alpha"%[trail.snapshots.size(),trail.max_images,trail.lifetime,trail.interval]
func _process(dt:float)->void:
 if capture_dir!="":dt=1.0/60
 time+=dt
 if auto_mode:
  var s:=int(time/3.0)
  if s!=section:
   section=s;mode=s%4;bg=1 if s==3 else 0;trail.tint=Color("ef82c2") if s==2 else Color("7bdfeb");replay();queue_redraw()
 if running:step(dt)
 if capture_dir!="":
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png(capture_dir+"/frame_%05d.png"%frame_number)
  frame_number+=1
  if frame_number>=720:get_tree().quit()
func _draw()->void:
 draw_rect(Rect2(0,0,640,360),Color("b7bdc7") if bg else Color("151b29"))
 for y in [58,161]:draw_rect(Rect2(16,y-1,564 if y==161 else 284,178 if y==161 else 90),Color("8893a7") if bg else Color("253248"),false,1)
