extends Node2D
## Standalone alpha-sampled burning visual. Gameplay owns damage and status rules.
signal finished
var host: Sprite2D
var back:=Sprite2D.new()
var front:=Sprite2D.new()
var rng:=RandomNumberGenerator.new()
var particles:Array=[]
var edge:Array[Vector2]=[]
var mask:Image
var key:=""
var rect:=Rect2()
var elapsed:=0.0
var remaining:=0.0
var fade_age:=-1.0
var emit_acc:=0.0
var active:=false
var strength:=0.32
var density:=54.0
var flame_height:=11.0
var rise_speed:=12.0
var smoke_amount:=0.32
var ember_amount:=0.35
var enter_time:=0.12
var exit_time:=0.30
var seed_value:=18
var warm:=Color("ed8839")
var core_color:=Color("f9bb60")
var edge_color:=Color("6b3d1a")
var smoke_color:=Color("1f1a1c")
var ember_color:=Color("f2ac74")
var body_color:=Color("ff9966")
var base_color:=Color.WHITE
var last_color:=Color.WHITE
var owns_color:=false
const PAD=24
const LIMIT=128
const POOL_LIMIT=160
func _init()->void:
 add_child(back);add_child(front)
 back.z_index=-1;front.z_index=1
 back.z_as_relative=true;front.z_as_relative=true
 back.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;front.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 back.centered=false;front.centered=false
 configure(JSON.parse_string(FileAccess.get_file_as_string("res://effects/VFX-18_status_effects/burning/config.json")))
func number(v:Variant,f:float)->float:
 var n:=float(v) if v is int or v is float else f
 return n if is_finite(n) else f
func configure(p:Dictionary)->void:
 strength=clampf(number(p.get("intensity",strength),strength),0,0.7)
 density=clampf(number(p.get("density",density),density),0,80)
 flame_height=clampf(number(p.get("flame_height",flame_height),flame_height),2,20)
 rise_speed=clampf(number(p.get("rise_speed",rise_speed),rise_speed),1,32)
 smoke_amount=clampf(number(p.get("smoke",smoke_amount),smoke_amount),0,1)
 ember_amount=clampf(number(p.get("embers",ember_amount),ember_amount),0,1)
 enter_time=clampf(number(p.get("enter_time",enter_time),enter_time),0.02,1)
 exit_time=clampf(number(p.get("exit_time",exit_time),exit_time),0.03,2)
 seed_value=int(number(p.get("seed",seed_value),seed_value))
 if p.has("color"):warm=Color.from_string(str(p.color),warm)
 if p.has("core_color"):core_color=Color.from_string(str(p.core_color),core_color)
 if p.has("edge_color"):edge_color=Color.from_string(str(p.edge_color),edge_color)
 if p.has("smoke_color"):smoke_color=Color.from_string(str(p.smoke_color),smoke_color)
 if p.has("ember_color"):ember_color=Color.from_string(str(p.ember_color),ember_color)
 if p.has("body_color"):body_color=Color.from_string(str(p.body_color),body_color)
 redraw_visual()
func bind_host(s:Sprite2D)->bool:
 clear();restore();host=s;key=""
 if not is_instance_valid(host):return false
 base_color=host.self_modulate;last_color=base_color;owns_color=true
 return refresh_mask()
