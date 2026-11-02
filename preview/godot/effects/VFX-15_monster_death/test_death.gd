extends SceneTree
const Effect=preload("res://effects/VFX-15_monster_death/death.gd")
const Host=preload("res://effects/VFX-15_monster_death/demo_host.gd")
var checks:=0
var failures:=0
func check(value:bool,message:String)->void:
 checks+=1
 if not value:failures+=1;push_error(message)
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
  for k in int(ceil(e.total_lifetime()*fps))+3:e.advance(1.0/fps)
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
 e.configure({"duration":0.38,"dissolve_seconds":0.2,"residue_seconds":3.0,"residue_count":7,"host_mode":true});e.position=Vector2.ZERO;e.play();e.advance(0.38)
 check(e.burst_done and e.live_fragments().is_empty() and e.live_residue().size()==7,"settled residues replace flying ash")
 var anchors:=e.residue.duplicate(true);e.advance(1.5);check(e.residue==anchors,"ground remains do not float")
 e.position=Vector2(10,0);e.advance(0.01);check(e.residue==anchors,"ground positions remain world anchored")
 e.advance(1.5);check(e.finished and e.residue.is_empty(),"residue expiration cleans memory")
 e.position=Vector2.ZERO;e.play();e.advance(0.4);e.position=Vector2(200,0);e.advance(0.01);check(e.residue.is_empty() and not e.playing,"teleport resets residual ownership")
 e.configure({"residue_seconds":0});e.play();check(e.residue.is_empty(),"zero duration disables residue");e.advance(0.4);check(e.finished,"disabled residue retains old deadline")
 e.configure({"residue_seconds":3,"residue_count":0});e.play();e.advance(0.4);check(e.finished,"zero count has no invisible wait")
 e.configure({"residue_count":99,"residue_spread":99,"residue_seconds":99});check(e.residue_count==20 and e.residue_spread==32 and e.residue_seconds==8,"residue bounds")
 e.play();check(e.residue.size()==20,"bounded residue count");e.clear_residue();check(e.residue.is_empty(),"explicit residue clear")
 e.reset();check(e.residue.is_empty() and not e.burst_done,"pool reset clears all phases")
 copy.configure({"residue_seconds":3});copy.burst_finished.connect(func():copy.reset());copy.play();copy.advance(10);check(not copy.playing and not copy.finished and copy.elapsed==0,"callback reset wins")
 e.configure({"duration":0.38,"dissolve_seconds":0.2,"fragment_count":16,"residue_seconds":3,"residue_count":7,"residue_spread":14});e.position=Vector2.ZERO;e.play()
 for part in e.fragments:
  check(part.born>0 and part.born<e.dissolve_seconds,"birth follows body dissolve window")
  e.elapsed=part.born;check(e.fragment_world_position(part).is_equal_approx(e.play_transform*part.start),"same piece begins at body pixel")
  e.elapsed=part.born+part.flight;check(e.fragment_world_position(part).distance_to(part.world)<0.0001,"ballistic path reaches exact held point")
  if part.retained:
   var found:=false
   for ground in e.live_residue():
    if ground.id==part.id:found=true;check(ground.source_color==part.source_color and ground.size==part.size,"landing preserves piece appearance and identity")
   check(found,"same falling id becomes ground id")
 e.elapsed=0.1;check(not e.live_fragments().is_empty(),"fragments overlap ongoing dissolve")
 for i in 100:
  e.play();e.advance(0.25);e.reset();check(e.fragments.is_empty() and e.residue.is_empty(),"reuse clears both phases")
 e.queue_free();copy.queue_free()
 print("DEATH CHECKS: ",checks," failures=",failures);quit(1 if failures else 0)
