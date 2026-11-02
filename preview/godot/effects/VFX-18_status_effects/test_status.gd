extends SceneTree
const Effect=preload("res://effects/VFX-18_status_effects/status_effect.gd")
const Fixture=preload("res://effects/VFX-05_hit_flash/hero_fixture.gd")
var checks:=0
func ck(v:bool,msg:String)->void:
 checks+=1
 if not v:push_error(msg);quit(1)
func _initialize()->void:call_deferred("run")
func run()->void:
 var h:=Sprite2D.new();h.texture=Fixture.texture();root.add_child(h)
 var original:=CanvasItemMaterial.new();h.material=original
 var f:=Effect.new();root.add_child(f);f.bind_host(h)
 ck(h.material==original,"material untouched")
 for k in Effect.KINDS:ck(f.apply_status(k,1.0),"apply "+k)
 f.tick(0.3);ck(f.states.size()==4,"combination")
 ck(h.self_modulate.r<=1.0 and h.self_modulate.a==1.0,"no additive brightness")
 var age:float=f.states.burning.age;f.apply_status("burning",2,99);ck(f.states.burning.age==age,"refresh keeps phase");ck(f.states.burning.stacks==5,"stack clamp")
 f.remove_status("poison");f.tick(0.3);ck(not f.states.has("poison"),"remove only one");ck(f.states.has("burning"),"others persist")
 f.clear_all();ck(f.states.is_empty(),"clear");ck(h.material==original,"restore original")
 h.hframes=2;h.frame=1;h.flip_h=true;h.offset=Vector2(2,3);h.self_modulate.a=0.4
 f.apply_status("frozen",0.5);f.tick(0.1)
 ck(h.frame==1 and h.flip_h and h.offset==Vector2(2,3),"pose unchanged")
 ck(is_equal_approx(h.self_modulate.a,0.4),"alpha preserved")
 f.tick(1);ck(f.states.is_empty(),"expiry")
 for fps in [30,60,144]:
  f.clear_all();f.apply_status("shock",1)
  for i in range(fps*2):f.tick(1.0/fps)
  ck(f.states.is_empty(),"fps expiry")
 for i in range(500):
  f.apply_status(Effect.KINDS[i%4],0.05);f.tick(0.04);f.clear_all()
  ck(f.states.is_empty() and h.material==original,"reuse")
 f.configure({"intensity":9,"density":999,"enter_time":-1,"exit_time":NAN});ck(f.intensity==0.65 and f.density==16 and f.enter_time==0.03,"bounds")
 ck(not f.apply_status("bad",1),"unknown rejected")
 ck(not f.apply_status("shock",NAN),"nan rejected")
 f.clear_all();h.self_modulate=Color(0.6,0.7,0.8,0.3);f.apply_status("poison",1);f.tick(0.2)
 f.clear_all();ck(h.self_modulate.is_equal_approx(Color(0.6,0.7,0.8,0.3)),"external change becomes new base")
 f.apply_status("burning",1);h.free();f.tick(0.1);ck(f.states.is_empty() and f.host==null,"host destroyed")
 f.free()
 print("STATUS CHECKS PASSED ",checks);quit()
