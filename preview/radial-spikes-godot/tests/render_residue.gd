extends SceneTree
const Canvas=preload("../components/spike_canvas.gd")
const FX=preload("../components/radial_spikes.gd")
var checks:int=0
var failures:int=0
var vp:SubViewport
var probe:Node2D
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok: failures+=1; push_error(label)
func _initialize()->void: call_deferred("run")
func render(t:float)->Image:
 probe.age=t; probe.queue_redraw(); await process_frame; await process_frame; await RenderingServer.frame_post_draw
 return vp.get_texture().get_image()
func alpha_sum(im:Image)->float:
 var total:float=0
 for y in im.get_height():
  for x in im.get_width(): total+=im.get_pixel(x,y).a
 return total
func run()->void:
 if DisplayServer.get_name()=="headless": push_error("Native renderer required"); quit(2); return
 vp=SubViewport.new(); vp.size=Vector2i(120,100); vp.transparent_bg=true; vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(vp)
 probe=Canvas.new(); probe.position=Vector2(60,70); probe.spike={"pos":Vector2.ZERO,"height":30.0,"width":12.0,"lean":.12,"variant":.6,"seed":193,"layer":1,"strength":1.0,"direction":Vector2.RIGHT}; vp.add_child(probe)
 var folder:String=OS.get_environment("RADIAL_CAPTURE_DIR")
 for name in ["earth","ice"]:
  probe.renderer=load("res://modules/"+name+".gd"); probe.profile=load("res://presets/"+name+".tres").duplicate(true)
  var p:Resource=probe.profile; var end:float=p.rise_time+p.hold_time+p.fade_time
  var standing:Image=await render(p.rise_time)
  var breaking:Image=await render(p.rise_time+p.hold_time+p.fade_time*.55)
  var rubble:Image=await render(end+.5)
  check(standing.get_used_rect().size.y>=25,name+" intact tall silhouette")
  check(breaking.get_data()!=standing.get_data(),name+" collapse transforms the silhouette")
  check(rubble.get_used_rect().has_area() and rubble.get_used_rect().position.y>=60 and rubble.get_used_rect().size.y<18,name+" residue is low and on the ground")
  check((await render(end+2.3)).get_data()==rubble.get_data(),name+" ground residue persists steadily for seconds")
  check(alpha_sum(await render(end+3.1))<alpha_sum(rubble)*.35,name+" residue naturally fades near lifetime end")
  check(not (await render(end+p.residue_lifetime+.01)).get_used_rect().has_area(),name+" residue fully gone at expiry")
  await render(end+3); check(rubble.get_data()==(await render(end+.5)).get_data(),name+" residue reverse seek deterministic")
  if not folder.is_empty():
   standing.save_png(folder.path_join(name+"-intact.png")); breaking.save_png(folder.path_join(name+"-collapse.png")); rubble.save_png(folder.path_join(name+"-residue.png"))
  p.residue_size=1.6; check(rubble.get_data()!=(await render(end+.5)).get_data(),name+" residue size configurable")
  p.residue_density=0; check(not (await render(end+.5)).get_used_rect().has_area(),name+" zero density removes persistent residue")
  p.residue_density=1; p.residue_lifetime=0; check(not (await render(end+.01)).get_used_rect().has_area(),name+" zero lifetime ends at collapse")
  p.residue_lifetime=3.2; p.primary.a=0; p.highlight.a=0; p.shadow.a=0
  check(not (await render(end+.5)).get_used_rect().has_area() and not (await render(p.rise_time)).get_used_rect().has_area(),name+" palette alpha hides intact and residue")
 probe.free()
 # Shared display/geometry smoke across all 12 element-shape combinations.
 vp.size=Vector2i(360,240)
 var fx:Node2D=FX.new(); vp.add_child(fx)
 for name in ["earth","ice","lightning","fire"]:
  for shape in 3:
   var p:Resource=load("res://presets/"+name+".tres").duplicate(true); p.shape=shape; fx.configure(p); fx.play(Vector2(180,139),17)
   var seen:bool=false
   for phase in [.05,.11,.19,.26,.35,.45]:
    fx.seek(phase); await process_frame; await process_frame; await RenderingServer.frame_post_draw
    var im:Image=vp.get_texture().get_image(); seen=seen or im.get_used_rect().has_area()
    if not folder.is_empty() and phase==.26: im.save_png(folder.path_join(name+"-shape-"+str(shape)+".png"))
   check(seen,name+" renders shape "+str(shape))
   fx.seek(p.lifetime()+.02); await process_frame; await process_frame; await RenderingServer.frame_post_draw
   check(not vp.get_texture().get_image().get_used_rect().has_area(),name+" shape "+str(shape)+" cleans all pixels")
 fx.free()
 print("PASS" if failures==0 else "FAIL"," residue and shapes native: ",checks," assertions, ",failures," failures")
 quit(0 if failures==0 else 1)
