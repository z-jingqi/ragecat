extends SceneTree
const Single=preload("../single.gd")
const Profile=preload("../profile.gd")
const Stone=preload("../stone.gd")
const Workshop=preload("../preview.gd")
var checks:int=0
var failures:int=0
func check(ok:bool,name:String)->void:
 checks+=1
 if not ok: failures+=1; push_error(name)
func _initialize()->void: call_deferred("run")
func area(poly:PackedVector2Array)->float:
 var total:float=0
 for i in poly.size(): total+=poly[i].cross(poly[(i+1)%poly.size()])
 return absf(total)*.5
func run()->void:
 var p:Resource=Profile.new(); var fx:Node2D=Single.new(); root.add_child(fx); fx.configure(p); fx.play(Vector2(180,150),17)
 check(fx.get_child_count()==1 and fx.canvas!=null,"exactly one stone, no ring")
 var first:Dictionary=fx.spike.duplicate(true)
 fx.play(Vector2.ZERO,17); check(fx.spike==first,"same seed deterministic")
 fx.play(Vector2.ZERO,18); check(fx.spike!=first,"new seed changes shape")
 for seed_value in 12:
  fx.play(Vector2.ZERO,seed_value)
  var site:Dictionary=fx.spike
  var pieces:Array=Stone.fragments(site)
  check(pieces.size()>=5 and pieces.size()<=8,"limited unequal rigid chunks")
  var min_area:float=INF; var max_area:float=0
  for piece_index in pieces.size():
   var piece:PackedVector2Array=pieces[piece_index]
   min_area=minf(min_area,area(piece)); max_area=maxf(max_area,area(piece))
   check(not Geometry2D.triangulate_polygon(piece).is_empty(),"valid chunk polygon")
   for tick in 25:
    var transformed:PackedVector2Array=Stone.fragment_points(site,piece,piece_index,float(tick)/24,p)
    check(transformed.size()==piece.size(),"rigid vertex count")
    for i in piece.size():
     for j in range(i+1,piece.size()):
      check(absf(piece[i].distance_to(piece[j])-transformed[i].distance_to(transformed[j]))<.0001,"all point-pair distances fixed")
  check(max_area>min_area*2,"different fragment sizes, not brick rows")
 var emitted:Array[int]=[0]; fx.finished.connect(func(): emitted[0]+=1)
 fx.advance(p.lifetime()+1); fx.advance(1); check(emitted[0]==1 and not fx.running,"finish only once after rubble")
 fx.seek(.3); fx.advance(.01); check(fx.running and fx.age>.3,"reverse seek resumes")
 fx.clear(); fx.seek(.2); check(fx.canvas==null and fx.spike.is_empty(),"clear cannot resurrect")
 for i in 30: fx.play(Vector2.ZERO,i); fx.clear()
 check(fx.get_child_count()==0,"replay clear frees nodes")
 p.rise_time=NAN; p.break_time=-1; p.shake_amount=INF; p.stagger=99; fx.configure(p)
 check(fx.profile.rise_time==.055 and fx.profile.break_time==.25 and fx.profile.shake_amount==.8 and fx.profile.stagger<=fx.profile.break_time*.3,"finite bounded fields")
 fx.play(Vector2(INF,NAN),17); check(fx.position==Vector2.ZERO,"invalid anchor sanitized"); fx.free()
 var scene:Node2D=Workshop.new(); root.add_child(scene); scene.set_process(false)
 check(scene.views.size()==2,"same stone at game scale and enlarged")
 for key in scene.sliders:
  var slider:HSlider=scene.sliders[key].slider
  check(scene.get_viewport_rect().encloses(slider.get_global_rect()),"control visible: "+key)
  slider.value=slider.max_value
  check(is_equal_approx(float(scene.views[0].profile.get(key)),float(scene.profile.get(key))) and is_equal_approx(float(scene.views[1].profile.get(key)),float(scene.profile.get(key))),"controls applied to both views: "+key)
 scene.speed_button.item_selected.emit(1); check(scene.speed==.3,"slow playback")
 scene.queue_free(); await process_frame
 print("PASS" if failures==0 else "FAIL"," single earth: ",checks," assertions, ",failures," failures")
 quit(0 if failures==0 else 1)
