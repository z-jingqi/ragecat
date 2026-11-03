extends SceneTree
const Frame = preload("res://scripts/core/sf_frame.gd")
const JS = preload("res://scripts/core/sf_js.gd")
func _init():
 var data = PackedInt64Array(); data.resize(512)
 for y in range(8,31):
  for x in range(4,12): data[y*16+x]=0xffd6a54e
 var actor={"feet":func():return [160.0,300.0],"head":func():return [160.0,238.0],"hand":func():return {"x":184.0,"y":254.0,"a":0.0},"silhouette":func():return {"x":72.0,"y":118.0,"w":16,"h":32,"data":data}}
 for slug in ["explosion","impact","slash","muzzle-flash","blood","movement","fire","lightning"]:
  var E=load("res://scripts/effects/"+slug+".gd")
  var fx=E.new()
  var options={"x":320.0,"y":280.0,"ground":300.0,"seed":17.0,"actor":actor}
  var f=Frame.new(320,200)
  fx.configure(options)
  fx.update(1.0/60.0)
  fx.draw(f,"back");fx.draw(f,"front")
  var color=f.color.data.duplicate();var light=f.light.data.duplicate()
  fx.configure(options)
  fx.update(1.0/60.0)
  f.clear();fx.draw(f,"back");fx.draw(f,"front")
  assert(f.color.data==color and f.light.data==light,slug+" reconfigure changed deterministic frame")
  fx.dispose();fx.dispose();fx=null
  print("PASS lifecycle ",slug)
 JS.clear_property_cache()
 quit()
