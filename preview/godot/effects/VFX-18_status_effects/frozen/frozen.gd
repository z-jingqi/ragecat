extends Node2D
## Independent attached frozen status. Does not freeze gameplay or animation.
signal finished
var host:Sprite2D
var back:=Sprite2D.new()
var front:=Sprite2D.new()
var edge:Array[Vector2]=[]
var lower_edge:Array[Vector2]=[]
var mask:Image
var key:=""
var rect:=Rect2()
var sites:Array[Vector2]=[]
var crystals:Array=[]
var fragments:Array=[]
var phase:="idle"
var active:=false
var amount:=0.0
var elapsed:=0.0
var phase_age:=0.0
var hold_left:=0.0
var release_start:=1.0
var shed:=false
var strength:=0.40
var crystal_density:=0.065
var crystal_size:=4.2
var form_time:=0.5
var sustain_time:=1.8
var release_time:=0.6
var sweep_strength:=0.10
var mist_strength:=0.12
var seed_value:=41
var body_color:=Color("84bbdc")
var ice_color:=Color("76b1d3")
var facet_color:=Color("b1d8e8")
var edge_color:=Color("c4e1eb")
var crack_color:=Color("365c80")
var mist_color:=Color("638caa")
var base_color:=Color.WHITE
var last_color:=Color.WHITE
var owns_color:=false
const PAD=24
const LIMIT=128
const POOL_LIMIT=64
func _init()->void:
 add_child(back);add_child(front);back.z_index=-1;front.z_index=1
 back.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;front.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 back.centered=false;front.centered=false
 configure(JSON.parse_string(FileAccess.get_file_as_string("res://effects/VFX-18_status_effects/frozen/config.json")))
func number(v:Variant,f:float)->float:
 var n:=float(v) if v is int or v is float else f
 return n if is_finite(n) else f
func configure(p:Dictionary)->void:
 for name in ["body_color","ice_color","facet_color","edge_color","crack_color","mist_color"]:
  if p.has(name):set(name,Color.from_string(str(p[name]),get(name)))
 strength=clampf(number(p.get("intensity",strength),strength),0,0.7)
 crystal_density=clampf(number(p.get("crystal_density",crystal_density),crystal_density),0,0.3)
 crystal_size=clampf(number(p.get("crystal_size",crystal_size),crystal_size),1,7)
 form_time=clampf(number(p.get("form_time",form_time),form_time),0.05,3)
 sustain_time=clampf(number(p.get("sustain_time",sustain_time),sustain_time),0,60)
 release_time=clampf(number(p.get("release_time",release_time),release_time),0.15,3)
 sweep_strength=clampf(number(p.get("sweep_strength",sweep_strength),sweep_strength),0,0.3)
 mist_strength=clampf(number(p.get("mist_strength",mist_strength),mist_strength),0,0.4)
 seed_value=int(number(p.get("seed",seed_value),seed_value));key=""
 if active and refresh_mask():redraw_visual()
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
 key=k;rect=r;edge.clear();lower_edge.clear();crystals.clear();sites.clear()
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
 build_ice()
 return not edge.is_empty()
func alpha_at(x:int,y:int)->float:
 if x<0 or y<0 or x>=mask.get_width() or y>=mask.get_height():return 0
 return mask.get_pixel(x,y).a
func noise(x:float,y:float)->float:
 return fposmod(sin(x*12.9898+y*78.233+seed_value*0.731)*43758.5453,1.0)
func build_ice()->void:
 var rng:=RandomNumberGenerator.new();rng.seed=seed_value
 if edge.is_empty():return
 for i in range(8):sites.append(Vector2(rng.randf()*mask.get_width(),rng.randf()*mask.get_height()))
 var count:=mini(24,int(edge.size()*crystal_density))
 for i in range(count):
  var p:Vector2=edge[int(float(i)/maxi(count,1)*edge.size())]
  var n:=Vector2(float(alpha_at(int(p.x)-1,int(p.y))-alpha_at(int(p.x)+1,int(p.y))),float(alpha_at(int(p.x),int(p.y)-1)-alpha_at(int(p.x),int(p.y)+1)))
  if n.length()<0.1:n=(p-Vector2(mask.get_width(),mask.get_height())*0.5).normalized()
  crystals.append({"p":p,"dir":n.normalized().rotated(rng.randf_range(-0.35,0.35)),"size":crystal_size*rng.randf_range(0.65,1.35),"phase":rng.randf()})
