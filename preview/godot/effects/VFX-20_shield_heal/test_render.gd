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
	var presets=JSON.parse_string(FileAccess.get_file_as_string("res://effects/VFX-20_shield_heal/presets.json"))
	for index in [2,3]:
		var cfg=presets.presets[index].overrides.duplicate();cfg.particles=0;cfg.plus_count=1
		f.play(Vector2(64,102),cfg);f.tick(.8);await RenderingServer.frame_post_draw
		var im=v.get_texture().get_image();im.save_png(target.path_join("green_plus_"+str(index)+".png"))
		var p=(Vector2(64,102)+Vector2(-f.config.radius*(.50+.27*f.rand_slot(50)),-.4*f.config.height*1.7)).round()
		for off in [Vector2.ZERO,Vector2(3,0),Vector2(-3,0),Vector2(0,3),Vector2(0,-3)]:
			var c=im.get_pixelv(Vector2i(p+off));assert(c.g>c.r*1.5 and c.g>c.b*1.5);assert(c.a>.7)
	f.play(Vector2(64,102),{"mode":"heal","plus":"ff3300","particles":0,"plus_count":1});f.tick(.8);await RenderingServer.frame_post_draw
	var cp=(Vector2(64,102)+Vector2(-f.config.radius*(.50+.27*f.rand_slot(50)),-.4*f.config.height*1.7)).round()
	var cc=v.get_texture().get_image().get_pixelv(Vector2i(cp));assert(cc.r>cc.g*2)
	print("PLUS PIXELS: 10 green shape/opacity samples and custom red override passed")
	f.clear();await RenderingServer.frame_post_draw
	var empty=v.get_texture().get_image()
	for y in range(128):
		for x in range(128):assert(empty.get_pixel(x,y).a==0)
	print("RENDER CLEAR 16384 alpha checks");get_tree().quit()
