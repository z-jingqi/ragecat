extends Node2D
## Host-aware dissolve and independent small death burst. No gameplay destruction.
signal completed
const ShaderCode = preload("res://effects/VFX-15_monster_death/death.gdshader")
var duration := 0.38
var dissolve_seconds := 0.20
var fragment_count := 9
var spread := 24.0
var drift := 24.0
var seed_value := 17
var direction_degrees := -90.0
var cluster_size := 2.0
var edge_width := 0.07
var tint := Color("e5c19c")
var ash_color := Color("8b8795")
var host_mode := true
var flipped := false
var elapsed := 0.0
var playing := false
var finished := false
var sprite: Sprite2D
var shader_material: ShaderMaterial
var fragments: Array[Dictionary] = []
var host_image: Image
var opaque_points: Array[Vector2] = []

func _init() -> void:
 shader_material=ShaderMaterial.new();shader_material.shader=ShaderCode
 sprite=Sprite2D.new();sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;sprite.material=shader_material
 add_child(sprite)
func configure(values:Dictionary) -> void:
 duration=clampf(float(values.get("duration",duration)),0.12,1.0)
 dissolve_seconds=clampf(float(values.get("dissolve_seconds",dissolve_seconds)),0.06,duration)
 fragment_count=clampi(int(values.get("fragment_count",fragment_count)),0,24)
 spread=clampf(float(values.get("spread",spread)),0.0,48.0)
 drift=clampf(float(values.get("drift",drift)),-40.0,60.0)
 seed_value=clampi(int(values.get("seed",seed_value)),0,65535)
 direction_degrees=wrapf(float(values.get("direction_degrees",direction_degrees)),-180.0,180.0)
 cluster_size=clampf(float(values.get("cluster_size",cluster_size)),1.0,6.0)
 edge_width=clampf(float(values.get("edge_width",edge_width)),0.0,0.2)
 if values.has("tint"):tint=Color(values.tint)
 if values.has("ash_color"):ash_color=Color(values.ash_color)
 host_mode=bool(values.get("host_mode",host_mode))
 flipped=bool(values.get("flipped",flipped))
 reset()
func set_host(image:Image) -> bool:
 if image==null or image.is_empty() or image.get_width()>256 or image.get_height()>256:return false
 host_image=image.duplicate();sprite.texture=ImageTexture.create_from_image(host_image)
 opaque_points.clear()
 for y in host_image.get_height():
  for x in host_image.get_width():
   if host_image.get_pixel(x,y).a>0.5:opaque_points.append(Vector2(x+0.5-image.get_width()/2.0,y+0.5-image.get_height()/2.0))
 reset();return true
func reset() -> void:
 elapsed=0;playing=false;finished=false;fragments.clear();sync_visuals()
func play() -> void:
 reset();playing=true
 var rng:=RandomNumberGenerator.new();rng.seed=seed_value
 for i in fragment_count:
  var p:=Vector2.ZERO
  if host_mode and not opaque_points.is_empty():p=opaque_points[rng.randi_range(0,opaque_points.size()-1)]
  if flipped:p.x=-p.x
  var a:=rng.randf_range(-PI,PI)
  var born:=rng.randf_range(0.035,dissolve_seconds*0.65)
  var life:=minf(rng.randf_range(0.12,maxf(0.13,duration*0.65)),duration-born)
  fragments.append({"start":p,"velocity":Vector2(cos(a)*spread,sin(a)*spread-drift),"born":born,"size":rng.randi_range(1,2),"life":life})
 sync_visuals()
func advance(dt:float) -> void:
 if not playing or dt<=0 or not is_finite(dt):return
 elapsed=minf(duration,elapsed+dt)
 if elapsed>=duration-0.000001:
  elapsed=duration;playing=false;finished=true;fragments.clear();completed.emit()
 sync_visuals()
func sync_visuals() -> void:
 sprite.visible=host_mode and sprite.texture!=null and not finished
 sprite.flip_h=flipped
 shader_material.set_shader_parameter("progress",clampf(elapsed/dissolve_seconds,0,1) if elapsed>0 else 0.0)
 shader_material.set_shader_parameter("direction",deg_to_rad(direction_degrees))
 shader_material.set_shader_parameter("cluster_size",cluster_size)
 shader_material.set_shader_parameter("seed_value",float(seed_value))
 shader_material.set_shader_parameter("edge_width",edge_width)
 shader_material.set_shader_parameter("edge_color",tint)
 shader_material.set_shader_parameter("flash",0.20*(1.0-elapsed/0.035) if playing and elapsed<0.035 else 0.0)
 queue_redraw()
func live_fragments() -> Array[Dictionary]:
 var result:Array[Dictionary]=[]
 if not playing:return result
 for part in fragments:
  var t:float=elapsed-part.born
  if t<0 or t>=part.life:continue
  var p:Vector2=part.start+part.velocity*t
  var s:int=part.size if t<part.life*0.55 else 1
  result.append({"position":p.floor(),"size":s,"bright":t<part.life*0.18})
 return result
func _draw() -> void:
 for part in live_fragments():draw_rect(Rect2(part.position,Vector2.ONE*part.size),tint if part.bright else ash_color)
 if playing and not host_mode and elapsed<0.07:
  var r:=roundf(3.0+9.0*sin(PI*elapsed/0.07))
  var polygon:=PackedVector2Array([Vector2(-r,0),Vector2(-2,-2),Vector2(0,-r*0.65),Vector2(2,-2),Vector2(r,0),Vector2(2,2),Vector2(0,r*0.65),Vector2(-2,2)])
  for y in range(-int(r),int(r)+1):
   for x in range(-int(r),int(r)+1):
    if Geometry2D.is_point_in_polygon(Vector2(x+0.5,y+0.5),polygon):draw_rect(Rect2(x,y,1,1),tint)
