extends Node2D
## Ground-anchored elite visual. Does not alter host material or gameplay stats.
signal finished
const DEFAULTS={"radius":23.0,"height":48.0,"thickness":1.0,"period":1.1,"particles":14,"rise_speed":0.65,"brightness":0.85,"enter":0.18,"sustain":3.0,"exit":0.35,"seed":31,"core":"fff0aa","body":"edb752","edge":"785658"}
var config:Dictionary=DEFAULTS.duplicate(true)
var automatic:=true
# Opt-in state integration: the caller decides when the active state ends.
var externally_sustained:=false
var active:=false
var age:=0.0
var duration:=0.0
var stopping:=false
var stop_age:=0.0
var stop_strength:=1.0
var bound_host:=false
var host:Node2D
var offset:=Vector2.ZERO
var anchor:=Vector2.ZERO
func configure(overrides:Dictionary) -> void:
 config=DEFAULTS.duplicate(true)
 for k in overrides:
  if config.has(k):config[k]=overrides[k]
 var bounds={"radius":Vector2(8,36),"height":Vector2(16,68),"thickness":Vector2(1,2),"period":Vector2(0.3,4),"rise_speed":Vector2(0.15,2),"brightness":Vector2(0.2,1),"enter":Vector2(0.05,1),"sustain":Vector2(0.05,30),"exit":Vector2(0.08,1)}
 for k in bounds:
  var v:=float(config[k]);config[k]=clampf(v,bounds[k].x,bounds[k].y) if is_finite(v) else DEFAULTS[k]
 config.particles=clampi(int(config.particles),0,32)
 for k in ["core","body","edge"]:
  if not Color.html_is_valid(str(config[k])):config[k]=DEFAULTS[k]
 duration=config.enter+config.sustain+config.exit
func play(at:Vector2,overrides:Dictionary={},target:Node2D=null,foot_offset:Vector2=Vector2.ZERO) -> void:
 configure(overrides);anchor=at;host=target;bound_host=target!=null;offset=foot_offset;age=0;stop_age=0;stopping=false;active=true;queue_redraw()
func strength() -> float:
 if not active:return 0
 if stopping:return stop_strength*(1-smoothstep(0,config.exit,stop_age))
 return smoothstep(0,config.enter,age)*(1.0 if externally_sustained else 1-smoothstep(duration-config.exit,duration,age))
func stop() -> void:
 if active and not stopping:stop_strength=strength();stopping=true;stop_age=0
func clear() -> void:
 active=false;host=null;bound_host=false;age=0;stopping=false;queue_redraw()
func tick(dt:float) -> void:
 if not active or dt<=0 or not is_finite(dt):return
 if bound_host:
  if not is_instance_valid(host):clear();return
  anchor=to_local(host.to_global(offset)).round()
 age+=dt
 if stopping:stop_age+=dt
 if (not externally_sustained and age>=duration) or (stopping and stop_age>=config.exit):
  active=false;host=null;queue_redraw();finished.emit();return
 queue_redraw()
func _process(dt:float) -> void:
 if automatic:tick(dt)
func random_value(i:int,c:int) -> float:
 return fposmod(sin(float(i*137+c*317+int(config.seed)*19))*43758.5453,1.0)
func tint(key:String,level:float=1.0) -> Color:
 return Color(config[key])*Color(config.brightness,config.brightness,config.brightness,clampf(level,0,1))
func ring_point(a:float,r:float) -> Vector2:
 return (anchor+Vector2(cos(a)*r,sin(a)*r*0.28)).round()
func _draw() -> void:
 var e:=strength()
 if e<0.015:return
 var pulse:=0.5+0.5*sin(age*TAU/config.period)
 var radius:float=config.radius*(0.92+0.08*e)
 # A stable foot ring remains readable while brighter arcs circulate.
 for j in range(72):
  var a:=j*TAU/72.0
  var front:=sin(a)>0
  var bright:=sin(a*2-age*TAU/config.period)>0.45
  draw_line(ring_point(a,radius),ring_point(a+TAU/72,radius),tint("body" if bright else "edge",e),config.thickness,false)
 # Four pointed ground sigils distinguish elite state even without hue.
 for side in [-1,1]:
  var q:=anchor+Vector2(side*(radius+3),0)
  draw_line(q+Vector2(-side*2,-2),q,tint("core",e),1,false)
  draw_line(q,q+Vector2(-side*2,2),tint("body",e),1,false)
 # Side flames are tapered moving ribbons, leaving the central host unobscured.
 for side in [-1,1]:
  for lane in range(3):
   var phase:=random_value(lane+side*9,3)*TAU
   var lo:=0.04+lane*0.11
   var hi:float=(0.56+lane*0.14+0.05*sin(age*2.3+phase))*e
   var last:=Vector2.ZERO
   for j in range(19):
    var u:=lerpf(lo,hi,float(j)/18)
    var bend:=sin(u*4.2-age*2.8+phase)*2.0
    var x:float=side*(radius*(0.8-0.38*u)+lane*2+bend)
    var q:Vector2=(anchor+Vector2(x,-u*config.height)).round()
    if j>0:
     var w:=2.0 if lane==0 and j<9 and e>0.65 else 1.0
     draw_line(last,q,tint("body" if lane==0 else "edge",e*(0.7+0.3*pulse)),w,false)
    last=q
 # Bounded analytic rising motes. No cumulative particle allocations.
 for i in range(config.particles):
  var u:float=fposmod(age*config.rise_speed+random_value(i,1),1)
  var envelope:float=smoothstep(0,0.15,u)*(1-smoothstep(0.68,1,u))*e
  if envelope<0.16:continue
  var side:=1 if i%2==0 else -1
  var x:float=side*(radius*lerpf(0.62,1.05,random_value(i,2))-u*5)+sin(u*5+random_value(i,5)*TAU)*2
  var q:Vector2=(anchor+Vector2(x,-u*config.height)).round()
  draw_line(q,q+Vector2(0,-1 if i%3 else -3),tint("core" if i%3 else "body",envelope),1,false)