func play(seconds:float=-1)->bool:
 if seconds==-1:seconds=sustain_time
 if not is_finite(seconds) or seconds<0 or not refresh_mask():return false
 hold_left=minf(seconds,60)
 if not active:
  elapsed=0;amount=0;phase_age=0;phase="forming";fragments.clear();shed=false;active=true
 elif phase=="releasing":
  phase="forming";phase_age=amount*form_time;fragments.clear();shed=false
 redraw_visual();return true
func cancel(immediate:bool=false)->void:
 if immediate:clear()
 elif active and phase!="releasing":begin_release()
func begin_release()->void:
 phase="releasing";phase_age=0;release_start=amount;shed=false
func clear()->void:
 active=false;phase="idle";amount=0;phase_age=0;elapsed=0;fragments.clear();shed=false
 back.texture=null;front.texture=null;restore()
func restore()->void:
 if owns_color and is_instance_valid(host) and host.self_modulate.is_equal_approx(last_color):host.self_modulate=base_color
 owns_color=false
func _exit_tree()->void:restore()
func tick(dt:float)->void:
 if not is_finite(dt) or dt<=0 or not active:return
 if not is_instance_valid(host) or not refresh_mask():clear();host=null;return
 elapsed+=dt
 for p in fragments:p.age+=dt
 fragments=fragments.filter(func(p):return p.age<p.life)
 var left:=dt
 while left>0.000001 and active:
  if phase=="forming":
   var step:=minf(left,maxf(0,form_time-phase_age));phase_age+=step;left-=step;amount=clampf(phase_age/form_time,0,1)
   if phase_age>=form_time-0.000001:phase="holding";phase_age=0;amount=1
  elif phase=="holding":
   var step:=minf(left,hold_left);hold_left-=step;left-=step;phase_age+=step
   if hold_left<=0.000001:begin_release()
  elif phase=="releasing":
   phase_age+=left;left=0
   var u:=clampf(phase_age/release_time,0,1)
   amount=release_start*(1-smoothstep(0.16,0.86,u))
   if u>=0.18 and not shed:release_fragments();shed=true
   if u>=1:clear();finished.emit();return
 redraw_visual()
func release_fragments()->void:
 for c in crystals:
  if fragments.size()>=POOL_LIMIT:break
  if coverage(c.p,release_start)<0.2:continue
  fragments.append({"p":c.p,"dir":c.dir,"size":c.size,"age":0.0,"life":release_time*0.75,"velocity":c.dir*(6+c.size*2)+Vector2(0,-8)})
func coverage(p:Vector2,level:float)->float:
 var height:=float(mask.get_height())
 var wobble:=sin(p.x*0.8)*1.3+noise(floor(p.x/3),floor(p.y/3))*2.0
 return clampf((p.y-(1-level)*(height+6)+3+wobble)/3,0,1)*clampf(level*8,0,1)
func pixel(im:Image,x:int,y:int,c:Color)->void:
 if x<0 or y<0 or x>=im.get_width() or y>=im.get_height() or c.a<=0:return
 im.set_pixel(x,y,im.get_pixel(x,y).blend(c))
func line(im:Image,a:Vector2,b:Vector2,c:Color)->void:
 var steps:=maxi(1,ceili(a.distance_to(b)))
 for i in range(steps+1):
  var p:=a.lerp(b,float(i)/steps);pixel(im,roundi(p.x),roundi(p.y),c)
func shard(im:Image,p:Vector2,d:Vector2,size:float,opacity:float)->void:
 # Short unequal faceted crystals, not regular radial spikes.
 var side:=d.orthogonal();var tip:=p+d*size
 for i in range(ceili(size)+1):
  var u:=float(i)/maxf(size,1);var width:=maxf(0,1-u)*size*0.42
  for j in range(-ceili(width),ceili(width)+1):
   var q:=p+d*i+side*j
   pixel(im,roundi(q.x),roundi(q.y),Color(facet_color if j<0 else ice_color,opacity))
 line(im,p,tip,Color(edge_color,opacity*0.55))
