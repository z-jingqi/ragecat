extends Node2D
## Visual-only awakening: gather, upward release, quiet resolution.
signal peak
signal finished
const DEFAULTS={"radius":25.0,"height":88.0,"column_width":12.0,"core_width":2.0,"glints":5,"pulse_amount":0.06,"rings":2,"ring_interval":0.08,"particles":18,"charge":0.1,"burst":0.65,"settle":0.85,"intensity":0.62,"seed":22,"core":"fff2b5","body":"e3af4b","edge":"887054"}
var config:=DEFAULTS.duplicate(true)
var automatic:=true
var active:=false
var age:=0.0
var duration:=1.6
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
 var bounds={"radius":Vector2(10,40),"height":Vector2(30,88),"column_width":Vector2(6,32),"core_width":Vector2(1,4),"pulse_amount":Vector2(0,0.15),"ring_interval":Vector2(0.02,0.18),"charge":Vector2(0.08,0.8),"burst":Vector2(0.1,1.2),"settle":Vector2(0.25,1.5),"intensity":Vector2(0,0.85)}
 for k in bounds:
  var v:=float(config[k]);config[k]=clampf(v,bounds[k].x,bounds[k].y) if is_finite(v) else DEFAULTS[k]
 config.glints=clampi(int(config.glints),0,12)
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
 var c:float=config.charge
 var b:float=config.burst
 var tail:float=config.settle
 var t:=age-c
 if t<0:
  var p:=age/c
  var r:float=lerpf(3,config.radius*0.46,p)
  ring(r,0,sin(p*PI*0.5),"body")
  line(Vector2(-3,0),Vector2(3,0),color("core",sin(p*PI)),2)
  return
 # Ground rings remain at the foot. The reference is a pillar, not rising hoops.
 for i in range(config.rings):
  var rt:float=t-i*config.ring_interval
  if rt<0:continue
  var life:float=b+tail*0.55
  var p:=clampf(rt/life,0,1)
  var r:float=config.radius*(0.58+i*0.15)*lerpf(0.75,1.15,smoothstep(0,0.3,p))
  var e:float=smoothstep(0,0.07,p)*(1-smoothstep(0.32,1,p))
  ring(r,0,e,"core" if i==0 else "body",maxf(0,(p-0.7)*2))
 # Central narrow pillar with stepped three-tone glow, independently fading
 # before the last sparks. Small bounded modulation is not a white strobe.
 var beam_end:float=b+tail*0.32
 var e:=smoothstep(0,0.07,t)*(1-smoothstep(b,beam_end,t))
 var pulse:float=1-config.pulse_amount*(0.5+0.5*sin(t*TAU*6))
 var h:float=config.height*smoothstep(0,0.1,t)
 var cw:float=config.core_width
 for layer in range(3):
  var width:float=[config.column_width,cw+3,cw][layer]
  var alpha:float=[0.2,0.5,1.0][layer]
  var key:String=["edge","body","core"][layer]
  draw_rect(Rect2(point(Vector2(-width*0.5,-h)),Vector2(roundf(width),roundf(h))),color(key,e*alpha*pulse))
 # Fixed, staggered sparks rise from a low disc; drag slows the upward motion.
 for i in range(config.particles):
  var delay:=rnd(i,0)*b*0.7
  var life:float=b+tail-delay
  var p:=clampf((t-delay)/life,0,1)
  if t<delay or p>=1:continue
  var x:float=(rnd(i,1)*2-1)*config.radius*0.75
  var y:float=-3-config.height*(0.25+0.35*rnd(i,2))*(1-pow(1-p,2))
  var alpha:=smoothstep(0,0.07,p)*(1-smoothstep(0.45,1,p))
  var v:=Vector2(x,y)
  if i%5==0:
   # Small upward shards, not letterforms.
   var size:=2.0 if p<0.65 else 1.0
   draw_colored_polygon(PackedVector2Array([point(v+Vector2(-size,1)),point(v+Vector2(0,-size)),point(v+Vector2(size,1))]),color("body",alpha))
  else:line(v,v+Vector2(0,1+int(rnd(i,3)*3)),color("core" if i%3 else "body",alpha))
 for i in range(config.glints):
  var delay:=0.08+rnd(i,7)*b
  var life:=0.2+rnd(i,8)*0.24
  var p:float=(t-delay)/life
  if p<0 or p>=1:continue
  var v:=Vector2((rnd(i,9)*2-1)*config.radius*0.9,-8-rnd(i,10)*config.height*0.55)
  var alpha:=sin(p*PI)
  var size:=1.0 if p<0.2 or p>0.8 else 2.0
  line(v+Vector2(-size,0),v+Vector2(size,0),color("core",alpha))
  line(v+Vector2(0,-size),v+Vector2(0,size),color("core",alpha))
