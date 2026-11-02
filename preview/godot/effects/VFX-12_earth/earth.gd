extends Node2D
## Analytical, bounded raster ground fracture. No atlas or physics/gameplay dependency.
signal finished
var auto_tick := true
var playback_rate := 1.0
var age := -1.0
var active := false
var config: Dictionary = {}
var cracks: Array = []
var rocks: Array = []
var dust: Array = []
var image_buffer := Image.create(160,128,false,Image.FORMAT_RGBA8)
var texture: ImageTexture
const ORIGIN := Vector2(80,87)
func _ready() -> void:
 texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 texture=ImageTexture.create_from_image(image_buffer)
func play(at: Vector2, settings: Dictionary) -> void:
 position=at
 config=settings.duplicate(true)
 config.radius=clampf(float(config.get('radius',42)),12,52)
 config.duration=clampf(float(config.get('duration',.9)),.5,1.4)
 config.propagation=clampf(float(config.get('propagation',.15)),.06,minf(.3,config.duration*.4))
 config.branches=clampi(int(config.get('branches',7)),3,12)
 config.rocks=clampi(int(config.get('rocks',10)),0,18)
 config.dust=clampi(int(config.get('dust',8)),0,14)
 config.height=clampf(float(config.get('height',26)),4,38)
 config.angle=clampf(float(config.get('angle',0)),-180,180)
 config.seed=int(config.get('seed',38))
 cracks.clear();rocks.clear();dust.clear()
 var rng:=RandomNumberGenerator.new();rng.seed=config.seed
 var ts:float=config.duration/.9
 for i in range(config.branches):
  var a:float=TAU*float(i)/config.branches+deg_to_rad(config.angle)+rng.randf_range(-.19,.19)
  var pts: Array[Vector2]=[Vector2.ZERO]
  for j in range(1,5):
   var rr:float=config.radius*float(j)/4.0
   var aa:float=a+rng.randf_range(-.12,.12)
   pts.append(Vector2(cos(aa)*rr,sin(aa)*rr*.42))
  cracks.append({'points':pts,'fork':Vector2(cos(a+.36)*config.radius*.93,sin(a+.36)*config.radius*.93*.42),'delay':rng.randf_range(0,.035)})
 for i in range(config.rocks):
  var a:=rng.randf()*TAU
  var rr:float=rng.randf_range(.28,.85)*config.radius
  rocks.append({'base':Vector2(cos(a)*rr,sin(a)*rr*.42),'drift':Vector2(cos(a)*rng.randf_range(3,5),sin(a)*3),'height':rng.randf_range(.5,1)*config.height,'size':rng.randi_range(2,4),'delay':rng.randf_range(.035,.12)*ts,'life':rng.randf_range(.35,.5)*ts,'spin':rng.randi_range(0,2)})
 for i in range(config.dust):
  var a:=rng.randf()*TAU
  dust.append({'base':Vector2(cos(a)*config.radius*.8,sin(a)*config.radius*.42*.8),'drift':Vector2(cos(a)*8,-rng.randf_range(4,9)),'delay':rng.randf_range(.13,.25)*ts,'size':rng.randi_range(3,6)})
 age=0;active=true;_render()
func replay() -> void:
 if not config.is_empty():play(position,config)
func clear() -> void:
 age=-1;active=false;image_buffer.fill(Color.TRANSPARENT);_upload()
func tick(delta: float) -> void:
 if not active or delta<=0:return
 age=minf(age+delta*clampf(playback_rate,0,4),config.duration)
 if age>=config.duration:
  active=false;image_buffer.fill(Color.TRANSPARENT);_upload();finished.emit();return
 _render()
func _process(delta: float) -> void:
 if auto_tick:tick(delta)
func _pixel(p: Vector2,c: Color) -> void:
 var x:=roundi(p.x+ORIGIN.x);var y:=roundi(p.y+ORIGIN.y)
 if x>=0 and x<160 and y>=0 and y<128:image_buffer.set_pixel(x,y,c)
func _line(a: Vector2,b: Vector2,c: Color) -> void:
 var n:=maxi(1,ceili(maxf(absf(b.x-a.x),absf(b.y-a.y))))
 for i in range(n+1):_pixel(a.lerp(b,float(i)/n),c)
func _chunk(center: Vector2,size: int,c: Color,highlight: Color,erosion: float=0) -> void:
 for y in range(-size,size+1):
  for x in range(-size,size+1):
   if abs(x)+abs(y)*.7>size*1.3:continue
   if float(posmod(x*13+y*19+int(config.seed),17))/17.0<erosion:continue
   _pixel(center+Vector2(x,y),highlight if y < -size*.2 and x<1 else c)
func _render() -> void:
 image_buffer.fill(Color.TRANSPARENT)
 if not active:_upload();return
 var hot:=Color(config.hotColor);var crack:=Color(config.crackColor)
 var stone:=Color(config.rockColor);var light:=Color(config.lightColor);var smoke:=Color(config.dustColor)
 var cool:=clampf((age-.22)/(config.duration-.22),0,1)
 # Irregular radial fractures write on, then shrink from their ends in staggered sections.
 for ci in range(cracks.size()):
  var c:Dictionary=cracks[ci];var grow:=clampf((age-c.delay)/config.propagation,0,1)
  var keep:=1.0-clampf((cool-.32-float(ci%3)*.05)/.58,0,1)
  var pts:Array=c.points
  for j in range(4):
   var start:=float(j)/4;var finish:=minf(grow,keep)
   if finish<=start:continue
   var end:Vector2=pts[j].lerp(pts[j+1],clampf((finish-start)*4,0,1))
   _line(pts[j],end,hot if age<config.propagation+.03 else crack)
   if j<2 and cool<.35:_line(pts[j]+Vector2(0,1),end+Vector2(0,1),stone.darkened(.4))
  if grow>.55 and keep>.55:_line(pts[2],pts[2].lerp(c.fork,clampf((minf(grow,keep)-.55)/.45,0,1)),crack)
 # Short flattened broken front, subordinate to cracks, not a giant circle.
 var rp:=clampf(age/(config.propagation*.95),0,1)
 if rp>0 and age<config.propagation+.08:
  for i in range(60):
   if i%9>5:continue
   var a:=TAU*i/60.0
   _pixel(Vector2(cos(a)*config.radius*rp,sin(a)*config.radius*rp*.42),light)
 # Dust behind fragments, expands slightly then erodes in pixel clusters.
 for d in dust:
  var t:=clampf((age-d.delay)/(config.duration-d.delay),0,1)
  if age<d.delay or t>=1:continue
  var s:=maxi(1,roundi(d.size*sin(PI*minf(t*1.4,.9))*.75))
  _chunk(d.base+d.drift*t,s,smoke.darkened(.3),smoke,clampf((t-.42)/.58,0,1))
 # Independent ballistic fragments emerge with propagation, land and shrink.
 for r in rocks:
  var t:float=(age-r.delay)/r.life
  if t<0 or t>1.45:continue
  var flight:=minf(t,1)
  var pos:Vector2=r.base+r.drift*flight+Vector2(0,-4*r.height*flight*(1-flight))
  var size:=maxi(0,roundi(r.size*(1-clampf((t-1)/.4,0,1))))
  if size>0:_chunk(pos,size,stone,light)
 _upload()
func _upload() -> void:
 if texture==null:texture=ImageTexture.create_from_image(image_buffer)
 else:texture.update(image_buffer)
 queue_redraw()
func _draw() -> void:
 if texture!=null:draw_texture(texture,-ORIGIN)
