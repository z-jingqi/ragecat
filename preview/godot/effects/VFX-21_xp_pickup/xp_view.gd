extends Node2D
var state: RefCounted
var zoom := 1.0
var camera := Vector2.ZERO
var origin := Vector2.ZERO
var show_target := true
func pixel(p: Vector2, size: Vector2, color: Color) -> void:
 draw_rect(Rect2(origin+(p-camera).round()*zoom,size*zoom),color)
func segment(a: Vector2,b: Vector2,color:Color,width:int=1) -> void:
 var delta:=b-a
 var steps:=maxi(1,int(maxf(absf(delta.x),absf(delta.y))))
 for j in range(steps+1):pixel(a+delta*float(j)/steps,Vector2(width,width),color)
func _draw() -> void:
 if state==null:return
 var cfg:Dictionary=state.config
 var dark:=Color(cfg.color_dark);var body:=Color(cfg.color_body);var light:=Color(cfg.color_light)
 if show_target:
  var c:Vector2=state.target
  # A quiet collector marker is demo-only, not an effect layer.
  segment(c+Vector2(-7,0),c+Vector2(0,-4),Color("73818b"))
  segment(c+Vector2(0,-4),c+Vector2(7,0),Color("73818b"))
  segment(c+Vector2(7,0),c+Vector2(0,4),Color("73818b"))
  segment(c+Vector2(0,4),c+Vector2(-7,0),Color("73818b"))
 for g in state.gems:
  var c:Vector2=g.pos
  if g.phase==3:
   var u:float=g.age/float(cfg.arrival_seconds)
   var r:=2.0+u*6.0
   var len:=maxf(1.0,3.0*(1.0-u))
   for d in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN]:segment(c+d*r,c+d*(r+len),light if u<0.5 else body)
   continue
  var path:Array=g.path
  for j in range(1,path.size()):
   if j%2==0 or j>path.size()/2:segment(path[j-1],path[j],body if j>path.size()*0.65 else dark)
  if g.phase==1 or g.phase==0:pixel(g.ground+Vector2(-3,3),Vector2(6,1),Color("142b2c"))
  var radius:=int(cfg.radius)
  for y in range(-radius,radius+1):
   var half:=radius-absi(y)
   for x in range(-half,half+1):
    var color:=dark if x>0 or y>0 else body
    if x<0 and y<0 and absi(x)+absi(y)<radius:color=light
    pixel(c+Vector2(x,y),Vector2.ONE,color)
  pixel(c+Vector2(0,-radius),Vector2.ONE,light)
