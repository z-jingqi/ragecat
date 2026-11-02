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
var shell_pixels:Array=[]
var panel_centers:Array[Vector2]=[]
var plates:Array=[]
var phase:="idle"
var active:=false
var amount:=0.0
var elapsed:=0.0
var phase_age:=0.0
var hold_left:=0.0
var release_start:=1.0
var shed:=false
var strength:=0.40
var plate_count:=5
var plate_scale:=1.0
var shell_thickness:=1.0
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
 plate_count=clampi(int(number(p.get("plate_count",plate_count),plate_count)),0,5)
 plate_scale=clampf(number(p.get("plate_scale",plate_scale),plate_scale),0.5,1.5)
 shell_thickness=clampf(number(p.get("shell_thickness",shell_thickness),shell_thickness),0.4,1.2)
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
 key=k;rect=r;edge.clear();lower_edge.clear();crystals.clear();sites.clear();shell_pixels.clear();panel_centers.clear();plates.clear()
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
 # Stratified irregular sites produce large oblique panels instead of flat fill.
 var w:=float(mask.get_width());var h:=float(mask.get_height())
 for row in range(4):
  for col in range(3):sites.append(Vector2((col+rng.randf_range(0.1,0.9))*w/3,(row+rng.randf_range(0.1,0.9))*h/4))
 var sums:Array[Vector2]=[];var counts:Array[int]=[]
 for i in range(sites.size()):sums.append(Vector2.ZERO);counts.append(0);panel_centers.append(Vector2.ZERO)
 for y in range(-3,mask.get_height()+3):
  for x in range(-3,mask.get_width()+3):
   var pos:=Vector2(x,y);var source:=Color.TRANSPARENT;var nearest_source:=pos;var dist:=999.0
   if alpha_at(x,y)>=0.999:source=mask.get_pixel(x,y);dist=0
   else:
    for yy in range(-3,4):
     for xx in range(-3,4):
      var dd:=float(xx*xx+yy*yy)
      if dd<dist and alpha_at(x+xx,y+yy)>=0.999:dist=dd;source=mask.get_pixel(x+xx,y+yy);nearest_source=pos+Vector2(xx,yy)
   var thickness:float=(1.0+noise(floor(x/5.0),floor(y/5.0))*1.4)*shell_thickness
   if dist>thickness*thickness:continue
   # Preserve genuine interior holes; outer ice may thicken silhouette but not fill cavities.
   if x>=0 and y>=0 and x<mask.get_width() and y<mask.get_height() and alpha_at(x,y)<0.15:
    if alpha_at(x-1,y)>0.5 and alpha_at(x+1,y)>0.5 and alpha_at(x,y-1)>0.5 and alpha_at(x,y+1)>0.5:continue
   var near:=100000.0;var second:=100000.0;var cell:=0
   for i in range(sites.size()):
    var d:=pos.distance_squared_to(sites[i])
    if d<near:second=near;near=d;cell=i
    elif d<second:second=d
   var border:=sqrt(second)-sqrt(near)
   shell_pixels.append({"p":pos,"cell":cell,"border":border,"outside":dist>0,"source":source,"nearest":nearest_source})
   sums[cell]+=pos;counts[cell]+=1
 for i in range(sites.size()):panel_centers[i]=sums[i]/maxi(counts[i],1)
 # Unequal front slabs introduce readable refractive planes across the body detail.
 for uv in [Vector2(0.46,0.43),Vector2(0.57,0.57),Vector2(0.37,0.77),Vector2(0.64,0.80),Vector2(0.23,0.57)]:
  if plates.size()>=plate_count:break
  var desired:Vector2=Vector2(w,h)*uv;var anchor:=Vector2.ZERO;var best:=100000.0
  for y in range(mask.get_height()):
   for x in range(mask.get_width()):
    if alpha_at(x,y)<0.999:continue
    var q:=Vector2(x,y);var dd:=q.distance_squared_to(desired)
    if dd<best:best=dd;anchor=q
  var size:=Vector2(clampf(w*0.13,4,9),clampf(h*0.15,5,12))*rng.randf_range(0.85,1.15)*plate_scale
  plates.append({"p":anchor,"size":size,"angle":rng.randf_range(-0.5,0.4),"delay":rng.randf_range(0.10,0.25),"side":rng.randf_range(-1,1)})
 # Few grouped plates, not spikes scattered around the entire outline.
 var groups:=mini(5,int(edge.size()*crystal_density/3))
 for g in range(groups):
  var origin:Vector2=edge[rng.randi_range(0,edge.size()-1)]
  var normal:=Vector2(alpha_at(int(origin.x)-1,int(origin.y))-alpha_at(int(origin.x)+1,int(origin.y)),alpha_at(int(origin.x),int(origin.y)-1)-alpha_at(int(origin.x),int(origin.y)+1)).normalized()
  if normal.length()<0.1:normal=Vector2.UP
  for j in range(2):
   crystals.append({"p":origin+normal.orthogonal()*(j*2-1),"dir":normal.rotated((j-0.5)*0.6),"size":crystal_size*rng.randf_range(0.7,1.2),"phase":rng.randf()})
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
func triangle(im:Image,aa:Vector2,bb:Vector2,cc:Vector2,color:Color)->void:
 var points:=PackedVector2Array([aa,bb,cc])
 for y in range(floori(minf(aa.y,minf(bb.y,cc.y))),ceili(maxf(aa.y,maxf(bb.y,cc.y)))+1):
  for x in range(floori(minf(aa.x,minf(bb.x,cc.x))),ceili(maxf(aa.x,maxf(bb.x,cc.x)))+1):
   if Geometry2D.is_point_in_polygon(Vector2(x+0.5,y+0.5),points):pixel(im,x,y,color)
