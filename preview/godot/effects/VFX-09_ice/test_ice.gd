extends SceneTree
const Ice=preload('res://effects/VFX-09_ice/ice.gd')
var checks:=0
func check(ok:bool,msg:String):
 checks+=1
 if not ok: push_error(msg);quit(1)
func _initialize(): call_deferred('run')
func run():
 var fx=Ice.new();root.add_child(fx);fx.auto_tick=false
 var cfg=Ice.sanitized({})
 check(cfg.count==5,'default count')
 check(cfg.irregularity==.75,'default asymmetric geometry')
 check(Ice.sanitized({'irregularity':INF}).irregularity==.75,'invalid irregularity fallback')
 check(Ice.sanitized({'irregularity':-1}).irregularity==0,'low irregularity cap')
 check(Ice.sanitized({'irregularity':10}).irregularity==1,'high irregularity cap')
 check(is_equal_approx(cfg.duration,1.02),'duration')
 var extreme=Ice.sanitized({'height':INF,'count':100,'width':-3,'seed':-100,'lightHex':'invalid'})
 check(extreme.height==34 and extreme.count==7 and extreme.width==2,'sanitize')
 fx.play(Vector2(10.3,20.2),{})
 check(fx.position==Vector2(10,20),'anchor snap')
 fx.tick(.1);fx.paused=true;fx.tick(.2);check(is_equal_approx(fx.age,.1),'pause')
 fx.paused=false;fx.tick(NAN);check(is_equal_approx(fx.age,.1),'nan delta')
 fx.seek(.4);check(is_equal_approx(fx.age,.4),'seek')
 fx.seek(10);check(not fx.active and not fx._rect.visible,'ends empty')
 fx.replay();check(fx.active and fx.age==0,'replay')
 fx.clear();check(not fx.active and fx.age==-1,'clear')
 fx.play(Vector2(INF,0),{});check(not fx.active,'invalid position')
 for fps in [30,60,144]:
  fx.play(Vector2.ZERO,{})
  for i in range(fps*2):fx.tick(1.0/fps)
  check(not fx.active and is_equal_approx(fx.age,cfg.duration),'frame rate end')
 for i in range(1000):
  fx.play(Vector2.ZERO,{'seed':i,'count':1+i%7});fx.tick(5)
  check(not fx.active and fx.get_child_count()==1,'bounded reuse')
 # Boundary durations remain positive and all endpoints clear.
 for count in [1,7]:
  for grow in [.06,.3]:
   for hold in [0.,1.]:
    for shatter in [.15,.7]:
     fx.play(Vector2.ZERO,{'count':count,'grow':grow,'hold':hold,'shatter':shatter,'stagger':.12})
     check(fx.settings.duration>0,'valid life')
     fx.tick(9);check(not fx._rect.visible,'max end')
 var lab=load('res://effects/VFX-09_ice/lab.tscn').instantiate();root.add_child(lab)
 lab._select_preset(1);check(lab.config.count==1,'preset')
 lab._toggle_pause();check(lab.paused,'UI pause')
 lab._step();check(lab.paused,'UI step')
 lab._clear();check(not lab.effects[0].fx.active and not lab.loop_enabled,'UI clear')
 lab._reset_defaults();check(lab.config.count==5 and lab.rate==1,'UI reset')
 lab.queue_free();fx.queue_free();await process_frame
 print('ICE_CHECKS_PASS ',checks);quit()
