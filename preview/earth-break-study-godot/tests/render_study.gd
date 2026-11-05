extends SceneTree
const Canvas=preload("../canvas.gd")
const Profile=preload("../profile.gd")
const Ring=preload("../ring.gd")
var checks:int=0
var failures:int=0
var vp:SubViewport
var probe:Node2D
func check(ok:bool,name:String)->void:
 checks+=1
 if not ok: failures+=1; push_error(name)
func _initialize()->void: call_deferred("run")
func render(t:float)->Image:
 probe.age=t; probe.queue_redraw(); await process_frame; await process_frame; await RenderingServer.frame_post_draw
 return vp.get_texture().get_image()
func run()->void:
 if DisplayServer.get_name()=="headless": push_error("Native renderer required"); quit(2); return
 var folder:String=OS.get_environment("EARTH_CAPTURE_DIR")
 vp=SubViewport.new(); vp.size=Vector2i(100,100); vp.transparent_bg=true; vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(vp)
 probe=Canvas.new(); probe.position=Vector2(50,73); probe.spike={"pos":Vector2.ZERO,"height":32.0,"width":15.0,"lean":.08,"variant":.4,"seed":179,"direction":Vector2.RIGHT}; probe.profile=Profile.new(); vp.add_child(probe)
 var p:Resource=probe.profile
 for t in [-.01,.015,.045,.30,.35,.38,.43,.50,.60,.685,1.5,3.2]:
  var im:Image=await render(t)
  if not folder.is_empty(): im.save_png(folder.path_join("stone-%04d.png"%roundi((t+.01)*1000)))
  check(im.get_used_rect().has_area()==(t>=0 and t<p.site_lifetime()),"visible lifetime at "+str(t))
 var top:Image=await render(.045); var early:Image=await render(.015)
 check(top.get_used_rect().size.y>early.get_used_rect().size.y and top.get_used_rect().size.y>=30,"full-size stone revealed within45ms")
 var broken:Image=await render(.50); check(broken.get_data()!=top.get_data(),"fracture visibly separates rigid pieces")
 var rubble:Image=await render(1.3); check(rubble.get_used_rect().size.y<18,"fallen chunks rest low to ground")
 check((await render(2)).get_data()==rubble.get_data(),"landed rubble stable until fade")
 await render(2.8); check((await render(.50)).get_data()==broken.get_data(),"reverse seek same fractured frame")
 p.grit_density=0; var plain:Image=await render(.10); p.grit_density=1; check((await render(.10)).get_data()!=plain.get_data(),"sparse dirt chip control")
 p.primary.a=0; p.highlight.a=0; p.shadow.a=0
 check(not (await render(.045)).get_used_rect().has_area() and not (await render(.50)).get_used_rect().has_area(),"palette alpha respected")
 probe.free(); vp.size=Vector2i(360,240)
 var fx:Node2D=Ring.new(); vp.add_child(fx); fx.play(Vector2(180,150),17)
 for t in [.1,.135,.42,.50,.62,.8,2.0,3.3]:
  fx.seek(t); await process_frame; await process_frame; await RenderingServer.frame_post_draw
  var im:Image=vp.get_texture().get_image()
  if not folder.is_empty(): im.save_png(folder.path_join("ring-%04d.png"%roundi(t*1000)))
  check(t>=fx.profile.lifetime() or Rect2i(1,1,358,238).encloses(im.get_used_rect()),"default ring unclipped at "+str(t))
 fx.clear(); await process_frame; await process_frame; await RenderingServer.frame_post_draw
 check(not vp.get_texture().get_image().get_used_rect().has_area(),"clear removes all pixels")
 fx.free(); print("PASS" if failures==0 else "FAIL"," native earth study: ",checks," assertions, ",failures," failures")
 quit(0 if failures==0 else 1)
