extends SceneTree
const Orb=preload("res://effects/VFX-08_lightning_burst/burst.gd")
var output:=""
func _initialize()->void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--probe-dir="):output=arg.trim_prefix("--probe-dir=")
 call_deferred("run")
func run()->void:
 var view:=SubViewport.new();view.size=Vector2i(128,128);view.transparent_bg=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
 var orb:=Orb.new();orb.automatic=false;view.add_child(orb);orb.play(Vector2(64,64),[],{"radius":48,"arcs":3})
 var first:Dictionary=orb.paths[0].duplicate(true)
 var result:Array=[]
 if output!="":DirAccess.make_dir_recursive_absolute(output)
 for age in [0.01,0.035,0.07,0.12,0.2,0.28,0.31]:
  orb.age=age;orb.paths=[first];orb.queue_redraw()
  await process_frame
  await RenderingServer.frame_post_draw
  var im:=view.get_texture().get_image();var pixels:=0
  for y in range(128):
   for x in range(128):
    if Vector2(x-64,y-64).length()>14 and im.get_pixel(x,y).a>0.5:pixels+=1
  result.append({"age":age,"pixels":pixels})
  if output!="":im.save_png(output.path_join("arc_%.3f.png"%age))
 print("ORB TEMPORAL PIXELS: ",JSON.stringify(result))
 var ok:bool=result[0].pixels<result[1].pixels and result[1].pixels<result[2].pixels and result[4].pixels<result[2].pixels and result[5].pixels<result[4].pixels and result[6].pixels==0
 if not ok:push_error("Growth/decay rendered pixel progression failed")
 quit(0 if ok else 1)
