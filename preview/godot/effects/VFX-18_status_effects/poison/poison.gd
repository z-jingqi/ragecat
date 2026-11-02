extends Node2D
## Independent attached poison. No damage ticks or gameplay mutation.
signal finished
var host:Sprite2D
var back:=Sprite2D.new()
var front:=Sprite2D.new()
var rng:=RandomNumberGenerator.new()
var particles:Array=[]
var edge:Array[Vector2]=[]
var lower_edge:Array[Vector2]=[]
var mask:Image
var key:=""
var rect:=Rect2()
var elapsed:=0.0
var remaining:=0.0
var fade_age:=-1.0
var active:=false
var strength:=0.32
var bubble_rate:=10.0
var drip_rate:=5.0
var gas_rate:=3.0
var bubble_size:=2.4
var rise_speed:=10.0
var gravity:=32.0
var pulse_period:=0.9
var pulse_strength:=0.14
var enter_time:=0.14
var exit_time:=0.35
var seed_value:=27
var bubble_color:=Color("82b54b")
var highlight_color:=Color("c4d980")
var drip_color:=Color("6d982e")
var gas_color:=Color("3c6037")
var rim_color:=Color("619139")
var body_color:=Color("98d858") # Backward-compatible palette alias.
var tint_color:=Color("70e880")
var tint_strength:=0.42
var accum:=Vector3.ZERO
var pulse_clock:=0.0
var pulse_age:=10.0
var base_color:=Color.WHITE
var last_color:=Color.WHITE
var owns_color:=false
const PAD=24
const LIMIT=128
const POOL_LIMIT=128
func _init()->void:
 add_child(back);add_child(front)
 back.z_index=-1;front.z_index=1
 back.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;front.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 back.centered=false;front.centered=false
 configure(JSON.parse_string(FileAccess.get_file_as_string("res://effects/VFX-18_status_effects/poison/config.json")))
func number(v:Variant,f:float)->float:
 var n:=float(v) if v is int or v is float else f
 return n if is_finite(n) else f
func configure(p:Dictionary)->void:
 for name in ["bubble_color","highlight_color","drip_color","gas_color","rim_color","body_color"]:
  if p.has(name):set(name,Color.from_string(str(p[name]),get(name)))
 for name in ["bubble_rate","drip_rate","gas_rate"]:set(name,clampf(number(p.get(name,get(name)),get(name)),0,40))
 if p.has("tint_color"):tint_color=Color.from_string(str(p.tint_color),tint_color)
 elif p.has("body_color"):tint_color=body_color
 tint_strength=clampf(number(p.get("tint_strength",tint_strength),tint_strength),0,0.65)
 strength=clampf(number(p.get("intensity",strength),strength),0,0.7)
 bubble_size=clampf(number(p.get("bubble_size",bubble_size),bubble_size),1,5)
 rise_speed=clampf(number(p.get("rise_speed",rise_speed),rise_speed),1,24)
 gravity=clampf(number(p.get("gravity",gravity),gravity),0,80)
 pulse_period=clampf(number(p.get("pulse_period",pulse_period),pulse_period),0.3,3)
 pulse_strength=clampf(number(p.get("pulse_strength",pulse_strength),pulse_strength),0,0.4)
 enter_time=clampf(number(p.get("enter_time",enter_time),enter_time),0.02,1)
 exit_time=clampf(number(p.get("exit_time",exit_time),exit_time),0.03,2)
 seed_value=int(number(p.get("seed",seed_value),seed_value))
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
 key=k;rect=r;edge.clear();lower_edge.clear()
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
 for p in edge:
  if alpha_at(int(p.x),int(p.y)+1)<0.15:lower_edge.append(p)
 return not edge.is_empty()
func alpha_at(x:int,y:int)->float:
 if x<0 or y<0 or x>=mask.get_width() or y>=mask.get_height():return 0
 return mask.get_pixel(x,y).a
func play(seconds:float=3)->bool:
 if not is_finite(seconds) or seconds<=0 or not refresh_mask():return false
 if not active:
  elapsed=0;accum=Vector3.ZERO;rng.seed=seed_value;particles.clear();pulse_clock=float(seed_value%101)/101*pulse_period;pulse_age=10
 remaining=minf(seconds,60);fade_age=-1;active=true;redraw_visual();return true
func cancel(immediate:bool=false)->void:
 if immediate:clear()
 elif active:remaining=0;fade_age=0
func clear()->void:
 active=false;particles.clear();elapsed=0;remaining=0;fade_age=-1;accum=Vector3.ZERO;pulse_age=10
 back.texture=null;front.texture=null;restore()
func restore()->void:
 if owns_color and is_instance_valid(host) and host.self_modulate.is_equal_approx(last_color):host.self_modulate=base_color
 owns_color=false
func _exit_tree()->void:restore()
func tick(dt:float)->void:
 if not is_finite(dt) or dt<=0 or not active:return
 if not is_instance_valid(host) or not refresh_mask():clear();host=null;return
 elapsed+=dt;pulse_age+=dt
 if fade_age>=0:fade_age+=dt
 else:
  var excess:=maxf(0,dt-remaining);remaining=maxf(0,remaining-dt)
  if remaining<=0.000001:fade_age=excess
 for p in particles:p.age+=dt
 particles=particles.filter(func(p):return p.age<p.life)
 if fade_age<0:
  accum+=Vector3(bubble_rate,drip_rate,gas_rate)*dt
  for kind in range(3):
   var n:=mini(int(accum[kind]),POOL_LIMIT);accum[kind]-=floor(accum[kind])
   for i in range(n):spawn(kind)
  pulse_clock+=dt
  if pulse_clock>=pulse_period:
   pulse_clock=fposmod(pulse_clock,pulse_period);pulse_age=0
   if pulse_strength>0:
    if bubble_rate>0:spawn(0);spawn(0)
    if drip_rate>0:spawn(1)
 if fade_age>=exit_time:clear();finished.emit();return
 redraw_visual()
