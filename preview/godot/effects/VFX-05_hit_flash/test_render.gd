extends SceneTree
func _initialize()->void:
 var v:=SubViewport.new();v.size=Vector2i(32,32);v.transparent_bg=true;v.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(v)
 var im:=Image.create(8,8,false,Image.FORMAT_RGBA8);im.fill(Color.TRANSPARENT)
 for y in range(8):
  for x in range(8):im.set_pixel(x,y,Color(0.2+0.05*x,0.3,0.4,float(y)/7.0))
 var s:=Sprite2D.new();s.centered=false;s.texture=ImageTexture.create_from_image(im);s.position=Vector2(8,8);s.modulate=Color(0.8,0.9,0.7,0.5);s.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;v.add_child(s)
 await process_frame;await RenderingServer.frame_post_draw
 var baseline:=v.get_texture().get_image()
 var mat:=ShaderMaterial.new();mat.shader=load("res://effects/VFX-05_hit_flash/flash.gdshader");mat.set_shader_parameter("amount",0.0);s.material=mat
 await process_frame;await RenderingServer.frame_post_draw
 var idle:=v.get_texture().get_image()
 var checks:=0
 for y in range(32):
  for x in range(32):
   assert(baseline.get_pixel(x,y).is_equal_approx(idle.get_pixel(x,y)),"Idle shader must equal original modulated texture");checks+=1
 mat.set_shader_parameter("amount",0.46)
 await process_frame;await RenderingServer.frame_post_draw
 var flash:=v.get_texture().get_image();var changed:=0
 for y in range(32):
  for x in range(32):
   var a:=baseline.get_pixel(x,y);var b:=flash.get_pixel(x,y)
   assert(is_equal_approx(a.a,b.a),"Preserve exact alpha for partial-alpha texture and host modulate");checks+=1
   if a.a>0 and a!=b:changed+=1
 assert(changed==56,"All nontransparent fixture pixels change");checks+=1
 print("RENDER PASS ",checks," checks; ",changed," visible pixels, alpha unchanged")
 quit()