func plate_draw(im:Image,pos:Vector2,size:Vector2,angle:float,opacity:float)->void:
 var aa:=pos+Vector2(-size.x*0.55,-size.y*0.28).rotated(angle)
 var bb:=pos+Vector2(size.x*0.22,-size.y*0.58).rotated(angle)
 var cc:=pos+Vector2(size.x*0.58,size.y*0.28).rotated(angle)
 var dd:=pos+Vector2(-size.x*0.22,size.y*0.58).rotated(angle)
 triangle(im,aa,bb,dd,Color(facet_color,opacity*0.90))
 triangle(im,bb,cc,dd,Color(ice_color,opacity*0.72))
 line(im,aa,bb,Color(edge_color,opacity))
 line(im,aa,dd,Color(edge_color,opacity*0.55))
 line(im,bb,dd,Color(edge_color,opacity*0.70))
 line(im,cc,dd,Color(crack_color,opacity*0.65))
func panel_color(item:Dictionary)->Color:
 var p:Vector2=item.p;var cell:int=item.cell
 var center:Vector2=panel_centers[cell]
 var angle:=noise(cell,8)*1.7-0.85
 var plane:float=(p-center).dot(Vector2(cos(angle),sin(angle)))
 var face:float=0.90 if plane>0 and noise(cell,12)>0.28 else 0.18
 var c:=ice_color.lerp(facet_color,0.18+face*0.70)
 # Source luminance is retained inside the encasing translucent ice.
 var lum:float=item.source.get_luminance()
 c=c.darkened((1-lum)*0.15)
 if item.outside:
  var facing:float=(p-item.nearest).dot(Vector2(-0.7,-1))
  c=c.lerp(edge_color,0.65) if facing>0.5 and noise(cell,11)>0.25 else c.darkened(0.12)
 if item.border<0.6:c=c.lerp(crack_color,0.50)
 # Sparse coherent bright bevels, not a uniform outline.
 if item.border>0.6 and item.border<1.5 and plane<1:c=c.lerp(edge_color,0.6)
 return c
