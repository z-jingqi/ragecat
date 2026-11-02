extends SceneTree
const Fire=preload("res://effects/VFX-07_fire_explosion/fire.gd")
var checks:=0
func _initialize()->void: call_deferred("run")
func ck(ok:bool,msg:String)->void:
 checks+=1
 if not ok:
  push_error(msg)
  quit(1)
  assert(ok,msg)
func run()->void:
 var presets=JSON.parse_string(FileAccess.get_file_as_string("res://effects/VFX-07_fire_explosion/presets.json")).presets
 var fx=Fire.new()
 fx.auto_tick=false
 root.add_child(fx)
 ck(not fx.active,"initial")
 for p in presets:
  for hz in [30,60,144]:
   fx.play(Vector2(0.1,0.9),p)
   var n:=0
   while fx.active and n<200:
    fx.tick(1.0/hz)
    n+=1
   ck(not fx.active,"finite end")
   ck(is_equal_approx(fx.age,p.duration),"exact duration")
   ck(abs(n/float(hz)-p.duration)<=1.0/hz+0.000001,"frame rate end")
   ck(not fx.get_child(0).visible,"empty end")
 fx.play(Vector2.ZERO,presets[0])
 fx.paused=true
 fx.tick(1)
 ck(fx.age==0,"pause")
 fx.paused=false
 fx.tick(0.03)
 fx.tick(-1); fx.tick(NAN); fx.tick(INF)
 ck(is_equal_approx(fx.age,0.03),"invalid dt")
 fx.playback_rate=0
 fx.tick(1)
 ck(is_equal_approx(fx.age,0.03),"zero rate")
 fx.playback_rate=0.25
 fx.tick(0.2)
 ck(is_equal_approx(fx.age,0.08),"quarter rate")
 fx.playback_rate=1
 for i in range(1000):
  fx.play(Vector2.ZERO,presets[0])
  fx.tick(0.01)
  fx.clear()
  ck(fx.get_child_count()==1 and not fx.active,"reuse bounded")
 fx.replay()
 ck(fx.active and fx.age==0,"replay after clear")
 fx.seek(0.1)
 ck(fx.active and fx.age==0.1,"seek")
 fx.seek(999)
 ck(not fx.active and not fx.get_child(0).visible,"seek beyond")
 fx.play(Vector2(NAN,0),{})
 ck(not fx.active,"invalid contact")
 var input=presets[0].duplicate(true)
 fx.play(Vector2.ZERO,input)
 input.radius=29
 ck(fx.settings.radius==18,"snapshot")
 var hi=Fire.sanitized({"radius":999,"rise":999,"duration":999,"embers":999,"lobes":999,"spread":999,"seed":99999})
 ck(hi.radius==30 and hi.rise==45 and hi.duration==0.85,"high clamp")
 ck(hi.embers==12 and hi.lobes==10 and hi.spread==1.5 and hi.seed==4095,"bounded loops")
 ck(Fire.extent_pixels(hi)<=173,"finite surface")
 var lo=Fire.sanitized({"radius":NAN,"duration":INF,"rise":-1,"embers":-1,"lobes":-1,"spread":"oops","coreHex":"invalid"})
 ck(lo.radius==18 and lo.duration==0.48 and lo.rise==0,"invalid fallback")
 ck(lo.embers==0 and lo.lobes==3 and lo.spread==1,"invalid count")
 ck(lo.coreHex=="#fff2ac","color fallback")
 var lab=load("res://effects/VFX-07_fire_explosion/lab.tscn").instantiate()
 root.add_child(lab)
 lab.set_process(false)
 lab._clear()
 ck(not lab.effects[0].fx.active,"lab clear")
 lab._select_preset(2)
 ck(lab.config.name=="heavy_burst","preset")
 lab._toggle_pause()
 ck(lab.paused,"ui pause")
 lab._step()
 ck(lab.paused and lab.effects[0].fx.age>0,"ui step")
 lab._reset_defaults()
 ck(not lab.paused and lab.config.radius==18 and lab.loop_enabled and lab.rate==1,"reset")
 lab.free(); fx.free()
 print("PASS fire lifecycle, config, UI: ",checks)
 quit()
