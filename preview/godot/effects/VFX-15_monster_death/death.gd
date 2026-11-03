extends Node2D
## Host-aware dissolve and independent small death burst. No gameplay destruction.
signal completed
signal burst_finished
const ShaderCode = preload("death.gdshader")
var duration := 0.38
var dissolve_seconds := 0.20
var fragment_count := 16
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
var residue_seconds := 3.0
var residue_count := 7
var residue_spread := 14.0
var residue_color := Color("666476")
var residue_highlight := Color("97909a")
var ground_offset := Vector2(0,18)
var teleport_distance := 128.0
var play_origin := Vector2.ZERO
var generation := 0
var play_transform := Transform2D.IDENTITY
var burst_done := false
var residue: Array[Dictionary] = []
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
 drift=clampf(float(values.get("drift",drift)),0.0,60.0)
 seed_value=clampi(int(values.get("seed",seed_value)),0,65535)
 direction_degrees=wrapf(float(values.get("direction_degrees",direction_degrees)),-180.0,180.0)
 cluster_size=clampf(float(values.get("cluster_size",cluster_size)),1.0,6.0)
 edge_width=clampf(float(values.get("edge_width",edge_width)),0.0,0.2)
 if values.has("tint"):tint=Color(values.tint)
 if values.has("ash_color"):ash_color=Color(values.ash_color)
 residue_seconds=clampf(float(values.get("residue_seconds",residue_seconds)),0.0,8.0)
 residue_count=clampi(int(values.get("residue_count",residue_count)),0,20)
 residue_spread=clampf(float(values.get("residue_spread",residue_spread)),0.0,32.0)
 if values.has("residue_color"):residue_color=Color(values.residue_color)
 if values.has("residue_highlight"):residue_highlight=Color(values.residue_highlight)
 if values.has("ground_offset") and values.ground_offset is Vector2:ground_offset=values.ground_offset
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
 generation+=1
 elapsed=0;playing=false;finished=false;burst_done=false;fragments.clear();residue.clear();sync_visuals()
func dissolve_threshold(point:Vector2)->float:
 if host_image==null:return 0.0
 var size:=Vector2(host_image.get_width(),host_image.get_height())
 var pixel:=point+size*0.5
 var cell:=(pixel/cluster_size).floor()
 var n:=fposmod(cell.x*73.0+cell.y*151.0+float(seed_value)*19.0,997.0)
 var noise:=fposmod(n*n+17.0*n+19.0,997.0)/997.0
 var dir:=Vector2.from_angle(deg_to_rad(direction_degrees))
 var projected:float=(pixel/size-Vector2.ONE*0.5).dot(dir)/(absf(dir.x)+absf(dir.y))+0.5
 return 0.07+0.86*(projected*0.64+noise*0.36)
func play() -> void:
 reset();playing=true;play_origin=global_position;play_transform=global_transform
 var rng:=RandomNumberGenerator.new();rng.seed=seed_value
 var count:=maxi(fragment_count,residue_count if residue_seconds>0 else 0)
 for i in count:
  var p:=Vector2.ZERO
  var source_color:=ash_color
  var born:=rng.randf_range(0.015,0.07)
  if host_mode and not opaque_points.is_empty():
   p=opaque_points[rng.randi_range(0,opaque_points.size()-1)]
   born=dissolve_threshold(p)*dissolve_seconds
   var pixel:Vector2i=Vector2i(p+Vector2(host_image.get_width(),host_image.get_height())*0.5)
   source_color=host_image.get_pixelv(pixel)
  if flipped:p.x=-p.x
  var land:Vector2=(ground_offset+Vector2(rng.randf_range(-residue_spread,residue_spread),rng.randf_range(-2,2))).round()
  var flight:=minf(rng.randf_range(0.18,0.27),maxf(0.06,duration-born))
  var vy:float=-rng.randf_range(0.0,drift)
  var velocity:=Vector2((land.x-p.x)/flight+rng.randf_range(-spread,spread)*0.35,vy)
  var ax:float=2.0*(land.x-p.x-velocity.x*flight)/(flight*flight)
  var gravity:float=2.0*(land.y-p.y-vy*flight)/(flight*flight)
  var part:={"id":i,"start":p,"land":land,"world":play_transform*land,"velocity":velocity,"gravity":Vector2(ax,gravity),"born":born,"flight":flight,"size":Vector2(rng.randi_range(1,3),rng.randi_range(1,2)),"source_color":source_color,"retained":i<residue_count and residue_seconds>0,"cut":rng.randf_range(0.0,0.16),"light":i%3==0}
  fragments.append(part)
  if part.retained:residue.append(part)
 sync_visuals()
func total_lifetime()->float:
 return duration+(residue_seconds if residue_count>0 else 0.0)
func clear_residue()->void:
 residue.clear();queue_redraw()
func advance(dt:float) -> void:
 if not playing or dt<=0 or not is_finite(dt):return
 if global_position.distance_to(play_origin)>teleport_distance:
  reset();return
 var current_generation:=generation
 elapsed=minf(total_lifetime(),elapsed+dt)
 if elapsed>=duration-0.000001 and not burst_done:
  burst_done=true;burst_finished.emit()
  if generation!=current_generation:return
 if elapsed>=total_lifetime()-0.000001:
  elapsed=total_lifetime();playing=false;finished=true;fragments.clear();residue.clear();completed.emit()
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
func fragment_world_position(part:Dictionary)->Vector2:
 var t:float=clampf(elapsed-part.born,0.0,part.flight)
 var p:Vector2=part.start+part.velocity*t+part.gravity*(0.5*t*t)
 return play_transform*p
func live_fragments() -> Array[Dictionary]:
 var result:Array[Dictionary]=[]
 if not playing:return result
 for part in fragments:
  var t:float=elapsed-part.born
  if t<0 or t>=part.flight:continue
  result.append({"id":part.id,"position":to_local(fragment_world_position(part)).floor(),"size":part.size,"color":part.source_color})
 return result
func live_residue()->Array[Dictionary]:
 var result:Array[Dictionary]=[]
 if not playing:return result
 var left:=total_lifetime()-elapsed
 for piece in residue:
  if elapsed>=piece.born+piece.flight and left>piece.cut:result.append(piece)
 return result
func _draw() -> void:
 for piece in live_residue():
  var settled:float=0.0 if elapsed-piece.born-piece.flight<0.08 else 0.65 if elapsed-piece.born-piece.flight<0.12 else 1.0
  var color:Color=piece.source_color.lerp(residue_highlight if piece.light else residue_color,settled)
  draw_rect(Rect2(to_local(piece.world).floor(),piece.size),color)
 for part in live_fragments():draw_rect(Rect2(part.position,part.size),part.color)
 if playing and not host_mode and elapsed<0.07:
  var r:=roundf(3.0+9.0*sin(PI*elapsed/0.07))
  var polygon:=PackedVector2Array([Vector2(-r,0),Vector2(-2,-2),Vector2(0,-r*0.65),Vector2(2,-2),Vector2(r,0),Vector2(2,2),Vector2(0,r*0.65),Vector2(-2,2)])
  for y in range(-int(r),int(r)+1):
   for x in range(-int(r),int(r)+1):
    if Geometry2D.is_point_in_polygon(Vector2(x+0.5,y+0.5),polygon):draw_rect(Rect2(x,y,1,1),tint)
