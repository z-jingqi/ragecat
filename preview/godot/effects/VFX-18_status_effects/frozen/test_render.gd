extends SceneTree
const Effect=preload("res://effects/VFX-18_status_effects/frozen/frozen.gd")
func _initialize()->void:
 var v:=SubViewport.new();v.size=Vector2i(32,32);v.transparent_bg=true;v.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(v)
 var im:=Image.create(8,8,false,Image.FORMAT_RGBA8);im.fill(Color.TRANSPARENT)
 for y in range(8):
  for x in range(8):im.set_pixel(x,y,Color(0.2+0.05*x,0.3,0.4,float(y)/7))
 im.set_pixel(3,3,Color.TRANSPARENT)
 var s:=Sprite2D.new();s.texture=ImageTexture.create_from_image(im);s.position=Vector2(16,16);s.modulate=Color(0.8,0.9,0.7,0.5);s.self_modulate=Color(0.7,0.8,0.9,0.7);s.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;v.add_child(s)
 var shader:=Shader.new();shader.code="shader_type canvas_item; void fragment(){ COLOR.rgb*=vec3(0.9,1.0,0.8); }"
 var mat:=ShaderMaterial.new();mat.shader=shader;s.material=mat
 var f:=Effect.new();v.add_child(f);f.bind_host(s);f.configure({"intensity":0.7});f.back.visible=false;f.front.visible=false
 await process_frame;await RenderingServer.frame_post_draw
 var baseline:=v.get_texture().get_image();var checks:=0
 f.play(2)
 f.tick(0.3);f.back.visible=false;f.front.visible=false
 await process_frame;await RenderingServer.frame_post_draw
 var colored:=v.get_texture().get_image();var changed:=0
 for y in range(32):
  for x in range(32):
   var a:=baseline.get_pixel(x,y);var b:=colored.get_pixel(x,y)
   assert(is_equal_approx(a.a,b.a),"alpha unchanged");checks+=1
   if a.a>0 and a!=b:changed+=1
 print("Changed pixels: ",changed);assert(changed>15 and s.material==mat);checks+=1
 f.clear()
 await process_frame;await RenderingServer.frame_post_draw
 var restored:=v.get_texture().get_image()
 for y in range(32):
  for x in range(32):assert(baseline.get_pixel(x,y).is_equal_approx(restored.get_pixel(x,y)),"exact restore");checks+=1
 f.play(1);f.tick(0.2);f.free()
 await process_frame;await RenderingServer.frame_post_draw
 assert(v.get_texture().get_image().get_data()==baseline.get_data(),"deletion restores");checks+=1
 print("FROZEN GPU PASSED ",checks," alpha/material/restore checks")
 quit()
