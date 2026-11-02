extends Node2D
## Samples a Sprite2D's actual frame and transform. No gameplay movement or invulnerability.
var interval:=0.035
var lifetime:=0.22
var hold:=0.025
var max_images:=8
var opacity:=0.62
var tint:=Color("7bdfeb")
var end_tint:=Color("493f80")
var color_mix:=0.85
var minimum_distance:=2.0
var teleport_distance:=80.0
# Brief directional accents share the actual path; never a full slash or beam.
var speed_lines:=true
var line_length:=18.0
var line_spread:=14.0
var line_opacity:=0.8
var line_lifetime:=0.09
var minimum_speed:=100.0
var accents:Array[Dictionary]=[]
var sample_serial:=0
var enabled:=false
var clock:=0.0
var next_sample:=0.0
var snapshots:Array[Dictionary]=[]
var pool:Array[Sprite2D]=[]
var previous_transform:=Transform2D.IDENTITY
var previous_position:=Vector2.ZERO
var last_emission:=Vector2.INF
var initialized:=false
const SHADER=preload("res://effects/VFX-06_dodge_afterimage/afterimage.gdshader")
func start(host:Sprite2D)->void:
 reset();enabled=true
 if is_instance_valid(host):
  previous_transform=host.global_transform;previous_position=host.global_position;initialized=true
func stop()->void: enabled=false
func reset()->void:
 enabled=false;clock=0.0;next_sample=0.0;initialized=false;last_emission=Vector2.INF
 for p in pool: p.visible=false
 accents.clear();sample_serial=0;queue_redraw()
 snapshots.clear()
func configure()->void:
 interval=clampf(interval,0.01,0.2);lifetime=clampf(lifetime,0.03,1.0);hold=clampf(hold,0,lifetime*0.5)
 max_images=clampi(max_images,1,24);opacity=clampf(opacity,0,1);color_mix=clampf(color_mix,0,1)
 line_length=clampf(line_length,2,36);line_spread=clampf(line_spread,0,32)
 line_opacity=clampf(line_opacity,0,1);line_lifetime=clampf(line_lifetime,0.02,0.25);minimum_speed=maxf(0,minimum_speed)
 minimum_distance=maxf(0,minimum_distance);teleport_distance=maxf(4,teleport_distance)
func advance(delta:float,host)->void:
 if delta<=0:return
 configure()
 var old:=clock;clock+=delta
 if not is_instance_valid(host) or host.texture==null:
  enabled=false
 else:
  var current:Transform2D=host.global_transform
  if initialized and current.origin.distance_to(previous_position)>teleport_distance:
   for p in pool:p.visible=false
   snapshots.clear();accents.clear();last_emission=Vector2.INF;next_sample=clock+interval
  if enabled and initialized:
   # Bound work even after long application stalls. Sample only still-visible history.
   next_sample=maxf(next_sample,clock-lifetime)
   var iterations:=0
   while next_sample<=clock+0.000001 and iterations<128:
    var a:=clampf((next_sample-old)/delta,0,1)
    var tr:=previous_transform.interpolate_with(current,a)
    if last_emission==Vector2.INF or tr.origin.distance_to(last_emission)>=minimum_distance:
     capture(host,tr,next_sample)
     var velocity:Vector2=(current.origin-previous_position)/delta
     if speed_lines and velocity.length()>=minimum_speed and host.is_visible_in_tree():
      var direction:=velocity.normalized()
      # Alternating deterministic offsets break the ladder-like regularity.
      var flank:float=[-1.0,0.7,-0.4,1.0][sample_serial%4]
      var origin:=tr.origin-direction*7+direction.orthogonal()*line_spread*flank
      accents.append({"origin":origin,"direction":direction,"born":next_sample,"length":line_length*[0.7,1.0,0.5,0.85][sample_serial%4],"alpha":host.modulate.a*host.self_modulate.a,"z":host.z_index-1})
      sample_serial+=1
      while accents.size()>24:accents.pop_front()
     last_emission=tr.origin
    next_sample+=interval;iterations+=1
  previous_transform=current;previous_position=current.origin;initialized=true
 for i in range(snapshots.size()-1,-1,-1):
  var s:Dictionary=snapshots[i]
  var age:float=clock-s.born
  if age>=lifetime:
   s.node.visible=false;snapshots.remove_at(i);continue
  var p:=clampf((age-hold)/maxf(0.001,lifetime-hold),0,1)
  var m:ShaderMaterial=s.node.material
  m.set_shader_parameter("fade",opacity*pow(1-p,1.4))
  m.set_shader_parameter("tone",tint.lerp(end_tint,p))
  m.set_shader_parameter("color_mix",color_mix)
 for i in range(accents.size()-1,-1,-1):
  if clock-float(accents[i].born)>=line_lifetime-0.000001:accents.remove_at(i)
 queue_redraw()
func _draw()->void:
 for a in accents:
  var progress:=clampf((clock-float(a.born))/line_lifetime,0,1)
  var direction:Vector2=a.direction
  var tip:Vector2=a.origin-direction*progress*4
  var length:float=float(a.length)*(1-progress*0.75)
  var color:=tint.lerp(end_tint,progress);color.a*=line_opacity*float(a.alpha)*(1-progress)
  # Rasterize a one-pixel stepped stroke; no antialiased diagonal lines.
  for j in int(ceil(length)):
   var point:Vector2=(tip-direction*j).round()
   draw_rect(Rect2(to_local(point),Vector2.ONE),color)
func capture(host:Sprite2D,tr:Transform2D,born:float)->void:
 if not host.is_visible_in_tree():return
 while snapshots.size()>=max_images:
  snapshots[0].node.visible=false;snapshots.pop_front()
 var n:Sprite2D
 for p in pool:
  if not p.visible:n=p;break
 if n==null:
  n=Sprite2D.new();n.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;n.top_level=true
  var m:=ShaderMaterial.new();m.shader=SHADER;n.material=m;add_child(n);pool.append(n)
 var image:=host.texture.get_image()
 if image==null:return
 # A copy of the actual source frame, not a live reference to the host's animation.
 var rect:=Rect2i(Vector2i.ZERO,image.get_size())
 if host.region_enabled:rect=Rect2i(host.region_rect)
 var cell:=Vector2i(rect.size.x/host.hframes,rect.size.y/host.vframes)
 rect=Rect2i(rect.position+Vector2i(host.frame_coords)*cell,cell)
 rect=rect.intersection(Rect2i(Vector2i.ZERO,image.get_size()))
 if not rect.has_area():return
 n.texture=ImageTexture.create_from_image(image.get_region(rect));n.centered=host.centered;n.offset=host.offset
 n.flip_h=host.flip_h;n.flip_v=host.flip_v;n.global_transform=tr
 n.global_position=n.global_position.round();n.modulate=host.modulate*host.self_modulate
 n.z_index=host.z_index-1;n.z_as_relative=false;n.visible=true
 snapshots.append({"node":n,"born":born,"transform":tr,"frame":host.frame,"flip_h":host.flip_h,"offset":host.offset})
