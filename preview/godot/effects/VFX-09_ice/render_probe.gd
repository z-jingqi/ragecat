extends SceneTree
const Ice=preload('res://effects/VFX-09_ice/ice.gd')
func _initialize():call_deferred('run')
func run():
 var out=ProjectSettings.globalize_path('user://ice-probes')
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with('--probe-out='):out=arg.trim_prefix('--probe-out=')
 DirAccess.make_dir_recursive_absolute(out)
 var vp=SubViewport.new();vp.size=Vector2i(320,320);vp.transparent_bg=true;vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 root.add_child(vp)
 var fx=Ice.new();vp.add_child(fx);fx.auto_tick=false
 var presets=JSON.parse_string(FileAccess.get_file_as_string('res://effects/VFX-09_ice/presets.json')).presets
 for pi in range(presets.size()):
  fx.play(Vector2(160,170),presets[pi]);var life=fx.settings.duration
  for i in range(31):
   fx.seek(life*float(i)/30.)
   await process_frame;await RenderingServer.frame_post_draw
   vp.get_texture().get_image().save_png(out.path_join('p%d_%02d.png'%[pi,i]))
 # continuity immediately before/after first fracture
 fx.play(Vector2(160,170),presets[0])
 for t in [.4199,.4201]:
  fx.seek(t);await process_frame;await RenderingServer.frame_post_draw
  vp.get_texture().get_image().save_png(out.path_join('fracture_%s.png'%str(t)))
 # Repeat identical time/seed and compare irregularity extremes and worst extents.
 for i in range(4):
  var config={'seed':19,'irregularity':0. if i==2 else 1.}
  if i==3:config.merge({'count':7,'spacing':16,'height':48,'width':8,'speed':70,'shatter':.7,'angle':30},true)
  fx.play(Vector2(160,170),config);fx.seek(.35 if i<3 else .8)
  await process_frame;await RenderingServer.frame_post_draw
  vp.get_texture().get_image().save_png(out.path_join('variation_%d.png'%i))
 print('ICE_PROBE_DONE');quit()