func invalidate_mask()->void:key=""
func refresh_mask()->bool:
 if not is_instance_valid(host) or host.texture==null:return false
 var r:=host.get_rect()
 if r.size.x<1 or r.size.y<1 or r.size.x>LIMIT or r.size.y>LIMIT:return false
 var k:=str([host.texture.get_rid(),host.frame,host.hframes,host.vframes,host.region_enabled,host.region_rect,host.flip_h,host.flip_v,r])
 if key==k:return not edge.is_empty()
 key=k;rect=r;edge.clear()
 var source:=host.texture.get_image()
 if source==null:return false
 if source.is_compressed():source.decompress()
 var crop:=host.region_rect if host.region_enabled else Rect2(0,0,source.get_width(),source.get_height())
 var size:=Vector2i(roundi(r.size.x),roundi(r.size.y))
 var cell:=crop.size/Vector2(host.hframes,host.vframes)
 var origin:=crop.position+Vector2(host.frame%host.hframes,floori(float(host.frame)/host.hframes))*cell
 mask=Image.create(size.x,size.y,false,Image.FORMAT_RGBA8)
 for y in range(size.y):
  for x in range(size.x):
   var sx:=size.x-1-x if host.flip_h else x
   var sy:=size.y-1-y if host.flip_v else y
   var q:=Vector2i(origin+Vector2(sx,sy))
   if q.x>=0 and q.y>=0 and q.x<source.get_width() and q.y<source.get_height():mask.set_pixel(x,y,source.get_pixel(q.x,q.y))
 for y in range(size.y):
  for x in range(size.x):
   if alpha_at(x,y)<0.15:continue
   if alpha_at(x-1,y)<0.15 or alpha_at(x+1,y)<0.15 or alpha_at(x,y-1)<0.15 or alpha_at(x,y+1)<0.15:edge.append(Vector2(x,y))
 return not edge.is_empty()
func alpha_at(x:int,y:int)->float:
 if x<0 or y<0 or x>=mask.get_width() or y>=mask.get_height():return 0
 return mask.get_pixel(x,y).a
func play(seconds:float=3)->bool:
 if not is_finite(seconds) or seconds<=0 or not refresh_mask():return false
 if not active:
  elapsed=0;emit_acc=0;rng.seed=seed_value;particles.clear()
 remaining=minf(seconds,60);fade_age=-1;active=true;redraw_visual();return true
func cancel(immediate:bool=false)->void:
 if immediate:clear()
 elif active:remaining=0;fade_age=0
func clear()->void:
 active=false;particles.clear();elapsed=0;remaining=0;fade_age=-1
 back.texture=null;front.texture=null;restore()
func restore()->void:
 if owns_color and is_instance_valid(host) and host.self_modulate.is_equal_approx(last_color):host.self_modulate=base_color
 owns_color=false
func _exit_tree()->void:restore()
func tick(dt:float)->void:
 if not is_finite(dt) or dt<=0:return
 if not active:return
 if not is_instance_valid(host) or not refresh_mask():clear();host=null;return
 elapsed+=dt
 if fade_age>=0:fade_age+=dt
 else:
  var excess:=maxf(0,dt-remaining);remaining=maxf(0,remaining-dt)
  if remaining<=0.000001:fade_age=excess
 for p in particles:p.age+=dt
 particles=particles.filter(func(p):return p.age<p.life)
 if fade_age<0:
  emit_acc+=dt*density
  var births:=mini(int(emit_acc),POOL_LIMIT)
  emit_acc-=floor(emit_acc)
  for i in range(births):spawn()
 if fade_age>=exit_time:
  clear();finished.emit();return
 redraw_visual()
func spawn()->void:
 if edge.is_empty() or particles.size()>=POOL_LIMIT:return
 var p:=edge[rng.randi_range(0,edge.size()-1)]
 var kind:=0
 var choice:=rng.randf()
 if choice<smoke_amount*0.22:kind=1
 elif choice<smoke_amount*0.22+ember_amount*0.25:kind=2
 particles.append({"p":p,"age":0.0,"life":rng.randf_range(0.34,0.72) if kind==0 else rng.randf_range(0.5,1.05),"height":rng.randf_range(0.55,1.15)*flame_height,"width":rng.randf_range(2.0,3.8),"phase":rng.randf()*TAU,"kind":kind,"side":rng.randf_range(-1,1)})
func pixel(im:Image,x:int,y:int,c:Color)->void:
 if x<0 or y<0 or x>=im.get_width() or y>=im.get_height() or c.a<=0:return
 im.set_pixel(x,y,im.get_pixel(x,y).blend(c))
