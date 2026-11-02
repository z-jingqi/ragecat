extends SceneTree
const FX=preload("res://effects/VFX-22_level_up/level_up.gd")
var checks:=0
var failures:=0
var peaks:=0
var ends:=0
func check(v:bool,msg:String):
 checks+=1
 if not v:failures+=1;push_error(msg)
func _initialize():call_deferred("run")
func run():
 var f=FX.new();f.automatic=false;root.add_child(f)
 f.peak.connect(func():peaks+=1);f.finished.connect(func():ends+=1)
 for hz in [30,60,144]:
  f.play(Vector2(64,108));var before:=peaks
  var n:=0
  while f.active and n<1000:f.tick(1.0/hz);n+=1
  check(not f.active,"ends");check(peaks==before+1,"one peak");check(absf(float(n)/hz-f.duration)<=1.0/hz+0.0001,"fps duration")
 var host:=Node2D.new();root.add_child(host);host.position=Vector2(40,60)
 f.play(Vector2.ZERO,{},host,Vector2(2,3));check(f.anchor==Vector2(42,63),"immediate anchor");f.tick(0.01);check(f.anchor==Vector2(42,63),"host offset")
 host.position+=Vector2(5,8);f.tick(0.01);check(f.anchor==Vector2(47,71),"follow")
 host.free();f.tick(0.01);check(not f.active,"host deletion clears")
 f.play(Vector2.ZERO);var a:float=f.age
 for dt in [-1.0,0.0,NAN,INF]:f.tick(dt);check(f.age==a,"invalid dt")
 f.configure({"core":"00ff00","body":"3080e0","edge":"ab2080"})
 check(f.config.core=="00ff00" and f.config.body=="3080e0" and f.config.edge=="ab2080","three palette channels")
 check(is_equal_approx(f.color("core").g,0.62) and f.color("core").r==0,"palette rendered")
 f.configure({"core_width":99,"glints":99,"pulse_amount":99})
 check(f.config.core_width==4 and f.config.glints==12 and is_equal_approx(f.config.pulse_amount,0.15),"new control bounds")
 f.configure({"radius":999,"height":-1,"intensity":2,"particles":999,"rings":-4,"core":"badcolor","charge":NAN})
 check(f.config.radius==40 and f.config.height==30,"clamp size")
 check(f.config.particles==32 and f.config.rings==0,"bounds")
 check(is_equal_approx(f.config.intensity,0.85) and f.config.core==FX.DEFAULTS.core,"palette intensity")
 check(f.config.charge==FX.DEFAULTS.charge,"nan fallback")
 f.play(Vector2.ZERO,{"seed":71});var randoms:=[]
 for i in range(100):randoms.append(f.rnd(i,3))
 f.play(Vector2.ZERO,{"seed":71})
 for i in range(100):check(f.rnd(i,3)==randoms[i],"repeat seed")
 for i in range(1000):
  f.play(Vector2.ZERO);f.tick(0.04);f.clear();check(not f.active and f.host==null,"reuse clear")
 var reenter:Callable=func():f.play(Vector2(1,2),{"charge":0.8})
 f.peak.connect(reenter);f.play(Vector2.ZERO);f.tick(10)
 check(f.active and f.age==0 and f.anchor==Vector2(1,2),"peak reentry")
 f.peak.disconnect(reenter)
 for r in [10,25,40]:
  for h in [30,72,88]:
   for n in [0,18,32]:
    f.play(Vector2.ZERO,{"radius":r,"height":h,"particles":n,"rings":4});f.tick(20);check(not f.active,"extremes finish")
 var completed:Callable=func():f.play(Vector2(3,4))
 f.finished.connect(completed);f.play(Vector2.ZERO);f.tick(20)
 check(f.active and f.age==0 and f.anchor==Vector2(3,4),"finish reentry")
 f.finished.disconnect(completed)
 f.clear();var end_before:=ends;f.tick(20);check(ends==end_before,"clear no completion")
 f.free();print("LEVEL UP CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
