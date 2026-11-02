extends SceneTree
const Effect=preload("res://effects/particle_reveals/particle_reveals.gd")
const Host=preload("res://effects/particle_reveals/demo_host.gd")
var vp:SubViewport
var fx:Node2D
var out:=""
var checks:=0
var failures:=0
func check(ok:bool,msg:String)->void:
 checks+=1
 if not ok:failures+=1;push_error(msg)
func _initialize()->void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output="):out=arg.trim_prefix("--output=")
 if out.is_empty():quit(1);return
 DirAccess.make_dir_recursive_absolute(out);call_deferred("run")
func grab()->Image:
 await process_frame;await RenderingServer.frame_post_draw
 return vp.get_texture().get_image()
func run()->void:
 vp=SubViewport.new();vp.size=Vector2i(128,128);vp.transparent_bg=true;vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(vp)
 fx=Effect.new();fx.position=Vector2(48,64);vp.add_child(fx)
 var im:=Host.create_image();im.set_pixel(19,23,Color(0.3,0.5,0.7,0.5));im.save_png(out.path_join("source.png"));fx.set_host(im)
 var original:Image=await grab();original.save_png(out.path_join("original.png"))
 fx.play();fx.elapsed=0.3;var forward:Image=await grab();forward.save_png(out.path_join("forward.png"))
 fx.configure({"mode":"materialize"});fx.play();fx.elapsed=fx.total_lifetime()-0.3
 var reverse:Image=await grab();check(forward.get_data()==reverse.get_data(),"actual pixel reverse matches forward")
 fx.advance(10);var restored:Image=await grab();check(original.get_data()==restored.get_data(),"materialize endpoint exact original RGBA")
 fx.configure({"mode":"disintegrate"});fx.play();fx.advance(10);var blank:Image=await grab()
 for y in 128:
  for x in 128:check(blank.get_pixel(x,y).a==0,"disintegrate endpoint empty")
 fx.configure({"mode":"materialize"});fx.play();fx.advance(0.4);fx.cancel();var cancelled:Image=await grab();check(original.get_data()==cancelled.get_data(),"cancel restores original")
 var source_count:=0
 for y in im.get_height():
  for x in im.get_width():
   check(absf(original.get_pixel(x+28,y+42).a-im.get_pixel(x,y).a)<0.01,"exact source alpha including holes")
   if im.get_pixel(x,y).a>0:source_count+=1
 check(source_count==fx.source_pixels.size(),"each visible source pixel represented")
 print("PARTICLE REVEALS GPU: ",checks," failures=",failures);quit(1 if failures else 0)