func spawn(kind:int)->void:
 if edge.is_empty() or particles.size()>=POOL_LIMIT:return
 var origins:=lower_edge if kind==1 and not lower_edge.is_empty() else edge
 var pos:Vector2=origins[rng.randi_range(0,origins.size()-1)]
 particles.append({"p":pos,"age":0.0,"life":rng.randf_range(0.65,1.25) if kind!=1 else rng.randf_range(0.45,0.8),"r":rng.randf_range(0.65,1.25)*bubble_size,"phase":rng.randf()*TAU,"kind":kind,"side":rng.randf_range(-1,1)})
func pixel(im:Image,x:int,y:int,c:Color)->void:
 if x<0 or y<0 or x>=im.get_width() or y>=im.get_height() or c.a<=0:return
 im.set_pixel(x,y,im.get_pixel(x,y).blend(c))
func redraw_visual()->void:
 if not active or not is_instance_valid(host):return
 if not owns_color:base_color=host.self_modulate;last_color=base_color;owns_color=true
 elif not host.self_modulate.is_equal_approx(last_color):base_color=host.self_modulate
 var weight:float=minf(elapsed/enter_time,1.0)*(1-clampf(fade_age/exit_time,0,1) if fade_age>=0 else 1)
 var pulse:float=pow(maxf(0,1-pulse_age/0.28),2)*pulse_strength
 var tint:=Color.WHITE.lerp(tint_color,tint_strength*weight) # Continuous state, independent of particles/pulse.
 last_color=Color(base_color.r*tint.r,base_color.g*tint.g,base_color.b*tint.b,base_color.a);host.self_modulate=last_color
 global_transform=host.global_transform;z_index=host.z_index;z_as_relative=host.z_as_relative
 back.visible=host.is_visible_in_tree();front.visible=back.visible
 var size:=Vector2i(mask.get_width()+PAD*2,mask.get_height()+PAD*2)
 var a:=Image.create(size.x,size.y,false,Image.FORMAT_RGBA8);var b:=Image.create(size.x,size.y,false,Image.FORMAT_RGBA8)
 var opacity:float=weight*clampf(strength/0.4,0,1)*host.modulate.a*base_color.a
 # Intermittent damp rim follows alpha, never a solid green box or full-body flash.
 for p in edge:
  var n:=sin(p.x*0.61+p.y*0.31+elapsed*2+seed_value)
  if n>0.3:pixel(b,int(p.x)+PAD,int(p.y)+PAD,Color(rim_color,opacity*(0.18+pulse)*(n-0.3)))
 for p in particles:
  var u:float=p.age/p.life
  var origin:Vector2=p.p+Vector2(PAD,PAD)
  var env:float=sin(PI*u)
  var pos:Vector2=origin
  if p.kind==0:
   pos+=Vector2(sin(p.phase+p.age*3)*2+p.side*u*3,-p.age*rise_speed)
   var radius:float=p.r*(0.65+u*0.65)
   var ir:=ceili(radius)
   for y in range(-ir,ir+1):
    for x in range(-ir,ir+1):
     var distance:=Vector2(x,y).length()
     if absf(distance-radius)<0.55 and not (u>0.84 and (x+y)%3==0):
      pixel(b,roundi(pos.x)+x,roundi(pos.y)+y,Color(highlight_color if x<0 and y<0 else bubble_color,opacity*env*0.8))
   if u>0.88:
    for sign in [-1,1]:pixel(b,roundi(pos.x)+sign*(ir+1),roundi(pos.y)-1,Color(bubble_color,opacity*(1-u)*5))
  elif p.kind==1:
   var floor_y:=float(mask.get_height()+PAD-1)
   pos+=Vector2(p.side*p.age*3,p.age*3+gravity*p.age*p.age*0.5)
   if pos.y>=floor_y:
    var spread:=1+int(u*3)
    for x in range(-spread,spread+1):pixel(b,roundi(pos.x)+x,int(floor_y),Color(drip_color,opacity*env*0.55))
   else:
    pixel(b,roundi(pos.x),roundi(pos.y),Color(drip_color,opacity*env))
    pixel(b,roundi(pos.x),roundi(pos.y)-1,Color(highlight_color,opacity*env*0.6))
    if u>0.3:pixel(b,roundi(pos.x),roundi(pos.y)-2,Color(drip_color,opacity*env*0.45))
  else:
   pos+=Vector2(sin(p.phase+p.age*2)*3,-p.age*rise_speed*0.35)
   var r:=1+int(u*3)
   for y in range(-r,r+1):
    for x in range(-r,r+1):
     if x*x+y*y<=r*r:pixel(a,roundi(pos.x)+x,roundi(pos.y)+y,Color(gas_color,opacity*env*0.22))
 back.position=rect.position-Vector2(PAD,PAD);front.position=back.position
 if back.texture==null or back.texture.get_size()!=Vector2(size):back.texture=ImageTexture.create_from_image(a);front.texture=ImageTexture.create_from_image(b)
 else:back.texture.update(a);front.texture.update(b)
