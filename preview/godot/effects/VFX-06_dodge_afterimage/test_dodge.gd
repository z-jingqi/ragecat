extends SceneTree
const Trail=preload("res://effects/VFX-06_dodge_afterimage/afterimage.gd")
const Demo=preload("res://effects/VFX-06_dodge_afterimage/demo.gd")
var count:=0
func check(v:bool,msg:String)->void:
 count+=1
 if not v:push_error(msg);quit(1);assert(v,msg)
func _initialize()->void:call_deferred("run")
func run()->void:
 var rootnode:=Node2D.new();root.add_child(rootnode)
 var h:=Sprite2D.new();rootnode.add_child(h)
 var im:=Image.create(8,4,false,Image.FORMAT_RGBA8);im.fill(Color.TRANSPARENT);im.fill_rect(Rect2i(1,1,2,2),Color(1,0,0,0.5));im.fill_rect(Rect2i(4,0,4,4),Color.GREEN)
 h.texture=ImageTexture.create_from_image(im);h.hframes=2;h.offset=Vector2(1,-2);h.flip_h=true;h.position=Vector2(10,20)
 var t:=Trail.new();rootnode.add_child(t);t.start(h);t.advance(0.01,h)
 check(t.snapshots.size()==1,"initial source snapshot")
 var n:Sprite2D=t.snapshots[0].node
 check(n.texture.get_image().get_size()==Vector2i(4,4),"current cell cropped")
 check(n.texture.get_image().get_pixel(1,1).a==im.get_pixel(1,1).a,"alpha copied exactly")
 check(n.texture.get_image().get_pixel(0,0).a==0,"transparent hole preserved")
 check(n.flip_h and n.offset==Vector2(1,-2),"flip and pivot captured")
 var tr:=n.global_transform
 h.frame=1;h.position+=Vector2(10,0);t.advance(0.035,h)
 check(n.global_transform==tr,"history world transform fixed")
 check(n.texture.get_image().get_pixel(0,0).a==0,"old animation frame immutable")
 check(t.snapshots[-1].node.texture.get_image().get_pixel(0,0)==Color.GREEN,"new frame captured")
 rootnode.position+=Vector2(30,0)
 check(n.global_transform==tr,"parent motion does not drag ghost")
 t.advance(0.01,h)
 t.reset();h.position=Vector2.ZERO;t.start(h)
 for i in 50:t.advance(0.01,h)
 check(t.snapshots.size()==0,"stationary host does not reseed")
 t.reset();h.position=Vector2.ZERO;t.start(h)
 for i in 200:
  h.position.x+=2;t.advance(0.01,h);check(t.snapshots.size()<=8,"capacity bounded")
 check(t.pool.size()<=8,"pool bounded")
 t.stop();t.advance(1,h);check(t.snapshots.is_empty(),"stop decays fully")
 t.start(h);h.position.x+=8;t.advance(0.04,h);check(not t.snapshots.is_empty(),"resumed trail")
 h.position.x+=300;t.advance(0.016,h);check(t.snapshots.is_empty(),"teleport breaks history")
 t.reset();check(t.snapshots.is_empty(),"reset clears")
 for fps in [30,60,144]:
  t.reset();h.position=Vector2.ZERO;t.start(h)
  for i in fps:
   h.position.x=100.0*float(i+1)/fps;t.advance(1.0/fps,h)
  check(t.snapshots.size()==6,"stable fixed time sample count")
  check(abs(t.snapshots[-1].transform.origin.x-128.0)<0.01,"interpolated sample worldpos")
 for j in 100:
  t.start(h);h.position.x+=3;t.advance(0.04,h);t.reset();check(t.snapshots.is_empty(),"repeated pool reset")
 t.interval=-1;t.max_images=100;t.lifetime=0;t.configure();check(t.interval==0.01 and t.max_images==24 and t.lifetime==0.03,"parameter clamps")
 t.reset();h.region_enabled=true;h.region_rect=Rect2(4,0,4,4);h.hframes=1;h.frame=0;h.flip_v=true;h.rotation=0.4;t.start(h);t.advance(0.01,h)
 check(t.snapshots[0].node.texture.get_image().get_pixel(0,0)==Color.GREEN,"region snapshot")
 check(t.snapshots[0].node.flip_v,"vertical flip snapshot")
 check(abs(t.snapshots[0].node.global_rotation-0.4)<0.001,"rotation captured")
 t.start(h);h.queue_free();await process_frame;t.advance(0.01,h);check(not t.enabled,"destroyed host safe")
 var d:=Demo.new();root.add_child(d);await process_frame
 d.running=false;d.replay();d.step(0.05);check(d.trail.snapshots.size()>0,"demo dash emits")
 d.reset_all();check(d.mode==0 and d.trail.snapshots.size()==0,"demo reset")
 d.queue_free();rootnode.queue_free();await process_frame
 print("DODGE CHECKS PASS ",count);quit()
