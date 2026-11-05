extends Node2D
signal finished
const Profile=preload("profile.gd")
const Canvas=preload("canvas.gd")
var profile:Resource=Profile.new()
var sites:Array[Dictionary]=[]
var canvases:Array[Node2D]=[]
var age:float=0
var seed_value:int=17
var running:bool=false
var emitted:bool=false
func _init()->void: y_sort_enabled=true
func configure(p:Resource)->void:
 profile=p.clean()
 if not sites.is_empty(): _build(); seek(age)
func play(center:Vector2,seed_number:int=17)->void:
 position=center if center.is_finite() else Vector2.ZERO; seed_value=seed_number; age=0; running=true; emitted=false; _build(); seek(0)
func _build()->void:
 _clear_nodes()
 var rng:RandomNumberGenerator=RandomNumberGenerator.new(); rng.seed=seed_value
 for i in profile.count:
  var angle:float=TAU*(i+rng.randf_range(-.12,.12))/profile.count
  var radius:float=profile.radius+rng.randf_range(-2,2)
  var direction:Vector2=Vector2(cos(angle),sin(angle)*.5).normalized()
  var at:Vector2=Vector2(cos(angle)*radius,sin(angle)*radius*.5)
  var s:Dictionary={"pos":Vector2.ZERO,"height":rng.randf_range(28,35)*profile.size,"width":rng.randf_range(13,17)*profile.size,"lean":cos(angle)*.13,"variant":rng.randf(),"seed":rng.randi(),"direction":direction,"spawn":.08+rng.randf_range(0,.008),"anchor":at}
  sites.append(s)
  var c:Node2D=Canvas.new(); c.spike=s; c.profile=profile; c.position=at; add_child(c); canvases.append(c)
func seek(t:float)->void:
 if not is_finite(t): return
 age=maxf(t,0)
 if not sites.is_empty(): running=true
 if age<profile.lifetime(): emitted=false
 for i in canvases.size(): canvases[i].age=age-sites[i].spawn; canvases[i].queue_redraw()
func advance(delta:float)->void:
 if not running or not is_finite(delta) or delta<=0: return
 seek(age+delta)
 if age>=profile.lifetime():
  running=false
  if not emitted: emitted=true; finished.emit()
func clear()->void:
 running=false; age=0; emitted=false; _clear_nodes()
func _clear_nodes()->void:
 for c in canvases: remove_child(c); c.free()
 canvases.clear(); sites.clear()
