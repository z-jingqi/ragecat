extends SceneTree
const Fire=preload("res://effects/VFX-07_fire_explosion/fire.gd")
func _initialize()->void: call_deferred("run")
func run()->void:
 var output=OS.get_environment("FIRE_PROBE_DIR")
 if output.is_empty(): output=OS.get_user_data_dir().path_join("fire_probe")
 DirAccess.make_dir_recursive_absolute(output)
 var vp=SubViewport.new()
 vp.size=Vector2i(400,400)
 vp.transparent_bg=true
 vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 root.add_child(vp)
 var fx=Fire.new()
 fx.auto_tick=false
 vp.add_child(fx)
 var cases=[{}, {}, {"radius":30,"rise":45,"spread":1.5,"embers":16,"lobes":10,"smoke":1.0}, {"radius":6,"rise":0,"spread":0.5,"embers":0,"lobes":3,"smoke":0}]
 for k in range(cases.size()):
  fx.play(Vector2(200,200),cases[k])
  for i in range(21):
   fx.seek(fx.settings.duration*i/20.0)
   await process_frame
   await RenderingServer.frame_post_draw
   vp.get_texture().get_image().save_png(output.path_join("probe_%d_%02d.png"%[k,i]))
 print("fire GPU probe 84 frames complete")
 quit()
