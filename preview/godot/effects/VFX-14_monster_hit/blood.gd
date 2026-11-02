extends Node2D
## Small opaque, non-emissive blood flecks. Incoming vector uses mathematical +Y up.
var active:=false
var elapsed:=0.0
var settings:Dictionary={}
var drops:Array=[]
static func sanitized(values:Dictionary)->Dictionary:
 var out={"color":"b83e50","count":5,"distance":14.0,"life":0.24,"spread_degrees":75.0,"direction_degrees":180.0,"seed":23}
 for key in ["count","distance","life","spread_degrees","direction_degrees","seed"]:
  if values.has(key) and (values[key] is float or values[key] is int) and is_finite(float(values[key])):out[key]=values[key]
 out.count=clampi(int(out.count),0,16);out.distance=clampf(out.distance,0,40)
 out.life=clampf(out.life,0.06,0.8);out.spread_degrees=clampf(out.spread_degrees,0,180)
 out.direction_degrees=fmod(out.direction_degrees,360.0)
 if values.has("color") and values.color is String and Color.html_is_valid(values.color):out.color=values.color
 return out
func play(at:Vector2,incoming:Vector2,values:Dictionary)->void:
 position=at;settings=sanitized(values);elapsed=0;active=true;drops.clear()
 var rng=RandomNumberGenerator.new();rng.seed=int(settings.seed)
 var forward=Vector2(incoming.x,-incoming.y).normalized() if incoming.is_finite() and incoming.length_squared()>0.0001 else Vector2.RIGHT
 forward=forward.rotated(deg_to_rad(settings.direction_degrees))
 for i in settings.count:
  var direction=forward.rotated(deg_to_rad(rng.randf_range(-0.5,0.5)*settings.spread_degrees))
  drops.append({"travel":direction*settings.distance*rng.randf_range(0.55,1.0),"start":rng.randf_range(0,0.035),"size":2 if i%3==0 else 1,"shade":rng.randf_range(0.75,1.0)})
 queue_redraw()
func tick(dt:float)->void:
 if not active or not is_finite(dt) or dt<=0:return
 elapsed+=dt
 if elapsed>=settings.life:active=false
 queue_redraw()
func clear()->void:
 active=false;elapsed=0;queue_redraw()
func _draw()->void:
 if not active:return
 var base=Color(settings.color);base.a=1.0
 for drop in drops:
  var age=elapsed-drop.start
  if age<0:continue
  var t=clampf(age/maxf(0.001,settings.life-drop.start),0,1)
  # Fast outward movement, small downward fall; then shrink rather than a bright fade.
  var p=(drop.travel*(1.0-pow(1.0-t,2))+Vector2(0,settings.distance*0.3*t*t)).round()
  var size=1 if t>0.65 else drop.size
  if t>0.85 and drop.size==1:continue
  draw_rect(Rect2(p,Vector2.ONE*size),Color(base.r*drop.shade,base.g*drop.shade,base.b*drop.shade,1))
