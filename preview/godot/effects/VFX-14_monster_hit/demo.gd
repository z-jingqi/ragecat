extends Node2D
const Hit=preload("res://effects/VFX-14_monster_hit/monster_hit.gd")
const Fixture=preload("res://effects/VFX-14_monster_hit/fixture.gd")
var players:Array=[]
var hosts:Array=[]
var time:=0.0
var cycle:=0.0
var phase:=-1
var paused:=false
var light:=false
var looping:=true
var move_host:=false
var alpha:=false
var capture:=""
var frame:=0
var auto:=false
var amount:=0.20
var duration:=0.11
var mode:=0
var stress:=false
var status:Label
func label(text:String,p:Vector2,size:int=12)->Label:
 var l=Label.new();l.text=text;l.position=p;l.add_theme_font_size_override("font_size",size);add_child(l);return l
func button(text:String,p:Vector2,fn:Callable)->void:
 var b=Button.new();b.text=text;b.position=p;b.size=Vector2(80,25);b.add_theme_font_size_override("font_size",11);b.pressed.connect(fn);add_child(b)
func _ready()->void:
 auto="--hit-auto" in OS.get_cmdline_user_args()
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--hit-capture="):capture=arg.trim_prefix("--hit-capture=");DirAccess.make_dir_recursive_absolute(capture)
 label("14 / MONSTER HIT FEEDBACK",Vector2(20,12),18)
 label("Small blood flecks + restrained per-host flash",Vector2(20,40),11)
 label("ACTUAL 1x / NORMAL SPEED",Vector2(20,78),11)
 label("2x NEAREST / SAME INPUT",Vector2(20,174),11)
 for scale_value in [1,2]:
  var root=Node2D.new();root.position=Vector2(25,95 if scale_value==1 else 192);root.scale=Vector2.ONE*scale_value;add_child(root)
  for i in 6:
   var s=Sprite2D.new();s.texture=Fixture.texture(i%2);s.position=Vector2(12+i*25,25);root.add_child(s);hosts.append(s)
   var h=Hit.new();h.auto_tick=false;root.add_child(h);h.bind(s);players.append(h)
 label("A / B hit individually; remaining hosts untouched",Vector2(22,153),10)
 label("No opacity blink. No recoil / damage logic.",Vector2(22,304),10)
 button("Hit A",Vector2(355,78),func():trigger(0))
 button("Hit B",Vector2(445,78),func():trigger(1))
 button("Both",Vector2(535,78),func():trigger(0);trigger(1))
 button("Pause",Vector2(355,115),func():paused=not paused)
 button("+ Frame",Vector2(445,115),func():advance(1.0/60.0))
 button("Reset",Vector2(535,115),reset_all)
 button("Move",Vector2(355,152),func():move_host=not move_host)
 button("Alpha",Vector2(445,152),func():alpha=not alpha;apply_alpha())
 button("BG",Vector2(535,152),func():light=not light;queue_redraw())
 button("Crowd",Vector2(355,189),func():stress=not stress)
 var option=OptionButton.new();option.position=Vector2(445,189);option.size=Vector2(170,25)
 for name in ["Body + contact","Body only","Contact only"]:option.add_item(name)
 option.item_selected.connect(func(i):mode=i;configure());add_child(option)
 label("Flash strength",Vector2(355,239),11)
 var s=HSlider.new();s.position=Vector2(465,240);s.size=Vector2(150,18);s.min_value=0;s.max_value=0.8;s.step=0.01;s.value=amount;s.value_changed.connect(func(v):amount=v;configure());add_child(s)
 label("Flash time (s)",Vector2(355,273),11)
 var t=HSlider.new();t.position=Vector2(465,274);t.size=Vector2(150,18);t.min_value=0.02;t.max_value=0.5;t.step=0.01;t.value=duration;t.value_changed.connect(func(v):duration=v;configure());add_child(t)
 status=label("",Vector2(20,337),10)
 configure()
func configure()->void:
 for i in players.size():players[i].configure({"peak":amount,"duration":duration,"color":"ffe2b4" if i%6==0 else "b4e4ff","flash_enabled":mode!=2,"impact_enabled":mode!=1})
func apply_alpha()->void:
 for s in hosts:s.modulate.a=0.5 if alpha else 1.0
func reset_all()->void:
 for p in players:p.clear()
 paused=false;looping=true;move_host=false;alpha=false;cycle=0;stress=false;apply_alpha()
func trigger(index:int)->void:
 for offset in [0,6]:
  var s=hosts[index+offset]
  players[index+offset].hit(s.global_position+Vector2(-7,0)*s.get_parent().scale.x,Vector2.RIGHT)
func advance(dt:float)->void:
 time+=dt;cycle+=dt
 for p in players:p.tick(dt)
 if move_host:
  for i in hosts.size():hosts[i].position.x=12+(i%6)*25+round(sin(time*3)*8)
 else:
  for i in hosts.size():hosts[i].position.x=12+(i%6)*25
 if stress:
  if cycle>=0.05:
   cycle=fmod(cycle,0.05)
   for i in 6:trigger(i)
 elif looping:
  if cycle>=0.95:cycle=fmod(cycle,0.95);trigger(0)
  elif cycle>=0.22 and cycle-dt<0.22:trigger(1)
func _process(dt:float)->void:
 if auto:
  var section=int(time/2.4)
  if section!=phase:
   phase=section;mode=0;alpha=phase==3;light=phase==4;move_host=phase==2;stress=phase>=5
   if phase==1:mode=1
   configure();apply_alpha();cycle=0.94;queue_redraw()
  advance(1.0/60.0)
 elif not paused:advance(dt)
 status.text="Body mix %.2f | duration %.2fs | 4 blood bursts / host; crowd 20 hits/s"%[amount,duration]
 if auto and capture!="":
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png(capture+"/frame_%05d.png"%frame);frame+=1
 if auto and time>=16.8:get_tree().quit()
func _draw()->void:
 draw_rect(Rect2(0,0,640,360),Color("a7aeb1") if light else Color("20272e"))