func redraw_visual()->void:
 if not active or not is_instance_valid(host):return
 if not owns_color:base_color=host.self_modulate;last_color=base_color;owns_color=true
 elif not host.self_modulate.is_equal_approx(last_color):base_color=host.self_modulate
 var weight:float=minf(elapsed/enter_time,1.0)*(1-clampf(fade_age/exit_time,0,1) if fade_age>=0 else 1)
 var heat:float=strength*weight*0.22
 var body_tint:=Color.WHITE.lerp(body_color,heat)
 last_color=Color(base_color.r*body_tint.r,base_color.g*body_tint.g,base_color.b*body_tint.b,base_color.a);host.self_modulate=last_color
 global_transform=host.global_transform
 z_index=host.z_index;z_as_relative=host.z_as_relative
 var visible_host:=host.is_visible_in_tree()
 back.visible=visible_host;front.visible=visible_host
 var size:=Vector2i(mask.get_width()+PAD*2,mask.get_height()+PAD*2)
 var a:=Image.create(size.x,size.y,false,Image.FORMAT_RGBA8);var b:=Image.create(size.x,size.y,false,Image.FORMAT_RGBA8)
 var opacity:float=weight*clampf(strength/0.4,0,1)*host.modulate.a*base_color.a
 # A sparse living edge, never a full bright silhouette or a bounding rectangle.
 for p in edge:
  var pulse:=sin(p.x*0.83+p.y*0.47-elapsed*9)
  var surge:=sin(p.x*0.43+p.y*0.31-elapsed*8+seed_value)+sin(p.x*0.81-p.y*0.19-elapsed*11)*0.5
  var tongue:=1+int(maxf(surge,0)*4)
  for dy in range(-tongue,2):
   for dx in range(-1,2):
    var q:=Vector2i(p)+Vector2i(dx,dy)
    if alpha_at(q.x,q.y)<0.15:
     var rim_color:=warm if surge>0.25 and dy<0 else edge_color
     pixel(a,q.x+PAD,q.y+PAD,Color(rim_color,opacity*(0.7 if surge>0.25 else 0.28)))
  if pulse>0.2:pixel(b,int(p.x)+PAD,int(p.y)+PAD,Color(warm,opacity*0.42*(pulse-0.2)))
 for p in particles:
  var u:float=p.age/p.life
  var origin:Vector2=p.p+Vector2(PAD,PAD)
  var envelope:float=sin(PI*u)
  var dx:float=sin(p.phase+p.age*8)*1.4+p.side*u*2
  var pos:=origin+Vector2(dx,-p.age*rise_speed)
  if p.kind==0:
   pos.y=origin.y-p.age*rise_speed*0.35
   var height:float=p.height*envelope
   for y in range(maxi(1,int(height))):
    var t:float=float(y)/maxf(height,1)
    var width:float=p.width*(1-t)*envelope
    var cx:=int(pos.x+sin(p.phase+t*3+p.age*7)*t*2)
    for x in range(-ceili(width),ceili(width)+1):
     if absf(x)>width:continue
     var c:=edge_color if absf(x)>width*0.55 else warm
     pixel(a,cx+x,int(pos.y)-y,Color(c,opacity*envelope))
     if p.phase>PI and t<0.82:pixel(b,cx+x,int(pos.y)-y,Color(c,opacity*envelope*0.65))
     if t<0.4 and absf(x)<width*0.45:pixel(b,cx+x,int(pos.y)-y,Color(core_color,opacity*envelope*0.8))
  elif p.kind==1:
   var r:=1+int(u*2)
   for y in range(-r,r+1):
    for x in range(-r,r+1):
     if x*x+y*y<=r*r:pixel(a,int(pos.x)+x,int(pos.y)+y,Color(smoke_color,opacity*envelope*0.3))
  else:
   pixel(b,int(pos.x),int(pos.y),Color(ember_color,opacity*envelope*0.75))
 back.position=rect.position-Vector2(PAD,PAD);front.position=back.position
 if back.texture==null or back.texture.get_size()!=Vector2(size):back.texture=ImageTexture.create_from_image(a);front.texture=ImageTexture.create_from_image(b)
 else:back.texture.update(a);front.texture.update(b)
