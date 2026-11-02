extends Node2D
## Attached micro-electric arcs. No gameplay damage, motion or animation changes.
signal finished
var host:Sprite2D
var back:=Sprite2D.new()
var front:=Sprite2D.new()
var edge:Array[Vector2]=[]
var lower_edge:Array[Vector2]=[]
var mask:Image
var key:=""
var rect:=Rect2()
var arcs:Array=[]
var rng:=RandomNumberGenerator.new()
var elapsed:=0.0
var remaining:=0.0
var fade_age:=-1.0
var next_arc:=0.0
var active:=false
var strength:=0.42
var arc_rate:=7.0
var arc_length:=15.0
var arc_speed:=100.0
var hold_time:=0.055
var cool_time:=0.28
var branch_chance:=0.45
var enter_time:=0.10
var exit_time:=0.35
var tint_strength:=0.08
var seed_value:=57
var core_color:=Color("b1e0e4")
var arc_color:=Color("6ca5cd")
var cool_color:=Color("41557f")
var branch_color:=Color("7cbbd1")
var tint_color:=Color("b4ceeb")
var base_color:=Color.WHITE
var last_color:=Color.WHITE
var owns_color:=false
const PAD=24
const LIMIT=128
const POOL_LIMIT=20
func _init()->void:
 add_child(back);add_child(front);back.z_index=-1;front.z_index=1
 back.centered=false;front.centered=false
 back.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;front.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 configure(JSON.parse_string(FileAccess.get_file_as_string("res://effects/VFX-18_status_effects/shock/config.json")))
func number(v:Variant,f:float)->float:
 var n:=float(v) if v is int or v is float else f
 return n if is_finite(n) else f
func configure(p:Dictionary)->void:
 for name in ["core_color","arc_color","cool_color","branch_color","tint_color"]:
  if p.has(name):set(name,Color.from_string(str(p[name]),get(name)))
 strength=clampf(number(p.get("intensity",strength),strength),0,0.7)
 arc_rate=clampf(number(p.get("arc_rate",arc_rate),arc_rate),0,20)
 arc_length=clampf(number(p.get("arc_length",arc_length),arc_length),4,30)
 arc_speed=clampf(number(p.get("arc_speed",arc_speed),arc_speed),40,300)
 hold_time=clampf(number(p.get("hold_time",hold_time),hold_time),0.02,0.3)
 cool_time=clampf(number(p.get("cool_time",cool_time),cool_time),0.08,0.6)
 branch_chance=clampf(number(p.get("branch_chance",branch_chance),branch_chance),0,1)
 enter_time=clampf(number(p.get("enter_time",enter_time),enter_time),0.02,1)
 exit_time=clampf(number(p.get("exit_time",exit_time),exit_time),0.1,2)
 tint_strength=clampf(number(p.get("tint_strength",tint_strength),tint_strength),0,0.35)
 seed_value=int(number(p.get("seed",seed_value),seed_value));redraw_visual()
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
  elapsed=0;arcs.clear();rng.seed=seed_value;next_arc=rng.randf_range(0.01,0.12)
 remaining=minf(seconds,60);fade_age=-1;active=true;redraw_visual();return true
func cancel(immediate:bool=false)->void:
 if immediate:clear()
 elif active:remaining=0;fade_age=0
func clear()->void:
 active=false;arcs.clear();elapsed=0;remaining=0;fade_age=-1
 back.texture=null;front.texture=null;restore()
func restore()->void:
 if owns_color and is_instance_valid(host) and host.self_modulate.is_equal_approx(last_color):host.self_modulate=base_color
 owns_color=false
