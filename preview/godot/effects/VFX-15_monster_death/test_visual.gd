extends SceneTree
const Effect=preload("res://effects/VFX-15_monster_death/death.gd")
const Host=preload("res://effects/VFX-15_monster_death/demo_host.gd")
var viewport:SubViewport
var effect:Node2D
var out:=""
func _initialize()->void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output="):out=arg.trim_prefix("--output=")
 if out.is_empty():push_error("Pass -- --output=/absolute/directory");quit(1);return
 DirAccess.make_dir_recursive_absolute(out)
 call_deferred("run")
func capture(name:String)->void:
 await process_frame
 await RenderingServer.frame_post_draw
 viewport.get_texture().get_image().save_png(out.path_join(name+".png"))
func run()->void:
 viewport=SubViewport.new();viewport.size=Vector2i(96,96);viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 effect=Effect.new();effect.position=Vector2(48,48);viewport.add_child(effect)
 var host:=Host.create_image();host.set_pixel(19,23,Color(0.6,0.4,0.2,0.5));host.save_png(out.path_join("source.png"));effect.set_host(host)
 effect.configure({"fragment_count":0,"residue_seconds":0});await capture("ready")
 effect.play();effect.advance(0.06);await capture("early")
 effect.advance(0.06);await capture("middle")
 effect.advance(0.08);await capture("body_gone")
 effect.advance(1);await capture("done")
 effect.reset();await capture("reset")
 effect.configure({"fragment_count":0,"residue_seconds":0,"flipped":true});await capture("flipped")
 effect.configure({"fragment_count":9,"residue_seconds":3,"residue_count":7,"flipped":false});effect.play();effect.advance(0.6);await capture("ground_start")
 effect.advance(2.0);await capture("ground_hold")
 effect.advance(1.0);await capture("ground_done")
 effect.configure({"fragment_count":16,"residue_seconds":0,"flipped":false});effect.play()
 var schedule:Array=effect.fragments.duplicate(true);effect.fragments.clear()
 var failures:=0;var checks:=0
 for part in schedule:
  for sign_value in [-1,1]:
   effect.elapsed=part.born+sign_value*0.0005;effect.sync_visuals()
   await process_frame;await RenderingServer.frame_post_draw
   var im:=viewport.get_texture().get_image()
   var pos:Vector2i=Vector2i(part.start.floor()+Vector2(48,48))
   var alpha:=im.get_pixelv(pos).a
   checks+=1
   if (sign_value<0 and alpha==0) or (sign_value>0 and alpha>0):failures+=1
 print("DEATH SOURCE-RELEASE GPU CHECKS: ",checks," failures=",failures)
 print("DEATH VISUAL CAPTURE COMPLETE");quit(1 if failures else 0)
