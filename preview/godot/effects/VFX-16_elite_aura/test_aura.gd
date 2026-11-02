extends SceneTree
const Aura=preload("res://effects/VFX-16_elite_aura/aura.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String) -> void:
 checks+=1
 if not ok:failures+=1;push_error(message)
func _initialize() -> void:
 var fx=Aura.new();fx.automatic=false;root.add_child(fx)
 fx.play(Vector2(32,48));check(fx.active,"starts");check(fx.strength()==0,"no pop start")
 fx.tick(0.09);check(fx.strength()>0 and fx.strength()<1,"formation")
 fx.tick(0.2);check(fx.strength()==1,"sustain")
 fx.stop();fx.tick(0.1);check(fx.strength()>0 and fx.strength()<1,"exit envelope")
 fx.tick(2);check(not fx.active,"clear")
 for fps in [30,60,144]:
  fx.play(Vector2.ZERO)
  for i in range(fps*4):fx.tick(1.0/fps)
  check(not fx.active,"fps completes")
 var host:=Node2D.new();root.add_child(host);host.position=Vector2(20,30)
 fx.play(Vector2.ZERO,{},host,Vector2(0,4));fx.tick(0.1);check(fx.anchor==Vector2(20,34),"foot offset")
 host.position=Vector2(55,70);fx.tick(0.1);check(fx.anchor==Vector2(55,74),"host follows")
 fx.configure({"radius":INF,"height":-4,"particles":999,"core":"invalid"});check(fx.config.radius==23,"nonfinite");check(fx.config.height==16,"height clamp");check(fx.config.particles==32,"bounded");check(fx.config.core==Aura.DEFAULTS.core,"color clamp")
 for i in range(1000):
  fx.play(Vector2.ZERO,{"seed":i});fx.tick(0.2);check(fx.active,"reuse");fx.clear();check(not fx.active,"clear reuse")
 fx.play(Vector2.ZERO,{},host);host.free();fx.tick(0.1);check(not fx.active,"lost host clear")
 print("Elite aura checks ",checks," failures ",failures);quit(1 if failures else 0)