func _exit_tree()->void:restore()
func tick(dt:float)->void:
 if not is_finite(dt) or dt<=0 or not active:return
 if not is_instance_valid(host) or not refresh_mask():clear();host=null;return
 elapsed+=dt
 if fade_age>=0:fade_age+=dt
 else:
  var excess:=maxf(0,dt-remaining);remaining=maxf(0,remaining-dt)
  if remaining<=0.000001:fade_age=excess
 for a in arcs:a.age+=dt
 arcs=arcs.filter(func(a):return a.age<a.life)
 if fade_age<0 and arc_rate>0:
  next_arc-=dt
  var count:=0
  while next_arc<=0 and count<POOL_LIMIT:
   spawn_arc();next_arc+=rng.randf_range(0.7,1.3)/arc_rate;count+=1
 if fade_age>=exit_time:clear();finished.emit();return
 redraw_visual()
func closest_surface(p:Vector2,radius:int=3)->Vector2:
 if alpha_at(roundi(p.x),roundi(p.y))>=0.15:return p.round()
 var best:=Vector2(-1000,-1000);var distance:=float(radius*radius+1)
 for y in range(-radius,radius+1):
  for x in range(-radius,radius+1):
   var q:=p.round()+Vector2(x,y);var dd:=Vector2(x,y).length_squared()
   if dd<distance and alpha_at(int(q.x),int(q.y))>=0.15:best=q;distance=dd
 return best
func spawn_arc()->void:
 if edge.size()<2 or arcs.size()>=POOL_LIMIT:return
 var start:Vector2=edge[rng.randi_range(0,edge.size()-1)]
 var points:Array[Vector2]=[start]
 var contour:=rng.randf()<0.7
 if contour:
  var prev:=Vector2.ZERO
  for i in range(int(arc_length)):
   var best:=Vector2(-1000,-1000);var score:=-1000.0
   for p in edge:
    var delta:Vector2=p-points[-1]
    if delta.length_squared()<0.5 or delta.length_squared()>2.1 or points.has(p):continue
    var value:=delta.normalized().dot(prev)*0.8+rng.randf()*0.5
    if value>score:score=value;best=p
   if best.x< -999:break
   prev=(best-points[-1]).normalized();points.append(best)
 else:
  var target:Vector2=edge[rng.randi_range(0,edge.size()-1)]
  var direction:Vector2=(target-start).normalized();var length:=minf(start.distance_to(target),arc_length)
  var last:=start
  for i in range(1,maxi(2,int(length/3))+1):
   var raw:=start+direction*minf(i*3,length)+direction.orthogonal()*rng.randf_range(-2,2)
   var point:=closest_surface(raw)
   if point.x> -999 and point!=last:points.append(point);last=point
 if points.size()<3:return
 var length:=0.0
 var distances:Array[float]=[0.0]
 for i in range(1,points.size()):length+=points[i-1].distance_to(points[i]);distances.append(length)
 var grow:=clampf(length/arc_speed,0.06,0.32)
 var branch:Array[Vector2]=[]
 var branch_at:=0.0
 if rng.randf()<branch_chance:
  var idx:=clampi(int(points.size()*0.55),1,points.size()-1);var p:Vector2=points[idx]
  var direction:Vector2=(p-points[idx-1]).orthogonal().normalized()*(1 if rng.randf()>0.5 else -1)
  branch=[p,p+direction*2+Vector2(rng.randf_range(-1,1),0),p+direction*rng.randf_range(3,5)]
  branch_at=grow*distances[idx]/maxf(length,1)+0.045
 var visual_points:Array[Vector2]=[]
 var offset:=rng.randf_range(0.6,2.0)
 for i in range(points.size()):
  var p:Vector2=points[i]
  if contour:
   var normal:=Vector2(alpha_at(int(p.x)-1,int(p.y))-alpha_at(int(p.x)+1,int(p.y)),alpha_at(int(p.x),int(p.y)-1)-alpha_at(int(p.x),int(p.y)+1)).normalized()
   if rng.randf()<0.45:offset=rng.randf_range(0.6,2.0)
   visual_points.append(p+normal*offset)
  else:visual_points.append(p)
 arcs.append({"visual_points":visual_points,"points":points,"distances":distances,"length":length,"grow":grow,"branch":branch,"branch_at":branch_at,"age":0.0,"life":grow+hold_time+cool_time+0.15,"contour":contour,"phase":rng.randf()})
