extends SceneTree
const P=preload("../components/spear_profile.gd")
const E=preload("../components/elemental_spear.gd")
const L=preload("../components/stage_layer.gd")
var checks=0
var failures=0
func _initialize()->void: call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func run()->void:
	var modules=["fire","lightning","ice"]
	var available=[]
	for i in 3:
		if ResourceLoader.exists("res://modules/%s.gd"%modules[i]): available.append(i)
	for element in available:
		var p=load("res://presets/%s.tres"%modules[element]).sanitized()
		for phase in P.PHASES:
			check(p.phase(phase).element==element,"Saved preset selects correct element: "+phase)
			var layer=L.new(); root.add_child(layer); layer.play(Vector2.ZERO,p,phase); layer.seek(p.phase_duration(phase)*.5)
			check(layer.renderer.get_script().resource_path.ends_with(modules[element]+".gd"),"Correct renderer actually instantiated")
			check(layer.sample().active,"Element phase runs independently")
			layer.free()
		for ground in available:
			p.field.element=ground; p.dissolve.element=ground
			var e=E.new(); root.add_child(e); e.play(Vector2.ZERO,p)
			e.seek(p.offsets().hover+.08)
			check(e.layers.hover.renderer.get_script().resource_path.ends_with(modules[element]+".gd"),"Mix retains spear element")
			e.seek(p.contact_time()+.8)
			check(e.layers.field.renderer.get_script().resource_path.ends_with(modules[ground]+".gd") and e.layers.field.sample().active,"Mix replaces active field independently")
			e.seek(p.offsets().dissolve+.1)
			check(e.layers.dissolve.sample().age>p.field.duration,"Dissolve keeps continuous animation time")
			e.clear(); e.seek(0); check(e.is_finished(),"Mixed effect clear cannot resurrect")
			e.free()
	var p=P.new(); p.form.element=1; p.form.renderer_override=preload("../modules/fire.gd")
	var layer=L.new(); root.add_child(layer); layer.play(Vector2.ZERO,p,"form")
	check(layer.renderer.get_script().resource_path.ends_with("fire.gd"),"Custom stage renderer overrides enum without coupling")
	layer.free()
	print("ELEMENTAL_SPEAR_MODULES: %d elements, %d checks, %d failures"%[available.size(),checks,failures]); quit(1 if failures else 0)
