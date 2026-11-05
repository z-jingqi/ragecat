extends SceneTree
const Ring=preload("../ring.gd")
const Profile=preload("../profile.gd")
const Stone=preload("../stone.gd")
const Workshop=preload("../preview.gd")
var checks:int=0
var failures:int=0
func check(ok:bool,name:String)->void:
 checks+=1
 if not ok: failures+=1; push_error(name)
func _initialize()->void: call_deferred("run")
func run()->void:
 var p:Resource=Profile.new(); var fx:Node2D=Ring.new(); root.add_child(fx); fx.configure(p); fx.play(Vector2(180,150),17)
 check(fx.sites.size()==9 and fx.canvases.size()==9,"exactly one sparse ring")
 var first:Array=fx.sites.duplicate(true)
 fx.play(Vector2.ZERO,17); check(fx.sites==first,"same seed deterministic")
 fx.play(Vector2.ZERO,18); check(fx.sites!=first,"new seed changes layout")
 for site in fx.sites:
  var at:Vector2=site.anchor
  check(absf(Vector2(at.x,at.y*2).length()-p.radius)<2.01,"single radial band only")
  check(site.spawn>=.08 and site.spawn<=.088,"no layered onset scheduling")
  var pieces:Array=Stone.fragments(site)
  check(pieces.size()>=6 and pieces.size()<=8,"6–8 solid chunks")
  for piece_index in pieces.size():
   var piece:PackedVector2Array=pieces[piece_index]
   for tick in 21:
    var transformed:PackedVector2Array=Stone.fragment_points(site,piece,piece_index,float(tick)/20,p)
    check(transformed.size()==piece.size(),"rigid vertex count")
    for i in piece.size():
     var j:int=(i+1)%piece.size()
     check(absf(piece[i].distance_to(piece[j])-transformed[i].distance_to(transformed[j]))<.0001,"all fragment edge lengths stay fixed")
 var emitted:Array[int]=[0]; fx.finished.connect(func(): emitted[0]+=1)
 fx.advance(p.lifetime()+1); fx.advance(1); check(emitted[0]==1 and not fx.running,"finish only once after rubble")
 fx.seek(.3); fx.advance(.01); check(fx.running and fx.age>.3,"reverse seek resumes without stale completion")
 fx.clear(); fx.seek(.2); check(fx.sites.is_empty() and fx.canvases.is_empty(),"clear cannot resurrect pieces")
 for i in 30: fx.play(Vector2.ZERO,i); fx.clear()
 check(fx.get_child_count()==0,"repeat clear releases all nodes")
 p.rise_time=NAN; p.break_time=-1; p.count=99; p.radius=INF; fx.configure(p)
 check(fx.profile.rise_time==.045 and fx.profile.break_time==.18 and fx.profile.count==16 and fx.profile.radius==66,"invalid fields sanitized")
 fx.free()
 var scene:Node2D=Workshop.new(); root.add_child(scene); scene.set_process(false)
 for key in scene.sliders:
  var slider:HSlider=scene.sliders[key].slider
  check(scene.get_viewport_rect().encloses(slider.get_global_rect()),"control visible: "+key)
  slider.value=slider.max_value
  check(is_equal_approx(float(scene.ring.profile.get(key)),float(scene.profile.get(key))),"control applied: "+key)
 scene.speed_button.item_selected.emit(1); check(scene.speed==.35,"slow playback works")
 scene.queue_free(); await process_frame
 print("PASS" if failures==0 else "FAIL"," earth study: ",checks," assertions, ",failures," failures")
 quit(0 if failures==0 else 1)
