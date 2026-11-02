extends SceneTree
const Effect=preload("res://effects/particle_reveals/particle_reveals.gd")
const Host=preload("res://effects/particle_reveals/demo_host.gd")
const Demo=preload("res://effects/particle_reveals/demo.gd")
var checks:=0
var failures:=0
func check(ok:bool,msg:String)->void:
 checks+=1
 if not ok:failures+=1;push_error(msg)
func _initialize()->void:call_deferred("run")
func normalized(records:Array)->Array:
 var a:=[]
 for p in records:a.append([p.position,p.color,p.dust])
 return a
func run()->void:
 var a:=Effect.new();var b:=Effect.new();root.add_child(a);root.add_child(b)
 check(a.set_host(Host.create_image()),"accept host");b.set_host(Host.create_image())
 check(not a.set_host(null),"reject null");check(not a.set_host(Image.create(65,1,false,Image.FORMAT_RGBA8)),"bounded host")
 var original:=a.render_pixels();check(original.size()==a.source_pixels.size(),"complete source before start")
 a.play();var schedule:=a.pixels.duplicate(true);a.play();check(a.pixels==schedule,"stable seed")
 b.configure({"mode":"materialize"});b.play();check(b.pixels==a.pixels,"reverse uses same schedule")
 for t in [0.0,0.08,0.2,0.45,0.7,1.1]:
  a.elapsed=t;b.elapsed=b.total_lifetime()-t
  check(normalized(a.render_pixels())==normalized(b.render_pixels()),"same pixels exact inverse")
 for p in a.pixels:
  a.elapsed=p.born
  check(a.particle_position(p)==p.position,"no position jump at release")
 for mode in ["disintegrate","materialize"]:
  for fps in [30,60,144]:
   a.configure({"mode":mode});a.play()
   for k in range(int(ceil(a.total_lifetime()*fps))+1):a.advance(1.0/fps)
   check(a.finished and a.pixels.is_empty(),"completion storage clear")
   check(a.render_pixels().size()==(a.source_pixels.size() if mode=="materialize" else 0),"mode endpoint")
 var times:=[0];a.completed.connect(func():times[0]+=1)
 a.play();a.advance(10);a.advance(10);check(times[0]==1,"single event")
 a.configure({"mode":"materialize"});a.play();a.advance(0.4);a.cancel();check(a.render_pixels().size()==original.size() and a.pixels.is_empty(),"cancel restores host")
 a.configure({"density":0,"mode":"disintegrate"});a.play();a.elapsed=a.release_seconds;check(a.render_pixels().is_empty(),"zero density")
 a.configure({"density":99,"release_seconds":-1,"dust_seconds":99,"turbulence":INF,"wind_speed":NAN});check(a.density==1 and a.release_seconds==0.08 and a.dust_seconds==2 and is_finite(a.turbulence) and is_finite(a.wind_speed),"config bounds/nonfinite")
 a.position=Vector2.ZERO;a.play();a.position.x=200;a.advance(0.1);check(not a.active and a.pixels.is_empty(),"teleport cleanup")
 a.position=Vector2.ZERO
 for i in 1000:
  a.play();a.advance(0.1);a.cancel();check(a.pixels.is_empty(),"pool reuse")
 var image:=Image.create(5,7,false,Image.FORMAT_RGBA8);image.fill(Color(0.2,0.4,0.6,0.5));image.set_pixel(2,3,Color.TRANSPARENT)
 a.set_host(image);a.configure({"flipped":true});check(a.render_pixels().size()==34,"odd image and half alpha")
 a.free();b.free()
 var d:=Demo.new();root.add_child(d);d.set_process(false)
 d.apply_preset(1);check(d.actual.mode=="materialize","mode preset")
 d.apply_preset(2);check(d.actual.source.get_width()==32,"item preset")
 d.cancel();d.advance(0.8);check(not d.actual.active,"cancel no auto restart")
 d.reset_all();check(d.actual.mode=="disintegrate" and d.actual.source.get_width()==40,"reset restores character")
 d.free();print("PARTICLE REVEALS CHECKS: ",checks," failures=",failures);quit(1 if failures else 0)
