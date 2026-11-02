extends SceneTree
const Frozen=preload("res://effects/VFX-18_status_effects/frozen/frozen.gd")
const Fixture=preload("res://effects/VFX-18_status_effects/burning/fixture.gd")
var checks:=0
var failures:=0
func ck(v:bool,why:String)->void:
 checks+=1
 if not v:failures+=1;push_error(why)
func energy(f:Node)->float:
 if f.front.texture==null:return 0
 var im:Image=f.front.texture.get_image();var total:=0.0
 for yy in range(im.get_height()):
  for xx in range(im.get_width()):total+=im.get_pixel(xx,yy).a
 return total
func _initialize()->void:call_deferred("run")
func run()->void:
 var h:=Sprite2D.new();h.texture=Fixture.texture();h.hframes=2;h.z_index=10;root.add_child(h)
 var material:=CanvasItemMaterial.new();h.material=material
 var f:=Frozen.new();root.add_child(f);ck(f.bind_host(h),"bind actual alpha host")
 ck(f.edge.size()>30 and f.crystals.size()>4,"actual outline and crystals")
 for p in f.edge:ck(f.alpha_at(int(p.x),int(p.y))>=0.15,"frost source on alpha")
 for c in f.crystals:ck(f.alpha_at(int(c.p.x),int(c.p.y))>=0.15,"crystal attached to shape")
 ck(f.alpha_at(15,19)==0,"source hole retained")
 ck(f.plates.size()==5 and not f.shell_pixels.is_empty(),"front slabs and encasing shell built")
 for plate in f.plates:ck(f.alpha_at(roundi(plate.p.x),roundi(plate.p.y))>=0.999,"slab anchored to actual host")
 var plate_identity:=f.plates.duplicate(true)

 f.play();f.tick(0.2);ck(f.phase=="forming" and f.amount>0 and f.amount<1,"progressive form")
 ck(f.coverage(Vector2(14,30),f.amount)>f.coverage(Vector2(14,7),f.amount),"freezes upward")
 ck(f.front.texture.get_image().get_pixel(15+f.PAD,19+f.PAD).a==0,"ice coat does not fill body hole")
 f.tick(0.4);ck(f.phase=="holding" and f.amount==1,"formed hold")
 var first:=f.mask.get_data();h.frame=1;f.tick(0.01);ck(first!=f.mask.get_data(),"host current frame")
 h.flip_h=true;f.refresh_mask();ck(f.alpha_at(31-15,20)==0,"flipped mask hole")
 h.flip_h=false;h.flip_v=true;f.refresh_mask();ck(f.alpha_at(15,39-20)==0,"vertical flipped hole")
 h.flip_v=false;h.frame=0;f.refresh_mask()
 var elapsed:=f.elapsed;f.play(2);ck(f.elapsed==elapsed and f.phase=="holding","refresh preserves hold")
 ck(h.material==material and h.self_modulate.a==1,"material and host alpha preserved")
 f.cancel();f.tick(0.14);ck(f.plates.size()==plate_identity.size(),"release keeps front slab identity");ck(f.phase=="releasing" and f.shed and not f.fragments.is_empty(),"crack then detach existing crystals")
 var amount:=f.amount;f.play();ck(f.phase=="forming" and f.amount==amount,"reapply during thaw continuous")
 f.tick(0.6);f.cancel();f.tick(0.61);ck(not f.active and f.fragments.is_empty(),"cancel finishes and restores")
 ck(h.self_modulate==Color.WHITE,"restore base")
 h.self_modulate=Color(0.7,0.8,0.9,0.3);f.play();f.tick(0.3);ck(is_equal_approx(h.self_modulate.a,0.3),"partial host alpha")
 h.self_modulate=Color(0.5,0.6,0.7,0.25);f.tick(0.01);f.clear();ck(h.self_modulate.is_equal_approx(Color(0.5,0.6,0.7,0.25)),"external updates preserved")
 f.configure({"intensity":0});f.play();f.tick(0.3);ck(h.self_modulate.is_equal_approx(Color(0.5,0.6,0.7,0.25)),"zero strength no host tint")
 ck(f.front.texture.get_image().get_data().count(0)==f.front.texture.get_image().get_data().size(),"zero strength no crust")
 f.clear();f.configure({"intensity":0.4,"crystal_density":0});f.play();f.tick(0.6);ck(f.crystals.is_empty(),"zero crystal density")
 f.configure({"crystal_density":0.3,"crystal_size":7})
 for fps in [30,60,144]:
  f.clear();f.play(0.7)
  for i in range(fps*2):f.tick(1.0/fps);ck(f.fragments.size()<=f.POOL_LIMIT,"bounded fragment pool")
  ck(not f.active,"form hold thaw finish across fps")
 for i in range(50):f.play(0.1);f.tick(0.04);f.clear();ck(f.fragments.is_empty(),"reuse clean")
 f.configure({"ice_color":"6688aa","facet_color":"bbccdd","body_color":"8899aa","edge_color":"ccddff","crack_color":"112233","mist_color":"556677"})
 ck(f.ice_color==Color("6688aa") and f.facet_color==Color("bbccdd") and f.body_color==Color("8899aa") and f.edge_color==Color("ccddff") and f.crack_color==Color("112233") and f.mist_color==Color("556677"),"all six palette channels")
 f.clear();h.region_enabled=false;h.hframes=2;h.frame=0;f.configure({"intensity":0.4});f.play();f.tick(0.6)
 var stable_plates:=f.plates.duplicate(true)
 var previous:=f.front.texture.get_image();var occupied_before:=0
 for yy in range(previous.get_height()):
  for xx in range(previous.get_width()):
   if previous.get_pixel(xx,yy).a>0.02:occupied_before+=1
 var prior_energy:=energy(f);var start_energy:=prior_energy
 f.cancel();f.tick(1.0/60)
 var current:=f.front.texture.get_image();var occupied_after:=0
 for yy in range(current.get_height()):
  for xx in range(current.get_width()):
   if current.get_pixel(xx,yy).a>0.02:occupied_after+=1
 ck(occupied_after>=occupied_before*0.8,"release does not delete whole shell on first frame")
 for i in range(35):
  f.tick(1.0/60);ck(f.plates==stable_plates,"same slab identities through release")
  var now:=energy(f);ck(now<=start_energy*1.2,"no release brightness burst");ck(prior_energy-now<=start_energy*0.3,"no single-frame disappearance");prior_energy=now
 f.tick(1);ck(not f.active and f.front.texture==null,"all residual visuals clear")
 f.configure({"plate_count":0});f.play();f.tick(0.1);ck(f.plates.is_empty(),"optional front plate control");f.clear()
 f.configure({"plate_count":99,"plate_scale":INF,"shell_thickness":-10});ck(f.plate_count==5 and is_finite(f.plate_scale) and f.shell_thickness>=0.4,"new geometry controls bounded")
 f.configure({"form_time":NAN,"release_time":-100,"crystal_density":INF});ck(is_finite(f.form_time) and f.release_time>=0.15 and is_finite(f.crystal_density),"invalid parameters safe")
 ck(not f.play(NAN) and not f.play(-2),"invalid duration")
 h.region_enabled=true;h.region_rect=Rect2(32,0,32,40);h.hframes=1;h.frame=0;ck(f.refresh_mask() and f.alpha_at(15,20)==0,"region source")
 var small:=Image.create(12,16,false,Image.FORMAT_RGBA8);small.fill(Color.WHITE);h.region_enabled=false;h.texture=ImageTexture.create_from_image(small)
 f.play();f.tick(0.1);ck(f.back.texture.get_size()==Vector2(60,64),"resized buffers")
 f.play();h.free();f.tick(0.1);ck(not f.active and f.host==null,"host destruction")
 f.free();print("FROZEN CHECKS ",checks," failures ",failures);quit(1 if failures else 0)
