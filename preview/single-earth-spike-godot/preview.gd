extends Node2D
const Single=preload("single.gd")
const Profile=preload("profile.gd")
const Floor=preload("fixture.gd")
const Hero=preload("character.gd")
var profile:Resource=Profile.new()
var views:Array[Node2D]=[]
var floors:Array[Node2D]=[]
var viewports:Array[SubViewport]=[]
var zoom_label:Label
var wide_view:bool=false
var time:float=0
var paused:bool=false
var cleared:bool=false
var updating:bool=false
var seed_value:int=17
var capture:bool=false
var frame:int=0
var speed:float=1
var timeline:HSlider
var status:Label
var phase:Label
var pause_button:Button
var speed_button:OptionButton
var sliders:Dictionary={}
func _ready()->void:
 get_window().size=Vector2i(1280,850); get_window().min_size=Vector2i(1280,850)
 label("E A R T H   /   S I N G L E   S P I R E",Vector2(28,22),25,Color("e5d8b9"))
 label("ASYMMETRIC ROCK  ·  SHORT BODY TREMOR  ·  IRREGULAR HARD FRACTURE",Vector2(29,60),12,Color("a19883"))
 label("01 / GAME SCALE · 1×",Vector2(29,147),13,Color("a7987e")); zoom_label=label("02 / SINGLE STONE · 4× NEAREST",Vector2(544,110),13,Color("a7987e"))
 for i in 2:
  var viewport:SubViewport=SubViewport.new(); viewport.size=Vector2i(360,240) if i==0 else Vector2i(160,120); viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; add_child(viewport); viewports.append(viewport)
  var floor_node:Node2D=Floor.new(); floor_node.z_index=-100; viewport.add_child(floor_node); floors.append(floor_node)
  var stage:Node2D=Node2D.new(); stage.y_sort_enabled=true; viewport.add_child(stage)
  var spike:Node2D=Single.new(); stage.add_child(spike); views.append(spike)
  if i==0:
   var hero:Node2D=Hero.new(); hero.position=Vector2(128,160); stage.add_child(hero)
  var panel:TextureRect=TextureRect.new(); panel.texture=viewport.get_texture(); panel.position=Vector2(28,176) if i==0 else Vector2(544,139); panel.size=Vector2(360,240) if i==0 else Vector2(640,480); panel.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST; add_child(panel)
 label("ONE STONE. NO RING.",Vector2(29,441),21,Color("d0a36c"))
 label("Whole rock snaps up through the ground",Vector2(29,481),14,Color("c1b59d"))
 label("Cracks spread · a short, small body tremor",Vector2(29,509),14,Color("c1b59d"))
 label("Unequal rigid chunks break, fall and settle",Vector2(29,537),14,Color("c1b59d"))
 button("Replay",Vector2(29,100),func(): replay()); button("New seed",Vector2(117,100),func(): seed_value+=1; replay(),94)
 pause_button=button("Pause",Vector2(29,580),func(): paused=not paused; pause_button.text="Resume" if paused else "Pause")
 button("Clear",Vector2(117,580),func(): cleared=true; for view in views: view.clear(); refresh())
 button("Light / Dark",Vector2(204,580),func(): toggle_floor(),110)
 button("Reset",Vector2(325,580),func(): profile=Profile.new(); configure(); sync(); replay(),65)
 speed_button=OptionButton.new(); speed_button.position=Vector2(29,632); speed_button.size=Vector2(143,32); speed_button.add_item("Speed 1×"); speed_button.add_item("Speed 0.3×"); add_child(speed_button); speed_button.item_selected.connect(func(i:int): speed=1 if i==0 else .3)
 status=label("",Vector2(544,634),13,Color("c1b59d")); phase=label("",Vector2(544,655),12,Color("a7987e"))
 timeline=HSlider.new(); timeline.position=Vector2(544,680); timeline.size=Vector2(640,18); timeline.step=.001; add_child(timeline); timeline.value_changed.connect(func(t:float):
  if not updating: paused=true; pause_button.text="Resume"; time=t; refresh())
 var specs:Array=[["Size","size",.6,1.5,.05],["Rise","rise_time",.025,.15,.005],["Hold","hold_time",.18,.9,.01],["Crack spread","crack_time",.04,.24,.01],["Break / fall","break_time",.25,.7,.01],["Shake px","shake_amount",0,2,.1],["Shake time","shake_time",.03,.18,.01],["Stagger","stagger",0,.12,.005],["Dirt chips","grit_density",0,2,.05],["Scatter","scatter",0,2,.1],["Rubble life","residue_lifetime",0,5,.1]]
 for i in specs.size():
  var spec:Array=specs[i]; var at:Vector2=Vector2(28+(i%6)*204,710+(i/6)*65)
  var txt:Label=label(spec[0],at,12,Color("a7987e"))
  var slider:HSlider=HSlider.new(); slider.position=at+Vector2(0,25); slider.size=Vector2(175,18); slider.min_value=spec[2]; slider.max_value=spec[3]; slider.step=spec[4]; add_child(slider)
  var key:String=spec[1]; sliders[key]={"slider":slider,"label":txt,"title":spec[0]}
  slider.value_changed.connect(func(v:float):
   if updating: return
   profile.set(key,v); profile=profile.clean(); configure(); sync(); replay())
 capture="--capture" in OS.get_cmdline_user_args(); configure(); sync(); replay()
