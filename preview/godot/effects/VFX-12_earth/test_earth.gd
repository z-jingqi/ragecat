extends SceneTree
const Earth=preload('res://effects/VFX-12_earth/earth.gd')
var checks:=0
func check(v:bool,msg:String)->void:
 checks+=1
 if not v:push_error(msg);quit(1)
func _initialize()->void:
 call_deferred('run')
func run()->void:
 var p=JSON.parse_string(FileAccess.get_file_as_string('res://effects/VFX-12_earth/presets.json')).presets
 var fx=Earth.new();root.add_child(fx);fx.auto_tick=false
 for c in p:
  fx.play(Vector2.ZERO,c);fx.tick(.2)
  var first=fx.image_buffer.get_data();var geometry=fx.cracks.duplicate(true)
  fx.play(Vector2.ZERO,c);fx.tick(.2)
  check(first==fx.image_buffer.get_data(),'seed deterministic raster')
  check(geometry==fx.cracks,'seed deterministic geometry')
  for fps in [30,60,144]:
   fx.play(Vector2.ZERO,c)
   for n in range(fps*2):fx.tick(1.0/fps)
   check(not fx.active,'all frame rates finish');check(fx.image_buffer.is_invisible(),'end empty')
  for age in [.01,.08,.15,.3,.5,.75]:
   fx.play(Vector2.ZERO,c);fx.tick(age)
   for x in range(160):check(fx.image_buffer.get_pixel(x,0).a==0 and fx.image_buffer.get_pixel(x,127).a==0,'vertical bound')
   for y in range(128):check(fx.image_buffer.get_pixel(0,y).a==0 and fx.image_buffer.get_pixel(159,y).a==0,'horizontal bound')
 var c=p[0].duplicate(true);c.radius=100;c.rocks=999;c.height=999;c.dust=999;c.branches=999
 fx.play(Vector2.ZERO,c);check(fx.config.radius==52 and fx.rocks.size()==18 and fx.dust.size()==14 and fx.cracks.size()==12,'bounded config')
 for dur in [.5,1.4]:
  c.duration=dur
  fx.play(Vector2.ZERO,c)
  for r in fx.rocks:check(r.delay+r.life*1.4<=dur,'rocks settle before duration')
  fx.tick(dur-.001)
  check(fx.active,'alive until exact end')
  fx.tick(.002);check(not fx.active and fx.image_buffer.is_invisible(),'exact end clears')
 for n in range(100):
  fx.play(Vector2.ZERO,p[0]);fx.tick(.12);fx.clear();check(fx.image_buffer.is_invisible(),'reset clears');check(not fx.active,'no active after clear')
 fx.play(Vector2.ZERO,p[0]);fx.tick(-1);check(fx.age==0,'negative delta ignored')
 for i in range(10):
  fx.play(Vector2.ZERO,p[0]);fx.tick(i*.1);fx.image_buffer.save_png('/workspace/scratch/96298ac95ed1/earth-qa/phase_%02d.png'%i)
 var scene=load('res://effects/VFX-12_earth/lab.tscn').instantiate();root.add_child(scene);scene.set_process(false)
 scene._toggle_pause();check(scene.paused,'pause');scene._step();check(scene.paused,'step remains paused');scene._clear();check(not scene.effects[0].fx.active,'clear UI');scene._select_preset(2);check(scene.effects[0].fx.config.radius==49,'preset');scene._reset_defaults();check(scene.config.radius==42,'reset')
 print('EARTH CHECKS ',checks);quit()
