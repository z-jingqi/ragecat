extends SceneTree
const Critical=preload('res://effects/VFX-19_critical_hit/critical.gd')
var checks:=0
var finishes:=0
func check(v:bool,msg:String)->void:
 checks+=1
 if not v:push_error(msg);quit(1)
func _initialize()->void:call_deferred('run')
func run()->void:
 var ps=JSON.parse_string(FileAccess.get_file_as_string('res://effects/VFX-19_critical_hit/presets.json')).presets
 var fx=Critical.new();root.add_child(fx);fx.auto_tick=false
 fx.finished.connect(func():finishes+=1)
 for c in ps:
  fx.play(Vector2.ZERO,c);fx.tick(.06);var data=fx.image_buffer.get_data();var shapes=fx.shards.duplicate(true)
  fx.play(Vector2.ZERO,c);fx.tick(.06)
  check(data==fx.image_buffer.get_data() and shapes==fx.shards,'deterministic')
  for fps in [30,60,144]:
   fx.play(Vector2.ZERO,c)
   for n in range(fps):fx.tick(1.0/fps)
   check(not fx.active and fx.image_buffer.is_invisible(),'allfps complete')
   fx.play(Vector2.ZERO,c)
   for n in range(fps/6):fx.tick(1.0/fps)
   fx.tick(maxf(0,.1666667-fx.age))
   var actual=fx.image_buffer.get_data()
   fx.play(Vector2.ZERO,c);fx.tick(.1666667)
   check(actual==fx.image_buffer.get_data(),'fps analytic image')
  for t in [.01,.03,.075,.12,.19,.28,.4]:
   fx.play(Vector2.ZERO,c);fx.tick(t)
   for x in range(128):check(fx.image_buffer.get_pixel(x,0).a==0 and fx.image_buffer.get_pixel(x,127).a==0,'canvasbounds y')
   for y in range(128):check(fx.image_buffer.get_pixel(0,y).a==0 and fx.image_buffer.get_pixel(127,y).a==0,'canvasbounds x')
 var cfg=ps[0].duplicate(true);cfg.size=999;cfg.shards=999;cfg.intensity=99;cfg.peak=10
 fx.play(Vector2.ZERO,cfg);check(fx.config.size==36 and fx.shards.size()==12 and fx.config.intensity==.85,'clamps')
 cfg.intensity=0;fx.play(Vector2.ZERO,cfg);fx.tick(.05);check(fx.image_buffer.is_invisible(),'zero intensity disabled')
 cfg=ps[0].duplicate(true);cfg.shards=0;cfg.ring=0;fx.play(Vector2.ZERO,cfg);check(fx.shards.is_empty(),'zero shards')
 for i in range(100):
  fx.play(Vector2.ZERO,ps[0]);fx.tick(.05);fx.clear();check(not fx.active and fx.image_buffer.is_invisible(),'reuseclear')
 var before=finishes;fx.play(Vector2.ZERO,ps[0]);fx.tick(1);fx.tick(1);check(finishes==before+1,'finish once')
 fx.play(Vector2.ZERO,ps[0]);fx.tick(-1);fx.tick(NAN);check(fx.age==0,'invaliddt')
 fx.play(Vector2.ZERO,ps[0]);fx.playback_rate=0;fx.tick(.1);check(fx.age==0,'pause');fx.playback_rate=1
 var other=Critical.new();root.add_child(other);other.auto_tick=false;other.play(Vector2.ONE,ps[1]);other.tick(.05);var od=other.image_buffer.get_data();fx.tick(.1);fx.clear();check(od==other.image_buffer.get_data(),'independent overlap')
 var scene=load('res://effects/VFX-19_critical_hit/lab.tscn').instantiate();root.add_child(scene);scene.set_process(false)
 scene._toggle_pause();check(scene.paused,'pauseUI');scene._step();check(scene.paused,'stepUI');scene._clear();check(not scene.effects[0].fx.active,'clearUI');scene._select_preset(2);check(scene.config.size==35,'presetUI');scene._reset_defaults();check(scene.config.size==30,'resetUI')
 scene.multi_hit=true;scene.play();scene._process(.1);check(scene.echoes[0].fx.active and scene.echoes[1].fx.active,"overlap preview")
 scene._clear();check(not scene.echoes[0].fx.active,"clear overlaps")
 scene._reset_defaults();check(not scene.multi_hit,"reset overlaps")
 for i in range(10):
  fx.play(Vector2.ZERO,ps[0]);fx.tick(i*.04);fx.image_buffer.save_png('/workspace/scratch/96298ac95ed1/critical-hit-qa/phase_%02d.png'%i)
 print('CRITICAL CHECKS ',checks);quit()
