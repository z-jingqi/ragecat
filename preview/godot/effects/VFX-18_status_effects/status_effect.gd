extends Node2D
## Owner ticks explicitly. Four independent visual states; gameplay owns status rules.
signal status_finished(kind: String)
const KINDS=["burning","poison","frozen","shock"]
var host: Sprite2D
var base_modulate:=Color.WHITE
var last_modulate:=Color.WHITE
var owns_tint:=false
var states: Dictionary={}
var intensity:=0.22
var density:=6
var enter_time:=0.14
var exit_time:=0.22
var seed_value:=18
var time:=0.0
var generation:=0
var palettes: Dictionary={}
func _init()->void:
 var d=JSON.parse_string(FileAccess.get_file_as_string("res://effects/VFX-18_status_effects/presets.json"))
 for k in KINDS:
  palettes[k]=[]
  for c in d.palettes[k]:palettes[k].append(Color(c))
func finite(v:Variant,f:float)->float:
 var n:=float(v) if v is float or v is int else f
 return n if is_finite(n) else f
func configure(v:Dictionary)->void:
 intensity=clampf(finite(v.get("intensity",intensity),intensity),0,0.65)
 density=clampi(int(finite(v.get("density",density),density)),0,16)
 enter_time=clampf(finite(v.get("enter_time",enter_time),enter_time),0.03,1)
 exit_time=clampf(finite(v.get("exit_time",exit_time),exit_time),0.03,1)
 seed_value=int(finite(v.get("seed",seed_value),seed_value))
 for k in KINDS:
  if v.has(k+"_color"):
   var c=Color.from_string(str(v[k+"_color"]),palettes[k][1])
   palettes[k]=[c.darkened(0.35),c,c.lightened(0.35)]
 update_visual()
func bind_host(value:Sprite2D)->void:
 clear_all();restore_tint();host=value
 if not is_instance_valid(host):return
 base_modulate=host.self_modulate;last_modulate=base_modulate;owns_tint=true;update_visual()
func restore_tint()->void:
 if owns_tint and is_instance_valid(host) and host.self_modulate.is_equal_approx(last_modulate):host.self_modulate=base_modulate
 owns_tint=false
func apply_status(kind:String,duration:float=3.0,stacks:int=1)->bool:
 if not KINDS.has(kind) or not is_instance_valid(host) or not is_finite(duration) or duration<=0:return false
 generation+=1
 # Refresh retains visual age/phase. Stack amount is bounded and not added to brightness.
 var prior:Dictionary=states.get(kind,{})
 states[kind]={"age":float(prior.get("age",0.0)),"remaining":clampf(duration,0.01,60),"stacks":clampi(stacks,1,5),"exit":-1.0,"weight":float(prior.get("weight",0.0))}
 update_visual();return true
func remove_status(kind:String,immediate:bool=false)->void:
 generation+=1
 if not states.has(kind):return
 if immediate:states.erase(kind)
 else:states[kind].exit=0.0;states[kind].remaining=0.0
 update_visual()
func clear_all()->void:
 generation+=1;states.clear();time=0.0;update_visual()
func _exit_tree()->void:restore_tint()
func tick(dt:float)->void:
 if not is_finite(dt) or dt<=0:return
 if not is_instance_valid(host):clear_all();owns_tint=false;host=null;return
 time+=dt
 var ended:Array[String]=[]
 for k in states.keys():
  var s:Dictionary=states[k]
  s.age+=dt
  if s.exit<0:
   var over:=maxf(0,dt-s.remaining)
   s.remaining=maxf(0,s.remaining-dt)
   if s.remaining<=0.000001:s.exit=over
  else:s.exit+=dt
  var incoming:=clampf(s.age/enter_time,0,1)
  s.weight=incoming*(1.0-clampf(s.exit/exit_time,0,1)) if s.exit>=0 else incoming
  if s.exit>=exit_time-0.000001:states.erase(k);ended.append(k)
 update_visual()
 var token:=generation
 for k in ended:
  status_finished.emit(k)
  if token!=generation:break
func update_visual()->void:
 if not is_instance_valid(host):queue_redraw();return
 if owns_tint and not host.self_modulate.is_equal_approx(last_modulate):base_modulate=host.self_modulate
 var color:=Color.BLACK;var total:=0.0;var maximum:=0.0
 for k in states:
  var w:float=states[k].weight;color+=palettes[k][1]*w;total+=w;maximum=maxf(maximum,w)
 if total>0:color/=total
 # Multiplicative host tint preserves the existing shader/material and exact alpha.
 var tint:=Color.WHITE.lerp(color,intensity*maximum)
 last_modulate=Color(base_modulate.r*tint.r,base_modulate.g*tint.g,base_modulate.b*tint.b,base_modulate.a)
 host.self_modulate=last_modulate
 queue_redraw()