func redraw_visual()->void:
 if not active or not is_instance_valid(host):return
 if not owns_color:base_color=host.self_modulate;last_color=base_color;owns_color=true
 elif not host.self_modulate.is_equal_approx(last_color):base_color=host.self_modulate
 var tint:=Color.WHITE.lerp(body_color,strength*amount*0.65)
 last_color=Color(base_color.r*tint.r,base_color.g*tint.g,base_color.b*tint.b,base_color.a);host.self_modulate=last_color
 global_transform=host.global_transform;z_index=host.z_index;z_as_relative=host.z_as_relative
 back.visible=host.is_visible_in_tree();front.visible=back.visible
 var size:=Vector2i(mask.get_width()+PAD*2,mask.get_height()+PAD*2)
 var a:=Image.create(size.x,size.y,false,Image.FORMAT_RGBA8);var b:=Image.create(size.x,size.y,false,Image.FORMAT_RGBA8)
 var opacity:=clampf(strength/0.5,0,1)*host.modulate.a*base_color.a
 var thaw:float=clampf(phase_age/release_time,0,1) if phase=="releasing" else 0.0
 var sweep:=fposmod(elapsed*0.35+float(seed_value%17)/17,1.0)*(mask.get_width()+mask.get_height())
 for y in range(mask.get_height()):
  for x in range(mask.get_width()):
   var source:=mask.get_pixel(x,y)
   # Keep antialiased partial-alpha edges and transparent holes untouched by the crust.
   if source.a<0.999:continue
   var p:=Vector2(x,y);var fill:=coverage(p,amount)
   if fill<=0:continue
   var near:=100000.0;var second:=100000.0;var cell:=0
   for i in range(sites.size()):
    var dist:=p.distance_squared_to(sites[i])
    if dist<near:second=near;near=dist;cell=i
    elif dist<second:second=dist
   var border:float=1.0 if sqrt(second)-sqrt(near)<0.65 else 0.0
   var facet:=noise(cell,3)
   var c:=ice_color.lerp(facet_color,facet*0.7)
   var light:=source.get_luminance()
   c=c.darkened((1-light)*0.25)
   var alpha:=opacity*fill*(0.35+facet*0.35)
   var glint:=maxf(0,1-absf(float(x+y)-sweep)/2)*sweep_strength
   c=c.lerp(edge_color,glint)
   if thaw>0.03 and border>0:
    c=crack_color;alpha*=clampf(thaw*8,0,1)
   pixel(b,x+PAD,y+PAD,Color(c,alpha))
 for p in edge:
  if alpha_at(int(p.x),int(p.y))<0.999:continue
  var cov:=coverage(p,amount)
  var broken:=0.55+noise(p.x,p.y)*0.45
  pixel(b,int(p.x)+PAD,int(p.y)+PAD,Color(edge_color,opacity*cov*broken*0.65))
 if not shed:
  for c in crystals:
   var cov:=coverage(c.p,amount)
   if cov>0:shard(b,c.p+Vector2(PAD,PAD),c.dir,c.size*cov,opacity*cov*0.75)
 for p in fragments:
  var u:float=p.age/p.life
  var pos:Vector2=p.p+p.velocity*p.age+Vector2(0,45*p.age*p.age)+Vector2(PAD,PAD)
  shard(b,pos,p.dir.rotated(p.age*2),p.size*(1-u*0.6),opacity*(1-u)*0.65)
 # Low, separated cold puffs. Stable motion, no full-body brightness pulses.
 for i in range(5):
  var u:=fposmod(elapsed*0.5+i*0.21+seed_value*0.03,1)
  var x:=float(mask.get_width())*(float(i)+0.5)/5+sin(u*3+i)*3
  var y:=float(mask.get_height())-2-u*3
  var radius:=1+int(u*3)
  for yy in range(-radius,radius+1):
   for xx in range(-radius,radius+1):
    if xx*xx+yy*yy<=radius*radius:pixel(a,roundi(x)+PAD+xx,roundi(y)+PAD+yy,Color(mist_color,opacity*amount*sin(PI*u)*mist_strength))
 back.position=rect.position-Vector2(PAD,PAD);front.position=back.position
 if back.texture==null or back.texture.get_size()!=Vector2(size):back.texture=ImageTexture.create_from_image(a);front.texture=ImageTexture.create_from_image(b)
 else:back.texture.update(a);front.texture.update(b)
