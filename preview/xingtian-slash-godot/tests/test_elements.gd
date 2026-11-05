extends SceneTree
const Profile=preload("../elements/element_profile.gd")
const Slash=preload("../elements/elemental_slash.gd")
var checks:=0
var failures:=0
func check(ok:bool, message:String)->void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func _initialize()->void: call_deferred("run")
func run()->void:
	check(Profile.new().edge_color==Color("fffaca"),"Default profile uses fire palette")
	var p=Profile.new(); p.element=2; p.apply_palette()
	var a=Slash.new(); var b=Slash.new(); root.add_child(a); root.add_child(b)
	a.play(Vector2(60,60),p); b.play(Vector2(60,60),p)
	check(not a.visible,"No pre-roll pixels")
	p.radius=88.; check(a.profile.radius==52.,"Caller configuration copied")
	a.seek(.08); check(a.visible and not b.visible,"Independent clocks")
	check(a.profile.edge_color==Color("f5ffff"),"Ice palette passed into accepted arc")
	check(a.arc.profile.edge_color==a.profile.edge_color,"Arc and rim palettes match")
	check(a.get_child_count()==1,"No impact or ground wave component")
	var point=a._point(.7); a.profile.facing_left=true; var mirrored=a._point(.7)
	check(is_equal_approx(point.x,-mirrored.x) and is_equal_approx(point.y,mirrored.y),"All attachment anchors mirror with accepted blade")
	a.seek(a.lifetime()); check(not a.visible and not a.arc.visible,"All layers fully end")
	a.seek(.08); check(a.visible,"Natural completion supports inspection")
	a.clear(); a.seek(.08); a.advance(.1); check(not a.visible and not a.started,"Clear cannot resurrect")
	a.play(Vector2.ZERO); a.set_enabled(false); a.seek(.08); check(not a.visible,"Disable entire instance")
	a.set_enabled(true); check(a.visible,"Re-enable preserves time")
	a.set_layer_enabled("arc",false); check(not a.arc.visible,"Arc toggles independently")
	a.play(Vector2.ZERO); check(not a.arc.enabled,"Replay preserves layer switch")
	a.seek(.08); var before=a.elapsed; a.advance(-1.); a.advance(NAN); a.seek(INF); check(a.elapsed==before,"Invalid times ignored")
	a.play(Vector2(INF,0)); check(not a.started,"Invalid origin clears safely")
	p=Profile.new(); p.edge_reach=NAN; p.attachment_strength=INF; p.attachment_count=99; p.debris_count=-2
	var sanitized=p.sanitized()
	check(sanitized.edge_reach==15. and sanitized.attachment_strength==1.,"Nonfinite settings cleaned")
	check(sanitized.attachment_count==12 and sanitized.debris_count==0,"Counts bounded")
	check(is_nan(p.edge_reach),"Sanitizing never mutates caller")
	var scene=load("res://elemental_preview.tscn").instantiate(); root.add_child(scene); scene.set_process(false)
	check(scene.effects.size()==6,"All three native and magnified views exist")
	scene.seek_all(.23); scene.paused=true; var t=scene.time; scene._process(.5); check(scene.time==t,"Pause holds")
	scene.clear_all(); scene.paused=false; scene._process(.5); scene.sliders.radius.value=88; scene.mirror_button.button_pressed=true
	check(scene.cleared and not scene.effects[0].started,"Clear survives edits and resume")
	scene.replay(); scene.seek_all(.23); check(scene.effects[0].visible,"Explicit replay restores")
	check(scene.views[0].size==Vector2i(384,288),"Maximum radius switches detail to integer 1x")
	check(scene.effects[0].profile.radius==88. and scene.effects[1].profile.radius==88.,"Both sizes share exact settings")
	scene.sliders.radius.value=20
	check(scene.sliders.thickness.value==10 and scene.effects[0].profile.thickness==10,"UI width reports radius-dependent clamping")
	scene.sliders.radius.value=52; scene.sliders.thickness.value=28
	check(scene.sliders.thickness.value==26 and scene.effects[0].profile.thickness==26,"UI width always matches rendered width")
	scene.free(); a.free(); b.free()
	print("ELEMENT_SLASH_STATE: %d checks, %d failures"%[checks,failures]); quit(1 if failures else 0)
