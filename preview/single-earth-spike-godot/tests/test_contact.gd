extends SceneTree
const Contact=preload("../contact.gd")
const Profile=preload("../profile.gd")
var failures:int=0
func check(ok:bool, label:String)->void:
 if not ok: failures+=1; push_error(label)
func _initialize()->void:
 var p:Resource=Profile.new()
 var contact:Object=Contact.new()
 var site:Dictionary={"width":27.0,"seed":17,"variant":.5}
 check(contact.has_method("ground_paths"),"ground burst has deterministic radial fracture paths")
 if not contact.has_method("ground_paths"):
  quit(1); return
 var paths:Array=contact.ground_paths(site)
 check(paths.size()==5,"five irregular ground spokes")
 check(paths==contact.ground_paths(site),"seed replay is deterministic")
 for path in paths: check(path.size()==4,"each ground crack has two bends")
 var poly:PackedVector2Array=contact.clod_polygon(0)
 check(poly.size()>=5 and not Geometry2D.triangulate_polygon(poly).is_empty(),"clod is an irregular solid polygon")
 check(contact.clod_polygon(0)!=contact.clod_polygon(1),"clods are not identical tiles")
 var start:Dictionary=contact.clod_pose(site,0,0.0,p)
 var middle:Dictionary=contact.clod_pose(site,0,.08,p)
 var end:Dictionary=contact.clod_pose(site,0,.5,p)
 check(middle.position.y<start.position.y,"soil pushed upwards")
 check(is_equal_approx(end.position.y,0.0),"clod returns to ground")
 check(contact.clod_pose(site,0,1.0,p)==end,"settled clod is stable")
 print("PASS contact geometry" if failures==0 else "FAIL contact geometry")
 quit(0 if failures==0 else 1)
