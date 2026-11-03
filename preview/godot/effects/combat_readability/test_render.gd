extends SceneTree
const Thunder := preload("../VFX-08_chain_lightning/fixed_path.gd")
const ThunderPreset := preload("../VFX-08_chain_lightning/combat_preset.gd")
const Level := preload("../VFX-22_level_up/level_up.gd")
const LevelPreset := preload("../VFX-22_level_up/combat_preset.gd")
var checks := 0
var failed := 0
class HostMask extends Node2D:
 func _draw(): draw_rect(Rect2(-19,-76,38,76),Color("667985"))
func _initialize(): call_deferred("run")
func check(ok: bool,title: String):
 checks += 1
 if not ok: failed += 1; push_error(title)
func frame(view: SubViewport) -> Image:
 await process_frame; await RenderingServer.frame_post_draw
 return view.get_texture().get_image()
func changed(a: Image,b: Image,rect: Rect2i) -> int:
 var total := 0
 for y in range(rect.position.y,rect.end.y):
  for x in range(rect.position.x,rect.end.x):
   if not a.get_pixel(x,y).is_equal_approx(b.get_pixel(x,y)): total += 1
 return total
func run():
 var view := SubViewport.new(); view.size = Vector2i(1280,720); view.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(view)
 var hidden := "--no-preset-render" in OS.get_cmdline_user_args()
 var prefix := ""
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output="): prefix = arg.trim_prefix("--output=")
 var thunder := Thunder.new(); view.add_child(thunder)
 var path := PackedVector2Array([Vector2(80,200),Vector2(180,200),Vector2(280,200),Vector2(380,200),Vector2(480,200),Vector2(580,200)])
 var empty: Image = await frame(view); var counts: Array = []
 for improved in [false,true]:
  thunder.play_path(path,ThunderPreset.OPTIONS if improved else {})
  var widths: Array = []
  for i in range(5):
   var native_peak: float = thunder.links[i].delay+thunder.config.attack+thunder.config.hold*.5
   thunder.seek(native_peak/thunder._native_duration*thunder.duration)
   if improved and hidden: thunder.hide()
   var rendered: Image = await frame(view)
   widths.append(changed(empty,rendered,Rect2i(92+i*100,180,76,40)))
   if not prefix.is_empty(): rendered.save_png(prefix+("-new" if improved else "-old")+str(i)+".png")
  counts.append(widths)
 for i in range(5):
  check(counts[0][i] > 20,"baseline segment is non-vacuously rendered")
  check(counts[1][i] > counts[0][i]*1.3,"every segment has a visibly wider footprint")
 thunder.free(); await process_frame
 var host := HostMask.new(); host.position = Vector2(640,480); host.z_index = 2; view.add_child(host)
 var level := Level.new(); level.automatic = false; view.add_child(level)
 empty = await frame(view); var level_pixels: Array = []
 for improved in [false,true]:
  level.scale = LevelPreset.DRAW_SCALE if improved else Vector2.ONE
  level.play(Vector2.ZERO,LevelPreset.OPTIONS if improved else {},host,Vector2.ZERO); level.tick(.36)
  if improved and hidden: level.hide()
  var rendered: Image = await frame(view)
  level_pixels.append(changed(empty,rendered,Rect2i(550,280,180,240)))
  if not prefix.is_empty(): rendered.save_png(prefix+("-level-new" if improved else "-level-old")+".png")
 check(level_pixels[0] > 10,"baseline upgrade is non-vacuously rendered behind tall mask")
 check(level_pixels[1] > level_pixels[0]*2,"new upgrade visibly clears tall host with larger signal")
 level.clear(); var cleared: Image = await frame(view)
 check(cleared.get_data() == empty.get_data(),"clear restores exact host/background pixels")
 print("READABILITY NATIVE: ",checks," checks, ",failed," failed; segments=",counts," upgrade=",level_pixels)
 view.free(); await process_frame
 quit(1 if failed else 0)
