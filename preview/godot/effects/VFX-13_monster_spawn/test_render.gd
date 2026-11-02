extends SceneTree
const Reveal=preload("res://effects/VFX-13_monster_spawn/reveal.gdshader")
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(value:bool,message:String)->void:
	checks+=1
	if not value:failures+=1;push_error(message)
func run()->void:
	var viewport:=SubViewport.new();viewport.size=Vector2i(8,8);viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var image:=Image.create(8,8,false,Image.FORMAT_RGBA8);image.fill(Color(0.4,0.6,0.8,0.5))
	for y in range(8):image.set_pixel(0,y,Color.TRANSPARENT)
	var body:=Sprite2D.new();body.texture=ImageTexture.create_from_image(image);body.centered=false;body.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var mat:=ShaderMaterial.new();mat.shader=Reveal;viewport.add_child(body)
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	var baseline:=viewport.get_texture().get_image()
	body.material=mat
	for p in [0.0,0.5,1.0]:
		mat.set_shader_parameter("progress",p)
		await process_frame;await process_frame;await RenderingServer.frame_post_draw
		var output:=viewport.get_texture().get_image()
		for y in range(8):
			for x in range(8):
				var c:=output.get_pixel(x,y)
				if x==0 or p==0 or (p==0.5 and y<4):check(c.a<0.01,"transparent source/hidden rows stay transparent")
				else:check(absf(c.a-0.5)<0.02,"source half-alpha preserved, not squared or filled")
				if p==1 and x>0:check(c.is_equal_approx(baseline.get_pixel(x,y)),"full appearance returns source RGB")
	viewport.free();print("VFX-13 native shader: ",checks," alpha/color assertions, failures=",failures);quit(1 if failures>0 else 0)
