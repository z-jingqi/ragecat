extends Node2D
## Source pixels stay in the body until their own release time, then become dust.
signal completed
var release_seconds:=0.48
var dust_seconds:=0.62
var wind_speed:=34.0
var wind_acceleration:=38.0
var wind_degrees:float=0.0
var release_degrees:float=-180.0
var lift:=8.0
var turbulence:=3.0
var density:=1.0
var seed_value:=23
var use_host_colors:=true
var dust_color:=Color("82717c")
var ember_color:=Color("e8c48a")
var ember_fraction:=0.025
var flipped:=false
var mode:="disintegrate"
var show_source:=true
var elapsed:=0.0
var active:=false
var finished:=false
var source:Image
var pixels:Array[Dictionary]=[]
var source_pixels:Array[Dictionary]=[]
var play_transform:=Transform2D.IDENTITY
var play_origin:=Vector2.ZERO
var generation:=0
func finite(value:Variant,fallback:float)->float:
 var n:=float(value) if value is float or value is int else fallback
 return n if is_finite(n) else fallback
func configure(v:Dictionary)->void:
 release_seconds=clampf(finite(v.get("release_seconds",release_seconds),release_seconds),0.08,1.5)
 dust_seconds=clampf(finite(v.get("dust_seconds",dust_seconds),dust_seconds),0.1,2.0)
 wind_speed=clampf(finite(v.get("wind_speed",wind_speed),wind_speed),0,100)
 wind_acceleration=clampf(finite(v.get("wind_acceleration",wind_acceleration),wind_acceleration),0,100)
 wind_degrees=wrapf(finite(v.get("wind_degrees",wind_degrees),wind_degrees),-180,180)
 release_degrees=wrapf(finite(v.get("release_degrees",release_degrees),release_degrees),-180,180)
 lift=clampf(finite(v.get("lift",lift),lift),-50,50)
 turbulence=clampf(finite(v.get("turbulence",turbulence),turbulence),0,8)
 density=clampf(finite(v.get("density",density),density),0,1)
 ember_fraction=clampf(finite(v.get("ember_fraction",ember_fraction),ember_fraction),0,0.15)
 seed_value=clampi(int(finite(v.get("seed",seed_value),seed_value)),0,65535)
 use_host_colors=bool(v.get("use_host_colors",use_host_colors));flipped=bool(v.get("flipped",flipped))
 if v.has("dust_color"):dust_color=Color.from_string(str(v.dust_color),dust_color)
 if v.has("ember_color"):ember_color=Color.from_string(str(v.ember_color),ember_color)
 if str(v.get("mode",mode)) in ["disintegrate","materialize"]:mode=str(v.get("mode",mode))
 reset()
func set_host(image:Image)->bool:
 if image==null or image.is_empty() or image.get_width()>64 or image.get_height()>64:return false
 source=image.duplicate();source_pixels.clear()
 for y in source.get_height():
  for x in source.get_width():
   var c:=source.get_pixel(x,y)
   if c.a>0:source_pixels.append({"position":Vector2(x-source.get_width()/2.0,y-source.get_height()/2.0).floor(),"color":c})
 reset();return true
func reset()->void:
 generation+=1;elapsed=0;active=false;finished=false;pixels.clear();show_source=mode=="disintegrate";queue_redraw()
func cancel()->void:
 reset();show_source=true;queue_redraw()
func sample_time()->float:
 return total_lifetime()-elapsed if mode=="materialize" else elapsed
func play()->void:
 reset();active=true;play_transform=global_transform;play_origin=global_position
 var rng:=RandomNumberGenerator.new();rng.seed=seed_value
 var dir:=Vector2.from_angle(deg_to_rad(release_degrees))
 var size:=Vector2(source.get_width(),source.get_height()) if source!=null else Vector2.ONE
 for i in source_pixels.size():
  var item:Dictionary=source_pixels[i]
  var p:Vector2=item.position
  if flipped:p.x=source.get_width()-1+2*floorf(-source.get_width()/2.0)-p.x
  var uv:Vector2=(p+Vector2.ONE*0.5)/size
  var projected:float=clampf(uv.dot(dir)/(absf(dir.x)+absf(dir.y))+0.5,0,1)
  var born:float=release_seconds*(0.05+0.9*(projected*0.8+rng.randf()*0.2))
  pixels.append({"id":i,"position":p,"color":item.color,"born":born,"life":dust_seconds*rng.randf_range(0.65,1.0),"speed":rng.randf_range(0.75,1.25),"phase":rng.randf()*TAU,"frequency":rng.randf_range(8,14),"visible":rng.randf()<density,"ember":rng.randf()<ember_fraction})
 queue_redraw()
func total_lifetime()->float:return release_seconds+dust_seconds
func advance(dt:float)->void:
 if not active or dt<=0 or not is_finite(dt):return
 if global_position.distance_to(play_origin)>128:reset();return
 elapsed=minf(elapsed+dt,total_lifetime())
 if elapsed>=total_lifetime()-0.000001:
  elapsed=total_lifetime();active=false;finished=true;pixels.clear();show_source=mode=="materialize";completed.emit()
 queue_redraw()
func particle_position(item:Dictionary)->Vector2:
 var age:float=maxf(0,sample_time()-item.born)
 var wind:=Vector2.from_angle(deg_to_rad(wind_degrees))
 var normal:=Vector2(-wind.y,wind.x)
 var curl:float=turbulence*(sin(item.phase+age*item.frequency)-sin(item.phase))*minf(age*8.0,1.0)
 var p:Vector2=item.position+wind*item.speed*(wind_speed*age+0.5*wind_acceleration*age*age)+Vector2(0,-lift*age)+normal*curl
 return to_local(play_transform*p.floor()).round()
func render_pixels()->Array[Dictionary]:
 var output:Array[Dictionary]=[]
 if not active and not show_source:return output
 if not active:
  for item in source_pixels:
   var p:Vector2=item.position
   if flipped:p.x=source.get_width()-1+2*floorf(-source.get_width()/2.0)-p.x
   output.append({"id":-1,"position":p,"color":item.color,"dust":false})
  return output
 for item in pixels:
  var age:float=sample_time()-item.born
  if age<0:
   output.append({"id":item.id,"position":to_local(play_transform*item.position).floor(),"color":item.color,"dust":false})
  elif age<item.life and item.visible:
   var c:Color=item.color if use_host_colors else ember_color
   if age>item.life*0.32:c=c.lerp(dust_color,0.55)
   if age>item.life*0.68:c=dust_color
   if item.ember and age<0.14:c=ember_color
   c.a=item.color.a
   output.append({"id":item.id,"position":particle_position(item),"color":c,"dust":true})
 return output
func _draw()->void:
 for item in render_pixels():draw_rect(Rect2(item.position,Vector2.ONE),item.color)