func stamp(p:Vector2,c:Color,size:Vector2=Vector2.ONE)->void:draw_rect(Rect2(p.round(),size),c)
func pixel_line(a:Vector2,b:Vector2,c:Color)->void:
 var n:=maxi(1,int(ceil(a.distance_to(b))))
 for j in range(n+1):stamp(a.lerp(b,float(j)/n),c)
func phase(i:int,kind:int,period:float)->float:return fposmod(time/period+float(i)*0.618+float(seed_value%997)*0.017+kind*0.13,1.0)
func _draw()->void:
 if not is_instance_valid(host) or not host.is_visible_in_tree() or states.is_empty() or density==0:return
 # Attachment coordinates use current Sprite2D rect/frame/transform; rasterize before host transform.
 draw_set_transform_matrix(global_transform.affine_inverse()*host.global_transform)
 var rect:=host.get_rect();var center:=rect.get_center();var foot:=Vector2(center.x,rect.end.y)
 var half:=rect.size.x*0.48
 for kind in states:
  var w:float=states[kind].weight
  if w<=0:continue
  var cs:Array=palettes[kind];var opacity:=w*clampf(intensity/0.22,0,1)*host.modulate.a*host.self_modulate.a
  var n:=mini(20,density+int(states[kind].stacks)-1)
  if kind=="burning":
   for i in range(n):
    var u:=phase(i,0,0.66);var x:=center.x+sin(i*2.4)*half
    var y:=foot.y-2-u*rect.size.y*0.9
    var h:float=(3+3*sin(i*1.7+1))*sin(PI*u)
    var drift:=sin(time*4+i)*2
    for yy in range(int(h)):
     var width:=maxi(1,int(3*(1-float(yy)/maxf(h,1))))
     stamp(Vector2(x+drift+sin(yy+i)*0.7,y-yy),Color(cs[1],opacity*(1-u*0.6)),Vector2(width,1))
    if u<0.7:stamp(Vector2(x+drift+1,y),Color(cs[2],opacity*0.65))
  elif kind=="poison":
   for i in range(n):
    var u:=phase(i,1,1.3);var p:=Vector2(center.x+sin(i*2.1)*half+sin(time+i),foot.y-u*(rect.size.y+7))
    var r:=1+int(i%3==0)
    var c:=Color(cs[1],opacity*sin(PI*u)*0.85)
    for d in [Vector2(r,0),Vector2(-r,0),Vector2(0,r),Vector2(0,-r)]:stamp(p+d,c)
  elif kind=="frozen":
   for i in range(maxi(4,n)):
    var side:=1.0 if i%2==0 else -1.0
    var p:=Vector2(center.x+side*half*0.8,foot.y-float(i)/maxi(n,4)*rect.size.y*0.85)
    var h:=3+int(i%3);var c:=Color(cs[1],opacity*0.7)
    pixel_line(p,p+Vector2(side*2,-h),c);pixel_line(p+Vector2(side*2,-h),p+Vector2(side*4,0),c)
    if fposmod(time*0.6+i*0.37,1.0)<0.18:stamp(p+Vector2(side*2,-h),Color(cs[2],opacity*0.65))
  elif kind=="shock":
   for i in range(maxi(2,n/2)):
    var u:=phase(i,3,0.48)
    if u>0.9:continue
    var growth:=clampf(u/0.25,0,1);var decay:=clampf((u-0.5)/0.4,0,1)
    var side:=1.0 if i%2==0 else -1.0
    var a:=Vector2(center.x+side*(half+1),foot.y-rect.size.y*0.8)
    var b:=Vector2(center.x-side*half*0.4,foot.y-rect.size.y*0.2)
    var prev:=a
    for j in range(1,7):
     var t:=float(j)/6;var point:=a.lerp(b,t)+Vector2(sin(j*3.7+i*4)*3,0)
     if t<=growth and t>=decay:pixel_line(prev,point,Color(cs[1] if u>0.5 else cs[2],opacity*0.65))
     prev=point
 draw_set_transform_matrix(Transform2D.IDENTITY)
