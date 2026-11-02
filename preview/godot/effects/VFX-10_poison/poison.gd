extends Node2D
## Independent world poison visual. Signals contain no health mutation.
signal active_finished
signal finished
var automatic:=true
var active:=false
var draining:=false
var age:=0.0
var config:Dictionary={}
const DEFAULT={"radius":40.0,"duration":3.0,"formation":0.24,"exit":0.5,"density":16,"flow":1.0,"height":26.0,"seed":19,"deep":"243b28","shade":"395b2d","body":"638d3a","rim":"95bb50","light":"d2e481"}
func _ready()->void:
 config=normalized({})
func normalized(overrides:Dictionary)->Dictionary:
 var c:=DEFAULT.duplicate();c.merge(overrides,true)
 for key in ["radius","duration","formation","exit","flow","height"]:
  if not is_finite(float(c[key])):c[key]=DEFAULT[key]
 c.radius=clampf(c.radius,12,52);c.duration=clampf(c.duration,0.3,30);c.formation=clampf(c.formation,0.05,minf(0.6,c.duration));c.exit=clampf(c.exit,0.1,1.0)
 c.flow=clampf(c.flow,0.3,2.0);c.height=clampf(c.height,8,40);c.density=clampi(int(c.density),0,24);c.seed=clampi(int(c.seed),0,99999)
 for key in ["deep","shade","body","rim","light"]:c[key]=Color(c[key])
 return c
func play(at:Vector2,overrides:Dictionary={})->void:
 config=normalized(overrides);position=at;age=0;active=true;draining=false;queue_redraw()
func stop()->void:
 active=false;draining=false;age=0;queue_redraw()
func _process(dt:float)->void:
 if automatic:tick(dt)
func tick(dt:float)->void:
 if not (active or draining) or not is_finite(dt) or dt<=0:return
 age+=dt
 if active and age>=config.duration:
  active=false;draining=true;active_finished.emit()
  if not draining:return
 if draining and age>=config.duration+config.exit:
  draining=false;finished.emit()
 queue_redraw()
func hash01(i:int)->float:
 return fposmod(sin(float(i*73+int(config.seed)*31))*43758.5453,1.0)
func envelope()->float:
 if not(active or draining):return 0
 return smoothstep(0,config.formation,age)*(1.0-smoothstep(config.duration,config.duration+config.exit,age))
func puff_state(i:int)->Dictionary:
 var life:float=1.65/config.flow
 var phase:float=fposmod(age+hash01(i+9)*life,life)/life
 var theta:float=hash01(i+100)*TAU+age*0.2*config.flow
 var spread:float=sqrt(hash01(i+200))*config.radius*0.67
 var p:=Vector2(cos(theta)*spread,sin(theta)*spread*0.4-phase*config.height)
 var size:float=config.radius*(0.26+hash01(i+300)*0.12)*(0.7+phase*0.6)*sin(PI*phase)
 return {"p":p,"size":size,"phase":phase,"id":i}
func pixel_ellipse(center:Vector2,rx:float,ry:float,color:Color)->void:
 var rxi:=int(round(rx));var ryi:=int(round(ry));var c:=center.round()
 if rxi<1 or ryi<1:return
 for y in range(-ryi,ryi+1):
  var half:=int(floor(rxi*sqrt(maxf(0,1.0-pow(float(y)/ryi,2)))))
  draw_rect(Rect2(c+Vector2(-half,y),Vector2(2*half+1,1)),color)
func pixel_arc(center:Vector2,r:float,start:float,end:float,col:Color,ys:float=1.0)->void:
 var last:=Vector2.INF
 for k in range(24):
  var a:=lerpf(start,end,float(k)/23);var p:Vector2=(center+Vector2(cos(a)*r,sin(a)*r*ys)).round()
  if p!=last:draw_rect(Rect2(p,Vector2.ONE),col);last=p
func _draw()->void:
 if config.is_empty():return
 var e:=envelope()
 if e<=0:return
 var r:float=config.radius*e
 # Stable gameplay footprint, with a low irregular cloud above it.
 pixel_ellipse(Vector2(0,2),r,r*0.46,config.deep)
 pixel_ellipse(Vector2(0,0),r*0.96,r*0.43,config.shade)
 for j in range(5):
  var a:=j*TAU/5+0.12*sin(age*config.flow+j)
  var p:=Vector2(cos(a)*r*0.83,sin(a)*r*0.36)
  pixel_arc(p,3+hash01(j)*3,0.15,PI*1.5,config.body,0.5)
 # Each cloud is born and shrinks continuously; no random reroll per frame.
 var puffs:Array=[]
 for i in range(config.density):puffs.append(puff_state(i))
 puffs.sort_custom(func(a,b):return a.p.y<b.p.y)
 for puff in puffs:
  var p:Vector2=puff.p*e;var s:float=puff.size*e
  var color:Color=config.body if puff.phase<0.62 else config.shade
  pixel_ellipse(p,s,s*0.58,config.deep)
  pixel_ellipse(p+Vector2(0,-1),s*0.91,s*0.52,color)
  pixel_ellipse(p+Vector2(-s*0.25,-s*0.32),s*0.53,s*0.35,color)
  if puff.phase<0.72:
   pixel_arc(p+Vector2(-s*0.18,-s*0.19),s*0.58,PI*1.05,PI*1.82,config.rim,0.63)
  # Small negative-space crease rather than a solid round balloon.
  pixel_arc(p+Vector2(s*0.23,s*0.12),s*0.35,0.0,PI*0.9,config.shade,0.6)
 for i in range(5):
  var u:=fposmod(age*config.flow*0.7+hash01(i+600),1.0)
  var p:=Vector2((hash01(i+700)*2-1)*r*0.76,(hash01(i+800)*2-1)*r*0.30-u*13)
  if u<0.78:
   pixel_arc(p,lerpf(1,3,u)*e,PI*0.1,TAU*0.95,config.rim)
   draw_rect(Rect2(p.round()+Vector2(-1,-1),Vector2.ONE),config.light)
  elif u<0.93:
   var t:float=(u-0.78)/0.15
   for j in range(3):
    var a:=j*TAU/3+0.2
    draw_rect(Rect2((p+Vector2(cos(a),sin(a))*(2+t*3)*e).round(),Vector2.ONE),config.rim)
