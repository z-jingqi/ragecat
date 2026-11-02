extends SceneTree
const Hit=preload("res://effects/VFX-14_monster_hit/monster_hit.gd")
const Fixture=preload("res://effects/VFX-14_monster_hit/fixture.gd")
func snap(v:SubViewport)->Image:
 await process_frame;await RenderingServer.frame_post_draw
 return v.get_texture().get_image()
func _initialize()->void:call_deferred("run")
func run()->void:
 var v=SubViewport.new();v.size=Vector2i(80,40);v.transparent_bg=true;v.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(v)
 var a=Sprite2D.new();a.texture=Fixture.texture();a.position=Vector2(20,20);a.modulate.a=0.5;a.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;v.add_child(a)
 var b=Sprite2D.new();b.texture=Fixture.texture(1);b.position=Vector2(60,20);b.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;v.add_child(b)
 var h=Hit.new();h.auto_tick=false;v.add_child(h);h.bind(a);h.configure({"impact_enabled":false})
 var baseline:Image=await snap(v)
 h.hit(Vector2.ZERO,Vector2.RIGHT)
 var flashed:Image=await snap(v)
 var checks:=0;var changed:=0
 for y in 40:
  for x in 80:
   var original:=baseline.get_pixel(x,y);var current:=flashed.get_pixel(x,y)
   assert(original.a==current.a,"No alpha modulation");checks+=1
   if x>=40:assert(original==current,"Unhit host unchanged");checks+=1
   elif original.a>0 and original!=current:changed+=1
 assert(changed>100,"Whole visible body responds");checks+=1
 h.tick(1.0)
 var restored:Image=await snap(v)
 assert(restored.get_data()==baseline.get_data(),"End pixel exact");checks+=1
 h.hit(Vector2.ZERO,Vector2.RIGHT);h.clear()
 var cleared:Image=await snap(v)
 assert(cleared.get_data()==baseline.get_data(),"Cancel pixel exact");checks+=1
 print("GPU PASS ",checks," assertions; changed host pixels ",changed)
 quit()
