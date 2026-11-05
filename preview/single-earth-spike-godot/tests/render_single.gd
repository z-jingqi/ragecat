extends SceneTree
const Canvas=preload("../canvas.gd")
const Profile=preload("../profile.gd")
const Single=preload("../single.gd")
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
 vp=SubViewport.new(); vp.size=Vector2i(160,120); vp.transparent_bg=true; vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(vp)
 probe=Canvas.new(); probe.position=Vector2(80,90); probe.spike={"pos":Vector2.ZERO,"height":42.0,"width":27.0,"lean":.1,"variant":.5,"seed":17,"direction":Vector2.RIGHT}; probe.profile=Profile.new(); vp.add_child(probe)
 var p:Resource=probe.profile
 for t in [-.01,.015,.035,.055,.10,.25,.39,.43,.46,.49,.515,.54,.58,.63,.70,.80,.915,1.00,1.1,1.3,2.5,3.4]:
  var im:Image=await render(t)
  if not folder.is_empty(): im.save_png(folder.path_join("stone-%04d.png"%roundi((t+.01)*1000)))
  check(im.get_used_rect().has_area()==(t>=0 and t<p.site_lifetime()),"visible lifetime "+str(t))
  check(not im.get_used_rect().has_area() or Rect2i(1,1,158,118).encloses(im.get_used_rect()),"unclipped stone "+str(t))
 var top:Image=await render(.055); var early:Image=await render(.015)
 check(top.get_used_rect().size.y>early.get_used_rect().size.y and top.get_used_rect().size.y>=40,"complete42pxbody at55ms")
 var broken:Image=await render(.63); check(broken.get_data()!=top.get_data(),"fracture pixel change")
 var rubble:Image=await render(1.3); check(rubble.get_used_rect().size.y<=22,"fallen rubble low to ground")
 check((await render(2)).get_data()==rubble.get_data(),"landed rubble stable until fade")
 await render(2.8); check((await render(.63)).get_data()==broken.get_data(),"reverse exact image")
 p.grit_density=0; var plain:Image=await render(.10); p.grit_density=.65; check((await render(.10)).get_data()!=plain.get_data(),"eruption chips configurable")
 p.impact_strength=0; var no_push:Image=await render(.035); p.impact_strength=1
 check((await render(.035)).get_data()!=no_push.get_data(),"ground push visibly configurable")
 p.depth=.8; var thin:Image=await render(.30); p.depth=4
 check((await render(.30)).get_data()!=thin.get_data(),"fixed solid depth visibly configurable")
 p.depth=2.5; p.grit_density=0; var no_landing_chips:Image=await render(.83); p.grit_density=.65
 check((await render(.83)).get_data()!=no_landing_chips.get_data(),"secondary contact chips visible")
 p.residue_lifetime=0
 check(not (await render(p.rise_time+p.hold_time+p.break_time+.01)).get_used_rect().has_area(),"zero residue lifetime clears whole effect")
 p.residue_lifetime=2.2
 p.shake_amount=0; var quiet:Image=await render(.48); p.shake_amount=1.05; check((await render(.48)).get_data()!=quiet.get_data(),"body shake configurable")
 p.shake_amount=1.05
 for scale_value in [.6,1.0,1.5]:
  for scatter_value in [0.0,1.0,2.0]:
   p.scatter=scatter_value; probe.spike.height=42*scale_value; probe.spike.width=27*scale_value
   var wide:bool=scale_value*maxf(1.0,scatter_value)>1.3
   vp.size=Vector2i(320,240) if wide else Vector2i(160,120); probe.position=Vector2(160,180) if wide else Vector2(80,90)
   for age in [.055,.55,.7,.9,1.2]:
    var state:Image=await render(age)
    check(Rect2i(Vector2i.ONE,vp.size-Vector2i(2,2)).encloses(state.get_used_rect()),"size/scatter bounds unclipped")
 vp.size=Vector2i(160,120); probe.position=Vector2(80,90); probe.spike.height=42; probe.spike.width=27; p.scatter=1
 p.primary.a=0; p.highlight.a=0; p.shadow.a=0
 check(not (await render(.055)).get_used_rect().has_area() and not (await render(.63)).get_used_rect().has_area(),"palette alpha")
 probe.free(); var fx:Node2D=Single.new(); vp.add_child(fx); fx.play(Vector2(80,90),17); fx.seek(.4); fx.clear(); await process_frame; await process_frame; await RenderingServer.frame_post_draw
 check(not vp.get_texture().get_image().get_used_rect().has_area(),"clear all pixels")
 fx.free(); print("PASS" if failures==0 else "FAIL"," native single earth: ",checks," assertions, ",failures," failures")
 quit(0 if failures==0 else 1)
