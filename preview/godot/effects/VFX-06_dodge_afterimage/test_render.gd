extends SceneTree
const Trail=preload("res://effects/VFX-06_dodge_afterimage/afterimage.gd")
var checks:=0
func verify(v:bool,msg:String)->void:
 checks+=1
 if not v:push_error(msg);quit(1);assert(v,msg)
func _initialize()->void:call_deferred("run")
func run()->void:
 var v:=SubViewport.new();v.size=Vector2i(64,64);v.transparent_bg=true;v.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(v)
 var h:=Sprite2D.new();h.position=Vector2(32,32);h.centered=false;v.add_child(h)
 var im:=Image.create(8,8,false,Image.FORMAT_RGBA8);im.fill(Color.TRANSPARENT);im.fill_rect(Rect2i(1,1,6,6),Color(1,0.4,0.2,0.5));im.fill_rect(Rect2i(3,3,2,2),Color.TRANSPARENT)
 h.texture=ImageTexture.create_from_image(im);h.modulate=Color(1,1,1,0.5)
 var t:=Trail.new();v.add_child(t);t.opacity=1;t.color_mix=0;t.hold=0.1;t.lifetime=0.5;t.start(h);t.advance(0.01,h);h.visible=false
 await process_frame;await RenderingServer.frame_post_draw
 var a:=v.get_texture().get_image()
 for y in 8:
  for x in 8:
   var expected:=im.get_pixel(x,y).a*0.5
   verify(abs(a.get_pixel(32+x,32+y).a-expected)<0.012,"sourcealpha once and transparent holes")
 var before:=a.get_data();h.position=Vector2(50,50)
 await process_frame;await RenderingServer.frame_post_draw
 verify(v.get_texture().get_image().get_data()==before,"host movement doesn't move retained ghost")
 t.stop();t.advance(1,h)
 await process_frame;await RenderingServer.frame_post_draw
 a=v.get_texture().get_image()
 for y in 64:
  for x in 64:verify(a.get_pixel(x,y).a==0,"clear transparent output")
 print("DODGE GPU CHECKS PASS ",checks);quit()
