extends SceneTree
const State = preload("flash_state.gd")
class Geometry:
 extends Node2D
 var state: RefCounted
 var base := Color(.3,.4,.5,.37)
 func _draw() -> void:
  draw_colored_polygon(PackedVector2Array([Vector2(32,10),Vector2(54,32),Vector2(32,54),Vector2(10,32)]),state.apply_color(base))
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var viewport:=SubViewport.new();viewport.size=Vector2i(64,64);viewport.transparent_bg=true
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var state:=State.new();state.configure({"duration":.1,"peak":.2,"hold":.018,"color":"#ffffff"})
 var shape:=Geometry.new();shape.state=state;viewport.add_child(shape)
 await process_frame;await RenderingServer.frame_post_draw
 var before:Image=viewport.get_texture().get_image()
 state.trigger();shape.queue_redraw()
 await process_frame;await RenderingServer.frame_post_draw
 var after:Image=viewport.get_texture().get_image()
 var checks:=0;var changed:=0
 for y in range(64):
  for x in range(64):
   var a:=before.get_pixel(x,y);var b:=after.get_pixel(x,y)
   assert(is_equal_approx(a.a,b.a),"geometry flash preserves alpha and silhouette");checks+=1
   if a.a>0 and a!=b:changed+=1
 assert(changed>800,"body pixels actually change");checks+=1
 state.tick(.1);shape.queue_redraw()
 await process_frame;await RenderingServer.frame_post_draw
 var cleared:Image=viewport.get_texture().get_image()
 for y in range(64):
  for x in range(64):assert(before.get_pixel(x,y)==cleared.get_pixel(x,y),"exact baseline restored");checks+=1
 print("GEOMETRY FLASH NATIVE: %d checks, changed=%d" % [checks,changed])
 viewport.free();await process_frame;quit()