func segment_alpha(age:float,start:float)->float:
 var local:=age-start
 if local<0:return 0
 if local<0.035:return local/0.035
 if local<0.035+hold_time:return 1
 return pow(clampf(1-(local-0.035-hold_time)/cool_time,0,1),1.5)
func pixel(im:Image,p:Vector2,c:Color)->void:
 var q:=Vector2i(p)+Vector2i(PAD,PAD)
 if q.x<0 or q.y<0 or q.x>=im.get_width() or q.y>=im.get_height() or c.a<=0:return
 # Max alpha prevents multiple line endpoints accumulating into bright blobs.
 var old:=im.get_pixelv(q)
 if c.a>old.a:im.set_pixelv(q,c)
func draw_path(im:Image,a:Dictionary,points:Array,start:float,branch:bool,opacity:float)->void:
 if points.size()<2:return
 var total:=0.0
 for i in range(1,points.size()):total+=points[i-1].distance_to(points[i])
 var traveled:=0.0
 for i in range(1,points.size()):
  var p:Vector2=points[i-1];var q:Vector2=points[i]
  var distance:=p.distance_to(q);var steps:=maxi(1,ceili(distance))
  for j in range(steps+1):
   var u:=float(j)/steps
   var progress:float=(traveled+distance*u)/maxf(total,1)
   var onset:float=start+progress*(0.07 if branch else a.grow)
   # Cooling onset varies by segment, preserving fine residual breaks.
   var local:float=a.age-onset
   var alpha:=segment_alpha(a.age,onset)*opacity*(0.65 if branch else 1.0)
   if alpha<=0:continue
   var raw:Vector2=p.lerp(q,u).round()
   var surface:=closest_surface(raw,2 if branch else 3)
   if surface.x< -999:continue
   var pos:=raw if branch or a.contour else surface
   var heat:=clampf(local/(hold_time+cool_time),0,1)
   var color:Color=(branch_color if branch else core_color).lerp(arc_color,clampf(heat*2,0,1)).lerp(cool_color,clampf((heat-0.35)*1.5,0,1))
   pixel(im,pos,Color(color,alpha))
  traveled+=distance
func redraw_visual()->void:
 if not active or not is_instance_valid(host):return
 if not owns_color:base_color=host.self_modulate;last_color=base_color;owns_color=true
 elif not host.self_modulate.is_equal_approx(last_color):base_color=host.self_modulate
 var weight:float=minf(elapsed/enter_time,1)*(1-clampf(fade_age/exit_time,0,1) if fade_age>=0 else 1)
 var tint:=Color.WHITE.lerp(tint_color,tint_strength*weight)
 last_color=Color(base_color.r*tint.r,base_color.g*tint.g,base_color.b*tint.b,base_color.a);host.self_modulate=last_color
 global_transform=host.global_transform;z_index=host.z_index;z_as_relative=host.z_as_relative
 back.visible=host.is_visible_in_tree();front.visible=back.visible
 var size:=Vector2i(mask.get_width()+PAD*2,mask.get_height()+PAD*2)
 var im:=Image.create(size.x,size.y,false,Image.FORMAT_RGBA8)
 var opacity:float=weight*clampf(strength/0.5,0,1)*host.modulate.a*base_color.a
 for a in arcs:
  draw_path(im,a,a.visual_points,0,false,opacity)
  draw_path(im,a,a.branch,a.branch_at,true,opacity)
 front.position=rect.position-Vector2(PAD,PAD)
 if front.texture==null or front.texture.get_size()!=Vector2(size):front.texture=ImageTexture.create_from_image(im)
 else:front.texture.update(im)
