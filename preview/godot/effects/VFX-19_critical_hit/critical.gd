extends Node2D
## Procedural local critical impact. A bounded image, not a baked atlas.
signal finished
var auto_tick := true
var playback_rate := 1.0
var age := -1.0
var active := false
var config: Dictionary = {}
var shards: Array = []
var image_buffer := Image.create(128,128,false,Image.FORMAT_RGBA8)
var texture: ImageTexture
const ORIGIN := Vector2(64,64)
func _ready() -> void:
 texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 texture=ImageTexture.create_from_image(image_buffer)
func play(at: Vector2, settings: Dictionary) -> void:
 position=at
 config=settings.duplicate(true)
 for spec in [['size',30,12,36],['duration',.34,.22,.65],['peak',.075,.04,.12],['angle',-28,-180,180],['ring',.7,0,1],['intensity',.68,0,.85]]:
  var value:float=float(config.get(spec[0],spec[1]))
  config[spec[0]]=clampf(value if is_finite(value) else float(spec[1]),spec[2],spec[3])
 config.peak=minf(config.peak,config.duration*.35)
 config.shards=clampi(int(config.get('shards',7)),0,12)
 config.seed=int(config.get('seed',19))
 for spec in [['coreColor','#fff0bd'],['edgeColor','#e7a948'],['coolColor','#925276']]:
  config[spec[0]]=str(config.get(spec[0],spec[1]))
 shards.clear()
 var rng:=RandomNumberGenerator.new();rng.seed=config.seed
 for i in range(config.shards):
  var a:float=deg_to_rad(config.angle)+TAU*float(i)/maxi(1,config.shards)+rng.randf_range(-.23,.23)
  shards.append({'angle':a,'reach':rng.randf_range(.65,1.12),'length':rng.randf_range(.12,.23),'delay':rng.randf_range(.02,.065),'life':rng.randf_range(.55,.85),'width':rng.randf_range(1,2)})
 age=0;active=true;_render()
func replay() -> void:
 if not config.is_empty():play(position,config)
func clear() -> void:
 age=-1;active=false;image_buffer.fill(Color.TRANSPARENT);_upload()
func tick(delta: float) -> void:
 if not active or not is_finite(delta) or delta<=0:return
 age=minf(age+delta*clampf(playback_rate,0,4),config.duration)
 if age>=config.duration:
  active=false;image_buffer.fill(Color.TRANSPARENT);_upload();finished.emit();return
 _render()
func _process(delta: float) -> void:
 if auto_tick:tick(delta)
func _pixel(p: Vector2,c: Color) -> void:
 var x:=roundi(p.x+ORIGIN.x);var y:=roundi(p.y+ORIGIN.y)
 if x>=0 and x<128 and y>=0 and y<128:image_buffer.set_pixel(x,y,c)
func _line(a: Vector2,b: Vector2,c: Color) -> void:
 var n:=maxi(1,ceili(maxf(absf(b.x-a.x),absf(b.y-a.y))))
 for i in range(n+1):_pixel(a.lerp(b,float(i)/n),c)
func _poly(points: PackedVector2Array,c:Color)->void:
 var low:=Vector2(999,999);var high:Vector2=-low
 for p in points:low=low.min(p);high=high.max(p)
 for y in range(floori(low.y),ceili(high.y)+1):
  for x in range(floori(low.x),ceili(high.x)+1):
   if Geometry2D.is_point_in_polygon(Vector2(x,y),points):_pixel(Vector2(x,y),c)
func _spike(a:float,length:float,width:float,start:float,c:Color)->void:
 var d:=Vector2.from_angle(a);var side:=d.orthogonal()
 _poly(PackedVector2Array([d*start,d*(start+length*.32)+side*width,d*(start+length),d*(start+length*.32)-side*width]),c)
func _color(key:String)->Color:
 var c:=Color(config[key]);return Color(c.r*config.intensity,c.g*config.intensity,c.b*config.intensity,1)
func _render()->void:
 image_buffer.fill(Color.TRANSPARENT)
 if not active or config.intensity<=0:_upload();return
 var t:float=age/config.duration
 var a:float=deg_to_rad(config.angle)
 var core:=_color('coreColor');var edge:=_color('edgeColor');var cool:=_color('coolColor')
 # Subordinate ring is broken into three unequal curved segments, not a white disc.
 if config.ring>0 and t>.07 and t<.72:
  var u:=clampf((t-.07)/.65,0,1)
  var radius:float=config.size*(.18+.55*(1-pow(1-u,2)))*config.ring
  var remnant:=clampf((u-.42)/.58,0,1)
  for i in range(64):
   var phase:=posmod(i+int(config.seed),21)
   if phase>int(13*(1-remnant)):continue
   var rad:=TAU*i/64.0+a
   var p:=Vector2(cos(rad)*radius,sin(rad)*radius*.82)
   _pixel(p,edge if u<.35 else cool)
   if u<.3:_pixel(p.normalized()*(p.length()-1),edge)
 # Crisp asymmetric star grows for several frames, then points retract individually.
 var grow:=clampf(age/(config.peak*.6),0,1)
 var release:=clampf((age-config.peak)/(config.duration*.48),0,1)
 for i in range(6):
  var angle:float=a+float(i)*PI/3+(.09 if i%2==1 else 0)
  var weight:float=1.0 if i in [0,3] else (.62 if i%2==0 else .44)
  var local:=clampf(release+float(i%3)*.1,0,1)
  var length:float=config.size*weight*grow*(1-pow(local,.7))
  if length>.8:
   _spike(angle,length,maxf(.5,config.size*.14*grow*(1-local)),0,edge if release<.45 else cool)
   if release<.65:_spike(angle,length*.82,maxf(.4,config.size*.065*grow*(1-local)),0,core)
 # Same shards travel and contract along their own paths; no per-frame random redraw.
 for s in shards:
  var u:float=(t-s.delay)/s.life
  if u<=0 or u>=1:continue
  var d:=Vector2.from_angle(s.angle)
  var p:Vector2=d*config.size*(.22+s.reach*(1-pow(1-u,2)))+Vector2(0,7*u*u)
  var length:float=config.size*s.length*sin(PI*minf(u*1.8,1))
  if length>.7:
   var side:=d.orthogonal()*maxf(.5,s.width*(1-u))
   _poly(PackedVector2Array([p-d*length,p-d*length*.35+side,p,p-d*length*.35-side]),edge if u<.45 else cool)
  elif u<.87:
   _pixel(p,cool)

 _upload()
func _upload()->void:
 if texture==null:texture=ImageTexture.create_from_image(image_buffer)
 else:texture.update(image_buffer)
 queue_redraw()
func _draw()->void:
 if texture!=null:draw_texture(texture,-ORIGIN)
