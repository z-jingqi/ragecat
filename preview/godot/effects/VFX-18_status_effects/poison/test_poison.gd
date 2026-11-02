extends SceneTree
const Poison=preload("res://effects/VFX-18_status_effects/poison/poison.gd")
const Fixture=preload("res://effects/VFX-18_status_effects/burning/fixture.gd")
var checks:=0
var failures:=0
func ck(v:bool,why:String)->void:
 checks+=1
 if not v:failures+=1;push_error(why)
func _initialize()->void:call_deferred("run")
func run()->void:
 var h:=Sprite2D.new();h.texture=Fixture.texture();h.hframes=2;h.z_index=10;root.add_child(h)
 var material:=CanvasItemMaterial.new();h.material=material
 var f:=Poison.new();root.add_child(f)
 ck(f.bind_host(h),"bind alpha host");ck(f.edge.size()>30,"actual outline")
 for p in f.edge:ck(f.alpha_at(int(p.x),int(p.y))>=0.15,"source on opaque mask")
 ck(f.alpha_at(15,19)==0,"hole retained")
 var first:=f.mask.get_data();h.frame=1;f.refresh_mask();ck(first!=f.mask.get_data(),"animation invalidates mask")
 h.flip_h=true;f.refresh_mask();ck(f.alpha_at(31-15,20)==0,"flipped transparent hole")
 h.flip_h=false;h.frame=0;f.refresh_mask()
 ck(f.play(3),"start");f.tick(0.5);ck(not f.particles.is_empty(),"particles emitted")
 ck(h.material==material,"material untouched");ck(h.self_modulate.a==1,"alpha unchanged")
 for p in f.particles:ck(f.alpha_at(int(p.p.x),int(p.p.y))>=0.15,"all particle origins on shape")
 for p in f.particles:
  if p.kind==1:ck(f.alpha_at(int(p.p.x),int(p.p.y)+1)<0.15,"drip from lower silhouette")
 var age:=f.elapsed;f.play(2);ck(f.elapsed==age,"refresh no reset")
 f.cancel();f.tick(0.36);ck(not f.active and f.particles.is_empty(),"cancel clears")
 ck(h.self_modulate==Color.WHITE,"cancel restores")
 h.self_modulate=Color(0.7,0.8,0.9,0.3);f.play();f.tick(0.3);ck(is_equal_approx(h.self_modulate.a,0.3),"partial alpha preserved")
 h.self_modulate=Color(0.5,0.6,0.7,0.25);f.tick(0.01);f.clear();ck(h.self_modulate.is_equal_approx(Color(0.5,0.6,0.7,0.25)),"external color respected")
 f.configure({"intensity":0});f.play();f.tick(0.2);ck(h.self_modulate.is_equal_approx(Color(0.5,0.6,0.7,0.25)),"zero intensity body")
 ck(f.front.texture.get_image().get_data().count(0)==f.front.texture.get_image().get_data().size(),"zero particles alpha")
 f.clear();f.configure({"bubble_rate":0,"drip_rate":0,"gas_rate":0});f.play();f.tick(1);ck(f.particles.is_empty(),"zero rates suppress timed bursts too")
 for fps in [30,60,144]:
  f.clear();f.configure({"intensity":0.32,"bubble_rate":40,"drip_rate":40,"gas_rate":40});f.play(1)
  for i in range(fps*2):f.tick(1.0/fps);ck(f.particles.size()<=f.POOL_LIMIT,"bounded pool")
  ck(not f.active,"fps duration")
 for i in range(50):f.play(0.1);f.tick(0.04);f.clear();ck(f.particles.is_empty(),"reuse clean")
 f.configure({"bubble_color":"44aacc","highlight_color":"ddffff","drip_color":"164455","gas_color":"223344","rim_color":"99eeff","body_color":"88ccdd"})
 ck(f.bubble_color==Color("44aacc") and f.highlight_color==Color("ddffff") and f.drip_color==Color("164455") and f.gas_color==Color("223344") and f.rim_color==Color("99eeff") and f.body_color==Color("88ccdd"),"all six palette channels configured")
 ck(not f.play(NAN) and not f.play(-1),"invalid duration")
 h.region_enabled=true;h.region_rect=Rect2(32,0,32,40);h.hframes=1;h.frame=0;ck(f.refresh_mask(),"region frame")
 ck(f.alpha_at(15,20)==0,"region correct source")
 var small:=Image.create(12,16,false,Image.FORMAT_RGBA8);small.fill(Color.WHITE)
 h.region_enabled=false;h.texture=ImageTexture.create_from_image(small);f.play();f.tick(0.1)
 ck(f.back.texture.get_size()==Vector2(60,64),"resize attached texture buffers")
 f.play();h.free();f.tick(0.1);ck(not f.active and f.host==null,"destroy host cleanup")
 f.free();print("POISON CHECKS ",checks," failures ",failures);quit(1 if failures else 0)
