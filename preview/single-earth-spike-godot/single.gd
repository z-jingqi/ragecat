extends Node2D
signal finished
const Profile=preload("profile.gd")
const Canvas=preload("canvas.gd")
var profile:Resource=Profile.new()
var canvas:Node2D
var spike:Dictionary={}
var age:float=0
var seed_value:int=17
var running:bool=false
var emitted:bool=false
func configure(p:Resource)->void:
 profile=p.clean()
 if canvas: _build(); seek(age)
func play(center:Vector2,seed_number:int=17)->void:
 position=center if center.is_finite() else Vector2.ZERO; seed_value=seed_number; age=0; running=true; emitted=false; _build(); seek(0)
func _build()->void:
 _clear_nodes()
 var rng:RandomNumberGenerator=RandomNumberGenerator.new(); rng.seed=seed_value
 spike={"pos":Vector2.ZERO,"height":42*profile.size,"width":27*profile.size,"lean":.10,"variant":rng.randf(),"seed":seed_value,"direction":Vector2.RIGHT,"spawn":.2}
 canvas=Canvas.new(); canvas.spike=spike; canvas.profile=profile; add_child(canvas)
func seek(t:float)->void:
 if not is_finite(t): return
 age=maxf(t,0)
 if canvas: running=true
 if age<profile.lifetime(): emitted=false
 if canvas: canvas.age=age-.2; canvas.queue_redraw()
func advance(delta:float)->void:
 if not running or not is_finite(delta) or delta<=0: return
 seek(age+delta)
 if age>=profile.lifetime():
  running=false
  if not emitted: emitted=true; finished.emit()
func clear()->void:
 running=false; age=0; emitted=false; _clear_nodes()
func _clear_nodes()->void:
 if is_instance_valid(canvas): remove_child(canvas); canvas.free()
 canvas=null; spike.clear()
