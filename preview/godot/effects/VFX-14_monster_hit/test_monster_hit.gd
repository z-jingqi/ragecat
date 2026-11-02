extends SceneTree
const Hit=preload("res://effects/VFX-14_monster_hit/monster_hit.gd")
const Fixture=preload("res://effects/VFX-14_monster_hit/fixture.gd")
var checks:=0
func check(ok:bool,msg:String)->void:
 checks+=1
 if not ok:push_error(msg);quit(1)
func _initialize()->void:call_deferred("run")
func run()->void:
 var rootnode=Node2D.new();root.add_child(rootnode)
 var a=Sprite2D.new();a.texture=Fixture.texture();a.position=Vector2(20,20);a.scale=Vector2(1.2,0.9);a.modulate=Color(0.8,0.9,1,0.45);rootnode.add_child(a)
 var b=Sprite2D.new();b.texture=Fixture.texture(1);rootnode.add_child(b)
 var original=CanvasItemMaterial.new();a.material=original
 var ha=Hit.new();ha.auto_tick=false;rootnode.add_child(ha);ha.bind(a)
 var hb=Hit.new();hb.auto_tick=false;rootnode.add_child(hb);hb.bind(b)
 ha.configure({"color":"ff6600"});hb.configure({"color":"3399ff"})
 var transform=a.transform;var modulation=a.modulate
 check(ha.hit(Vector2(12,20),Vector2.RIGHT),"hit accepts valid host")
 check(a.material!=original,"host owns temporary flash")
 check(b.material==null,"other host unchanged")
 hb.hit(Vector2.ZERO,Vector2.RIGHT)
 check(a.material!=b.material,"no shared flashing material")
 check(ha.owned_material.get_shader_parameter("flash_color")!=hb.owned_material.get_shader_parameter("flash_color"),"independent colors")
 a.position.x+=10;ha.tick(0.02)
 check(ha.impacts[0].global_position==Vector2(12,20),"contact stays world location")
 check(a.scale==transform.get_scale() and a.modulate==modulation,"pose/alpha unmodified")
 ha.paused=true;var age=ha.flash.elapsed;ha.tick(1);check(ha.flash.elapsed==age,"paused")
 ha.paused=false;ha.tick(1);check(a.material==original,"restores original material")
 check(ha.active_count()==0,"impact ends")
 ha.configure({"flash_enabled":false});ha.hit(Vector2.ZERO,Vector2.ZERO);check(a.material==original,"particle only")
 ha.clear();ha.configure({"flash_enabled":true,"impact_enabled":false});ha.hit(Vector2.ZERO,Vector2.RIGHT);check(ha.active_count()==0,"body only")
 ha.clear();check(a.material==original,"clear restore")
 ha.configure({"impact_enabled":true})
 for i in 1000:
  ha.hit(Vector2(i%10,0),Vector2.RIGHT)
  check(ha.impacts.size()<=4,"pool bounded")
  ha.tick(0.001)
 ha.clear();check(a.material==original and ha.active_count()==0,"reset burst")
 ha.hit(Vector2.ZERO,Vector2.RIGHT)
 var replacement=CanvasItemMaterial.new();a.material=replacement;ha.clear();check(a.material==replacement,"external material not overwritten")
 for hz in [30,60,144]:
  ha.hit(Vector2.ZERO,Vector2.RIGHT)
  for i in hz:ha.tick(1.0/hz)
  check(not ha.flash.active and ha.active_count()==0,"frame rate end")
 ha.hit(Vector2.ZERO,Vector2.RIGHT);ha.bind(b);check(a.material==replacement,"rebind restores old")
 b.free();ha.tick(0.02);check(ha.active_count()==0,"destroyed host clears")
 check(not ha.hit(Vector2.ZERO,Vector2.ZERO),"invalid host reject")
 ha.bind(a);check(not ha.hit(Vector2(NAN,0),Vector2.ZERO),"bad contact reject")
 ha.hit(Vector2.ZERO,Vector2.RIGHT);ha.free();check(a.material==replacement,"exit restores")
 var demo=load("res://effects/VFX-14_monster_hit/monster_hit.tscn").instantiate();root.add_child(demo)
 demo.looping=false;demo.trigger(0)
 check(demo.players[0].flash.active and not demo.players[1].flash.active,"demo selected target")
 demo.reset_all();check(not demo.players[0].flash.active,"demo reset")
 demo.mode=1;demo.configure();demo.trigger(0);check(demo.players[0].active_count()==0,"demo body only")
 var hc=Hit.new();hc.auto_tick=false;rootnode.add_child(hc);hc.bind(a)
 check(hc.flash.peak==0.2,"restrained default")
 hc.hit(Vector2.ZERO,Vector2.RIGHT);hc.tick(0.03);var first_age=hc.flash.elapsed
 hc.hit(Vector2.ZERO,Vector2.RIGHT);check(hc.flash.elapsed==first_age,"repeat does not restart active flash")
 hc.tick(0.09);hc.hit(Vector2.ZERO,Vector2.RIGHT);check(not hc.flash.active,"cooldown suppresses strobe")
 hc.tick(0.07);hc.hit(Vector2.ZERO,Vector2.RIGHT);check(hc.flash.active,"flash resumes after interval")
 hc.clear();hc.configure({"peak":0,"impact":{"color":"3388bb","count":99,"distance":999,"life":-1}})
 hc.hit(Vector2.ZERO,Vector2.UP)
 var blood=hc.impacts[0]
 check(blood.settings.count==16 and blood.settings.distance==40 and blood.settings.life==0.06,"blood bounds")
 check(blood.settings.color=="3388bb","blood configurable color")
 check(hc.flash.amount()==0,"zero strength supported")
 hc.clear()
 var crowd:Array=[]
 for i in 12:
  var target=Sprite2D.new();target.texture=Fixture.texture();rootnode.add_child(target)
  var feedback=Hit.new();feedback.auto_tick=false;rootnode.add_child(feedback);feedback.bind(target);crowd.append(feedback)
 for frame in 240:
  for feedback in crowd:
   feedback.hit(Vector2.ZERO,Vector2.RIGHT);feedback.tick(1.0/60.0)
   check(feedback.impacts.size()<=4 and feedback.flash.amount()<=0.2,"crowd bounded and no brightness stacking")
 for feedback in crowd:
  feedback.clear();check(feedback.host.material==null and feedback.active_count()==0,"crowd restored")
 print("PASS monster hit checks: ",checks);quit()
