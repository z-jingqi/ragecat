extends SceneTree
const Effect=preload("res://effects/VFX-15_monster_death/death.gd")
const Host=preload("res://effects/VFX-15_monster_death/demo_host.gd")
var checks:=0
func check(value:bool,message:String)->void:
 checks+=1
 if not value:push_error(message);quit(1)
func _initialize()->void:
 var e:=Effect.new();root.add_child(e)
 check(e.set_host(Host.create_image()),"valid host")
 check(e.opaque_points.size()>300,"silhouette sampled")
 check(not e.set_host(null),"null rejected")
 var big:=Image.create(257,1,false,Image.FORMAT_RGBA8)
 check(not e.set_host(big),"size bounded")
 var called:=[0];e.completed.connect(func():called[0]+=1)
 e.play();var first:=e.fragments.duplicate(true);e.advance(0.12);var state:=e.live_fragments().duplicate(true)
 e.play();check(e.fragments==first,"seed replay stable");e.advance(0.12);check(e.live_fragments()==state,"analytic same time")
 e.configure({"seed":18});e.play();check(e.fragments!=first,"seed changes")
 for fps in [30,60,144]:
  e.configure({});e.play()
  for k in int(ceil(e.duration*fps))+3:e.advance(1.0/fps)
  check(e.finished and not e.playing,"finished across fps")
  check(e.fragments.is_empty() and e.live_fragments().is_empty(),"no dead particles")
  check(not e.sprite.visible,"host fully gone")
 var before:int=called[0];e.advance(10);check(called[0]==before,"completion once")
 e.reset();check(e.sprite.visible and not e.finished,"reset restores host")
 e.configure({"duration":-1,"dissolve_seconds":99,"fragment_count":999,"spread":999,"cluster_size":0,"drift":999})
 check(e.duration==0.12 and e.dissolve_seconds==0.12 and e.fragment_count==24 and e.cluster_size==1 and e.spread==48 and e.drift==60,"clamped config")
 for i in 1000:
  e.play();e.advance(0.4);e.reset();check(e.fragments.is_empty() and e.elapsed==0,"repeated reset")
 e.configure({"host_mode":false});e.play();check(not e.sprite.visible,"standalone no host draw")
 for p in e.fragments:check(p.start==Vector2.ZERO,"standalone origins")
 var copy:=Effect.new();root.add_child(copy);copy.configure({"host_mode":false});copy.play();check(copy.playing,"standalone without host")
 e.advance(NAN);check(e.elapsed==0,"invalid dt ignored")
 e.queue_free();copy.queue_free()
 print("DEATH CHECKS PASSED: ",checks);quit()