func redraw_visual()->void:
 if not active or not is_instance_valid(host):return
 if not owns_color:base_color=host.self_modulate;last_color=base_color;owns_color=true
 elif not host.self_modulate.is_equal_approx(last_color):base_color=host.self_modulate
 var tint:=Color.WHITE.lerp(body_color,strength*amount*0.24)
 last_color=Color(base_color.r*tint.r,base_color.g*tint.g,base_color.b*tint.b,base_color.a);host.self_modulate=last_color
 global_transform=host.global_transform;z_index=host.z_index;z_as_relative=host.z_as_relative
 back.visible=host.is_visible_in_tree();front.visible=back.visible
 var size:=Vector2i(mask.get_width()+PAD*2,mask.get_height()+PAD*2)
 var a:=Image.create(size.x,size.y,false,Image.FORMAT_RGBA8);var b:=Image.create(size.x,size.y,false,Image.FORMAT_RGBA8)
 var opacity:=clampf(strength/0.5,0,1)*host.modulate.a*base_color.a
 var thaw:float=clampf(phase_age/release_time,0,1) if phase=="releasing" else 0.0
 for item in shell_pixels:
  var p:Vector2=item.p;var cell:int=item.cell
  var level:=release_start if phase=="releasing" else amount
  var fill:=coverage(item.nearest,level)
  if fill<=0:continue
  var c:=panel_color(item)
  var facet_face:float=(p-panel_centers[cell]).dot(Vector2(cos(noise(cell,8)*1.7-0.85),sin(noise(cell,8)*1.7-0.85)))
  var alpha:float=opacity*fill*(0.92 if item.outside else (0.90 if facet_face>0 and noise(cell,12)>0.28 else 0.60))
  if item.outside:
   var facing:float=(p-item.nearest).dot(Vector2(-0.7,-1))
   if facing<0.5:alpha*=0.25
  var pos:=p
  if phase=="releasing":
   var delay:=0.08+noise(cell,5)*0.18
   var u:=maxf(0,(thaw-delay)/(1-delay))
   if item.border<0.8:c=crack_color;alpha*=1-clampf(thaw*4,0,1)
   if u>0:
    var center:Vector2=panel_centers[cell]
    var direction:Vector2=(center-Vector2(mask.get_width(),mask.get_height())*Vector2(0.5,0.55)).normalized()
    var displacement:=direction*(7+noise(cell,9)*7)*u+Vector2(0,-6*u+17*u*u)
    pos=center+(p-center).rotated((noise(cell,7)-0.5)*u*1.5)+displacement
    alpha*=pow(1-u,1.1)
   if u>0.55 and noise(p.x,p.y)<(u-0.55)*1.5:continue
  else:
   var glint:=maxf(0,1-absf(float(p.x+p.y)-fposmod(elapsed*0.2+float(seed_value%17)/17,1.0)*(mask.get_width()+mask.get_height()))/2)*sweep_strength
   c=c.lerp(edge_color,glint)
  pixel(b,roundi(pos.x)+PAD,roundi(pos.y)+PAD,Color(c,alpha))
 for plate in plates:
  var cov:=coverage(plate.p,release_start if phase=="releasing" else amount)
  var pos:Vector2=plate.p;var angle:float=plate.angle;var alpha:float=opacity*cov
  if phase=="releasing":
   var u:=maxf(0,(thaw-plate.delay)/(1-plate.delay))
   pos+=Vector2(plate.side*14*u,-7*u+22*u*u);angle+=plate.side*u*1.8
   alpha*=pow(1-u,0.7)
  if cov>0:plate_draw(b,pos+Vector2(PAD,PAD),plate.size*cov,angle,alpha)
 if not shed:
  for c in crystals:
   var cov:=coverage(c.p,amount)
   if cov>0:shard(b,c.p+Vector2(PAD,PAD),c.dir,c.size*cov,opacity*cov*0.75)
 for p in fragments:
  var u:float=p.age/p.life
  var pos:Vector2=p.p+p.velocity*p.age+Vector2(0,45*p.age*p.age)+Vector2(PAD,PAD)
  shard(b,pos,p.dir.rotated(p.age*2),p.size*(1-u*0.6),opacity*(1-u)*0.65)
 # Mist emitted beneath and around the encased figure, never hiding its interior.
 for i in range(7):
  var u:=fposmod(elapsed*0.5+i*0.17+seed_value*0.03,1)
  var x:=float(mask.get_width())*(float(i)+0.5)/7+sin(u*3+i)*3
  var y:=float(mask.get_height())-3-u*5
  var radius:=2+int(u*3)
  for yy in range(-radius,radius+1):
   for xx in range(-radius,radius+1):
    if xx*xx+yy*yy<=radius*radius:pixel(a,roundi(x)+PAD+xx,roundi(y)+PAD+yy,Color(mist_color,opacity*amount*sin(PI*u)*mist_strength))
 back.position=rect.position-Vector2(PAD,PAD);front.position=back.position
 if back.texture==null or back.texture.get_size()!=Vector2(size):back.texture=ImageTexture.create_from_image(a);front.texture=ImageTexture.create_from_image(b)
 else:back.texture.update(a);front.texture.update(b)
