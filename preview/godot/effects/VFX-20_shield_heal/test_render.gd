extends Node
const Fx=preload("res://effects/VFX-20_shield_heal/support.gd")
var frames=[]
func _ready()->void:
	var v=SubViewport.new();v.size=Vector2i(128,128);v.transparent_bg=true;v.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(v)
	var f=Fx.new();f.automatic=false;v.add_child(f)
	var target="user://support-probes"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--probe-dir="):target=arg.trim_prefix("--probe-dir=")
	DirAccess.make_dir_recursive_absolute(target)
	for mode in ["shield","heal"]:
		for age in [0.0,.08,.2,.8,1.65,2.6,3.2]:
			f.play(Vector2(64,102),{"mode":mode});f.tick(age)
			await RenderingServer.frame_post_draw
			var img=v.get_texture().get_image();img.save_png(target.path_join(mode+"_"+str(age)+".png"))
	f.play(Vector2(64,102));f.tick(.5);f.break_shield();f.tick(.15)
	await RenderingServer.frame_post_draw
	v.get_texture().get_image().save_png(target.path_join("break.png"))
	f.clear();await RenderingServer.frame_post_draw
	var empty=v.get_texture().get_image()
	for y in range(128):
		for x in range(128):assert(empty.get_pixel(x,y).a==0)
	print("RENDER CLEAR 16384 alpha checks");get_tree().quit()
