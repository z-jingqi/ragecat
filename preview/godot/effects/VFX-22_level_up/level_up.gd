extends Node2D
## Visual-only awakening: gather, upward release, quiet resolution.
signal peak
signal finished
const DEFAULTS={"radius":25.0,"height":72.0,"column_width":22.0,"rings":3,"ring_interval":0.08,"particles":18,"charge":0.22,"burst":0.24,"settle":0.68,"intensity":0.62,"seed":22,"core":"fff2b5","body":"e3af4b","edge":"887054"}
var config:=DEFAULTS.duplicate(true)
var automatic:=true
var active:=false
var age:=0.0
var duration:=1.14
var anchor:=Vector2.ZERO
var host:Node2D
var bound_host:=false
var offset:=Vector2.ZERO
var peaked:=false
var generation:=0
func configure(overrides:Dictionary) -> void:
 config=DEFAULTS.duplicate(true)
 for k in overrides:
  if config.has(k):config[k]=overrides[k]
 var bounds={"radius":Vector2(10,40),"height":Vector2(30,88),"column_width":Vector2(6,32),"ring_interval":Vector2(0.02,0.18),"charge":Vector2(0.08,0.8),"burst":Vector2(0.1,0.6),"settle":Vector2(0.25,1.5),"intensity":Vector2(0,0.85)}
 for k in bounds:
  var v:=float(config[k]);config[k]=clampf(v,bounds[k].x,bounds[k].y) if is_finite(v) else DEFAULTS[k]
 config.rings=clampi(int(config.rings),0,4);config.particles=clampi(int(config.particles),0,32)
 for k in ["core","body","edge"]:
  if not Color.html_is_valid(str(config[k])):config[k]=DEFAULTS[k]
 duration=config.charge+config.burst+config.settle
func play(at:Vector2,overrides:Dictionary={},target:Node2D=null,foot_offset:=Vector2.ZERO) -> void:
 generation+=1;configure(overrides);anchor=at.round();host=target;bound_host=target!=null;offset=foot_offset;age=0;active=true;peaked=false
 if bound_host:anchor=to_local(host.to_global(offset)).round()
 queue_redraw()
func clear() -> void:
 generation+=1;active=false;host=null;bound_host=false;age=0;peaked=false;queue_redraw()
func stop() -> void:
 clear()
func tick(dt:float) -> void:
 if not active or not is_finite(dt) or dt<=0:return
 if bound_host:
  if not is_instance_valid(host):clear();return
  anchor=to_local(host.to_global(offset)).round()
 age=minf(age+dt,duration)
 if age>=config.charge and not peaked:
  var ticket:=generation
  peaked=true;peak.emit()
  if not active or generation!=ticket:return
 if age>=duration:
  active=false;host=null;bound_host=false;queue_redraw();finished.emit();return
 queue_redraw()
func _process(dt:float) -> void:
 if automatic:tick(dt)
func rnd(i:int,lane:int) -> float:
 return fposmod(sin(float(i*137+lane*311+int(config.seed)*17))*43758.5453,1)
func color(key:String,e:float=1) -> Color:
 return Color(config[key])*Color(config.intensity,config.intensity,config.intensity,clampf(e,0,1))
func point(v:Vector2) -> Vector2:return (anchor+v).round()
func line(a:Vector2,b:Vector2,c:Color,w:=1.0) -> void:draw_line(point(a),point(b),c,w,false)
func ring(r:float,y:float,e:float,key:String,cut:=0.0) -> void:
 for j in range(64):
  if cut>0 and rnd(j,12)<cut:continue
  var a:=j*TAU/64;var b:=(j+1)*TAU/64
  line(Vector2(cos(a)*r,y+sin(a)*r*0.25),Vector2(cos(b)*r,y+sin(b)*r*0.25),color(key,e))
func _draw() -> void:
 if not active or config.intensity<=0:return
 var c:float=config.charge;var b:float=config.burst;var end:float=config.settle
 var t:=age-c
 if t<0:
  var p:=age/c
  ring(config.radius*lerpf(1.0,0.64,smoothstep(0,1,p)),0,sin(p*PI*0.5),"edge")
  for i in range(8):
   var a:=i*TAU/8+0.12;var r:float=config.radius*lerpf(1.25,0.4,p)
   var v:=Vector2(cos(a)*r,sin(a)*r*0.25)
   line(v,v+Vector2(cos(a)*2,sin(a)),color("body",p))
  return
 var u:=clampf(t/(b+end),0,1)
 var env:=1-smoothstep(0.18,1,u)
 # Upright segmented filaments, never an opaque full-body white rectangle.
 var rise:=smoothstep(0,b*0.7,t)
 for side in [-1,1]:
  for lane in range(3):
   var x:float=side*(config.column_width*0.5+lane*3)
   var top:float=-config.height*rise*(1-lane*0.13)
   var bottom:float=-config.height*pow(u,1.7)
   if top<bottom:
    line(Vector2(x,bottom),Vector2(x+side*2,top),color("body" if lane==0 else "edge",env*(1-lane*0.2)),1)
    if lane==0 and u<0.3:line(Vector2(x,top),Vector2(x-side*2,top+5),color("core",env))
 # Successive ascending rings; each has its own age, radius and broken exit.
 for i in range(config.rings):
  var rt:float=t-i*config.ring_interval
  var life:float=maxf(0.12,b+end-i*config.ring_interval)
  if rt<0 or rt>=life:continue
  var p:float=rt/life
  var radius:float=config.radius*lerpf(0.72,0.94,p)*(1-i*0.1)
  ring(radius,-config.height*p*0.76,sin(minf(p*5,1.0)*PI*0.5)*(1-smoothstep(0.35,1,p)),"body" if i else "core",maxf(0,(p-0.55)*1.8))
 # Sparse radial-upward motes use fixed identities across the whole event.
 for i in range(config.particles):
  var delay:=rnd(i,0)*b*0.45;var life:float=b+end-delay
  var p:=clampf((t-delay)/life,0,1)
  if t<delay or p>=1:continue
  var side:=-1 if i%2 else 1
  var x:float=side*(5+rnd(i,1)*config.radius*0.55+sin(p*PI*0.7)*config.radius*0.27)
  var y:float=-4-config.height*(0.25+0.7*rnd(i,2))*p
  var e:=smoothstep(0,0.08,p)*(1-smoothstep(0.6,1,p))
  var v:=Vector2(x,y)
  if i%6==0:
   line(v+Vector2(-2,1),v+Vector2(0,-1),color("core",e));line(v+Vector2(0,-1),v+Vector2(2,1),color("core",e))
  else:line(v,v+Vector2(0,1+int(rnd(i,3)*2)),color("core" if i%3 else "body",e))