func configure()->void:
 wide_view=profile.size*maxf(1.0,profile.scatter)>1.3
 viewports[1].size=Vector2i(320,240) if wide_view else Vector2i(160,120)
 zoom_label.text="02 / SINGLE STONE · 2× WIDE VIEW" if wide_view else "02 / SINGLE STONE · 4× NEAREST"
 for view in views: view.configure(profile)
func toggle_floor()->void:
 for f in floors: f.light_background=not f.light_background; f.queue_redraw()
func label(txt:String,at:Vector2,size:int,col:Color)->Label:
 var n:Label=Label.new(); n.text=txt; n.position=at; n.add_theme_font_size_override("font_size",size); n.modulate=col; add_child(n); return n
func button(txt:String,at:Vector2,action:Callable,width:float=78)->Button:
 var n:Button=Button.new(); n.text=txt; n.position=at; n.size=Vector2(width,31); add_child(n); n.pressed.connect(action); return n
func sync()->void:
 updating=true
 for key in sliders:
  var e:Dictionary=sliders[key]; e.slider.value=profile.get(key); e.label.text=e.title+"  "+str(snappedf(profile.get(key),.001))
 timeline.max_value=profile.lifetime()+.3; updating=false
func replay()->void:
 time=0; paused=false; cleared=false; pause_button.text="Pause"
 views[0].play(Vector2(196,160),seed_value); views[1].play(Vector2(160,180) if wide_view else Vector2(80,90),seed_value); refresh()
func refresh()->void:
 if not cleared:
  for view in views: view.seek(time)
 updating=true; timeline.value=time; updating=false
 status.text="t = %.3fs   /   single stone   /   seed %d   /   %.2f×"%[time,seed_value,speed]
 var age:float=time-.2; var fracture:float=profile.rise_time+profile.hold_time
 phase.text="Cleared" if cleared else "Waiting" if age<0 else "Fast whole-body emergence" if age<profile.rise_time else "Intact continuous rock faces" if age<fracture-profile.crack_time else "Cracks spreading / short body tremor" if age<fracture else "Staggered rigid pieces / falling" if age<fracture+profile.break_time else "Settled rubble" if time<profile.lifetime() else "Gone"
func _process(delta:float)->void:
 if capture:
  frame+=1; speed=1 if frame<240 else .3; speed_button.select(0 if frame<240 else 1)
  if frame==240: replay(); toggle_floor()
  if frame>=960: get_tree().quit(); return
 if not paused and not cleared:
  time+=(1.0/60 if capture else delta)*speed
  if time>profile.lifetime()+.5 and not capture: replay()
  refresh()
func _unhandled_key_input(event:InputEvent)->void:
 if event is InputEventKey and event.pressed and not event.echo:
  if event.keycode==KEY_ESCAPE: get_tree().quit()
  elif event.keycode==KEY_R: replay()
  elif event.keycode==KEY_SPACE: paused=not paused; pause_button.text="Resume" if paused else "Pause"
