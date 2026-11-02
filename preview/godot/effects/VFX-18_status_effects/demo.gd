extends Node2D
const Effect=preload("res://effects/VFX-18_status_effects/status_effect.gd")
const Fixture=preload("res://effects/VFX-05_hit_flash/hero_fixture.gd")
var fx:Array=[]
var hosts:Array=[]
var age:=0.0
var paused:=false
var bg:=0
var move_host:=false
var auto_mode:=false
var capture_dir:=""
var frame:=0
var section:=-1
var selector:OptionButton
var status:Label
var intensity_slider:HSlider
func lab(s:String,p:Vector2,size:int=11)->Label:
 var l:=Label.new();l.text=s;l.position=p;l.add_theme_font_size_override("font_size",size);add_child(l);return l
func btn(s:String,p:Vector2,w:float,fn:Callable)->void:
 var b:=Button.new();b.text=s;b.position=p;b.size=Vector2(w,25);b.add_theme_font_size_override("font_size",11);b.pressed.connect(fn);add_child(b)
func _ready()->void:
 auto_mode="--status-auto" in OS.get_cmdline_user_args()
 for a in OS.get_cmdline_user_args():
  if a.begins_with("--status-capture="):capture_dir=a.trim_prefix("--status-capture=");DirAccess.make_dir_recursive_absolute(capture_dir)
 lab("18 / ATTACHED STATUS EFFECTS",Vector2(18,12),17)
 lab("Four independent states / low glare / original material retained",Vector2(18,37))
 lab("ACTUAL 1x / NORMAL SPEED",Vector2(18,70))
 lab("2x NEAREST / SAME STATE",Vector2(18,185))
 for row in range(2):
  for i in range(4):
   var h:=Sprite2D.new();h.texture=Fixture.texture();h.position=Vector2(58+i*100,129 if row==0 else 264);h.scale=Vector2.ONE*(1 if row==0 else 2);h.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;add_child(h);hosts.append(h)
   var e:=Effect.new();add_child(e);e.bind_host(h);fx.append(e)
   if row==0:lab(Effect.KINDS[i].to_upper(),Vector2(28+i*100,158),10)
 btn("Pause",Vector2(445,60),70,func():paused=not paused)
 btn("+ Frame",Vector2(523,60),85,func():tick(1.0/60))
 btn("Replay",Vector2(445,94),70,replay)
 btn("Clear",Vector2(523,94),85,func():
  for e in fx:e.clear_all())
 btn("Refresh",Vector2(445,128),70,func():
  for i in range(fx.size()):fx[i].apply_status(Effect.KINDS[i%4],3,3))
 btn("Remove fire",Vector2(523,128),85,func():
  for e in fx:e.remove_status("burning"))
 selector=OptionButton.new();selector.position=Vector2(445,171);selector.size=Vector2(164,25)
 for name in ["Separate statuses","All combined","Fire + ice","Poison + shock"]:selector.add_item(name)
 selector.item_selected.connect(func(_i):replay());add_child(selector)
 lab("Intensity",Vector2(445,210))
 intensity_slider=HSlider.new();intensity_slider.position=Vector2(445,231);intensity_slider.size=Vector2(163,18);intensity_slider.min_value=0;intensity_slider.max_value=0.65;intensity_slider.step=0.01;intensity_slider.value=0.22
 intensity_slider.value_changed.connect(func(v):
  for e in fx:e.configure({"intensity":v}))
 add_child(intensity_slider)
 btn("BG",Vector2(445,266),45,func():bg=(bg+1)%3;queue_redraw())
 btn("Move",Vector2(495,266),55,func():move_host=not move_host)
 btn("Reset",Vector2(555,266),55,reset)
 status=lab("",Vector2(18,336),10);replay()
func reset()->void:
 paused=false;move_host=false;age=0;selector.select(0);intensity_slider.value=0.22
 for h in hosts:h.self_modulate=Color.WHITE
 replay()
func replay()->void:
 for i in range(fx.size()):
  fx[i].clear_all()
  var kinds:Array=[Effect.KINDS[i%4]]
  if selector.selected==1:kinds=Effect.KINDS
  elif selector.selected==2:kinds=["burning","frozen"]
  elif selector.selected==3:kinds=["poison","shock"]
  for k in kinds:fx[i].apply_status(k,3)
func tick(dt:float)->void:
 age+=dt
 for i in range(fx.size()):
  var h:Sprite2D=hosts[i];h.position.x=58+(i%4)*100+(sin(age*1.8)*8 if move_host else 0)
  fx[i].tick(dt)
 status.text="States %d / intensity %.2f / colors never add brightness / refresh preserves phase"%[fx[0].states.size(),fx[0].intensity]
func _process(dt:float)->void:
 if auto_mode:
  var next:=int(age/4.0)
  if next!=section:
   section=next;selector.select(mini(next,3));replay()
   if next==2:move_host=true
   if next==3:bg=2;queue_redraw()
  tick(1.0/60)
 elif not paused:tick(dt)
 status.text="States %d / intensity %.2f / colors never add brightness / refresh preserves phase"%[fx[0].states.size(),fx[0].intensity]
 if auto_mode and capture_dir!="":
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png(capture_dir+"/frame_%05d.png"%frame);frame+=1
 if auto_mode and age>=16.0:get_tree().quit()
func _draw()->void:
 draw_rect(Rect2(0,0,640,360),[Color("23272e"),Color("0c1018"),Color("a1aab2")][bg])
 draw_rect(Rect2(18,93,403,80),Color(0.05,0.06,0.08,0.18))
 draw_rect(Rect2(18,207,403,113),Color(0.05,0.06,0.08,0.18))
